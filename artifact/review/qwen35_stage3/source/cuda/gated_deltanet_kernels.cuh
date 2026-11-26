#pragma once
#include <cuda_runtime.h>
#include <cmath>
namespace neurx::cuda::hybrid::delta_kernels {
__device__ inline float sigmoid(float x) {
  float e=expf(-fabsf(x));
  return x>=0 ? 1.0f/(1.0f+e) : e/(1.0f+e);
}
__global__ void project(const float* x,const float* w,float* y,
                        int rows,int in,int out) {
  int i=blockIdx.x*blockDim.x+threadIdx.x;
  if(i>=rows*out)return;
  int row=i/out,col=i%out;
  float sum=0;
  for(int f=0;f<in;++f)sum+=x[row*in+f]*w[col*in+f];
  y[i]=sum;
}
__global__ void causal_conv(const float* raw,const float* weight,float* history,
                            float* activated,int width,int kernel) {
  int channel=blockIdx.x*blockDim.x+threadIdx.x;
  if(channel>=width)return;
  float* past=history+channel*kernel;
  for(int tap=0;tap<kernel-1;++tap)past[tap]=past[tap+1];
  past[kernel-1]=raw[channel];
  float sum=0;
  for(int tap=0;tap<kernel;++tap)sum+=past[tap]*weight[channel*kernel+tap];
  activated[channel]=sum*sigmoid(sum);
}
__global__ void normalize_qk(const float* activated,float* q,float* k,
                             int heads,int dim) {
  int head=blockIdx.x*blockDim.x+threadIdx.x;
  if(head>=heads)return;
  const float* a=activated+head*dim;
  const float* b=activated+(heads+head)*dim;
  float sq=0,sk=0;
  for(int f=0;f<dim;++f){sq+=a[f]*a[f];sk+=b[f]*b[f];}
  float iq=1.0f/sqrtf(sq+1e-6f),ik=1.0f/sqrtf(sk+1e-6f);
  float scale=1.0f/sqrtf(float(dim));
  for(int f=0;f<dim;++f){q[head*dim+f]=a[f]*iq*scale;k[head*dim+f]=b[f]*ik;}
}
__global__ void gates(const float* a,const float* b,const float* alog,
                      const float* dt,float* beta,float* decay,int heads) {
  int head=blockIdx.x*blockDim.x+threadIdx.x;
  if(head>=heads)return;
  float x=a[head]+dt[head];
  float softplus=fmaxf(x,0.0f)+log1pf(expf(-fabsf(x)));
  beta[head]=sigmoid(b[head]);
  decay[head]=expf(-expf(alog[head])*softplus);
}
// Each thread exclusively owns one value-column of one recurrent state.
// There are no inter-thread reductions or state write races.
__global__ void recurrence(const float* q,const float* k,const float* activated,
                           const float* beta,const float* decay,float* state,
                           float* core,int kh,int vh,int kd,int vd) {
  int i=blockIdx.x*blockDim.x+threadIdx.x;
  if(i>=vh*vd)return;
  int head=i/vd,col=i%vd,key_head=head/(vh/kh);
  const float* key=k+key_head*kd;
  const float* query=q+key_head*kd;
  float* s=state+head*kd*vd+col;
  float prediction=0;
  for(int f=0;f<kd;++f){s[f*vd]*=decay[head];prediction+=s[f*vd]*key[f];}
  float delta=beta[head]*(activated[2*kh*kd+i]-prediction);
  float output=0;
  for(int f=0;f<kd;++f){s[f*vd]+=key[f]*delta;output+=s[f*vd]*query[f];}
  core[i]=output;
}
__global__ void norm_gate(const float* core,const float* z,const float* norm,
                          float* output,int heads,int dim,float epsilon) {
  int head=blockIdx.x*blockDim.x+threadIdx.x;
  if(head>=heads)return;
  float sum=0;
  for(int f=0;f<dim;++f){float x=core[head*dim+f];sum+=x*x;}
  float inv=1.0f/sqrtf(sum/dim+epsilon);
  for(int f=0;f<dim;++f){int i=head*dim+f;output[i]=core[i]*inv*norm[f]*(z[i]*sigmoid(z[i]));}
}
}
