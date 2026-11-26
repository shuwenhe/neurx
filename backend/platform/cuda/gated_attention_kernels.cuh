#pragma once
#include <cuda_runtime.h>
#include <cmath>
namespace neurx::cuda::hybrid::kernels {
// Deliberately sequential FP32 reduction baseline; no TF32 or implicit FMA.
__global__ void linear(const float* x,const float* w,float* y,int rows,int in,int out) {
  int i=blockIdx.x*blockDim.x+threadIdx.x;
  if(i>=rows*out)return;
  int row=i/out,col=i%out;float sum=0;
  for(int k=0;k<in;++k)sum+=x[row*in+k]*w[col*in+k];
  y[i]=sum;
}
__global__ void normalize_qg(const float* qg,const float* weight,float* q,float* gate,
                            int rows,int heads,int dim,float eps) {
  int row=blockIdx.x*blockDim.x+threadIdx.x;
  if(row>=rows*heads)return;
  float sum=0;for(int k=0;k<dim;++k){float x=qg[row*dim*2+k];sum+=x*x;}
  float inv=1.0f/sqrtf(sum/dim+eps);
  for(int k=0;k<dim;++k){q[row*dim+k]=qg[row*dim*2+k]*inv*(1+weight[k]);gate[row*dim+k]=qg[row*dim*2+dim+k];}
}
__global__ void normalize_k(float* k,const float* weight,int count,int dim,float eps) {
  int row=blockIdx.x*blockDim.x+threadIdx.x;if(row>=count)return;
  float sum=0;for(int d=0;d<dim;++d){float x=k[row*dim+d];sum+=x*x;}
  float inv=1.0f/sqrtf(sum/dim+eps);
  for(int d=0;d<dim;++d)k[row*dim+d]*=inv*(1+weight[d]);
}
__global__ void partial_rope(float* x,int rows,int heads,int dim,int rotary,int offset,float theta) {
  int i=blockIdx.x*blockDim.x+threadIdx.x;int half=rotary/2;
  if(i>=rows*heads*half)return;
  int f=i%half,row=i/half,t=row/heads;
  float angle=(offset+t)*powf(theta,-2.0f*f/rotary);
  float cs=cosf(angle),sn=sinf(angle),a=x[row*dim+f],b=x[row*dim+half+f];
  x[row*dim+f]=a*cs-b*sn;x[row*dim+half+f]=b*cs+a*sn;
}
// One thread per output feature, constant workspace. Three-pass stable softmax.
// Repeated scores trade throughput for a transparent, bounded-memory baseline.
__global__ void gated_gqa(const float* q,const float* gate,const float* keys,const float* values,
                         float* output,int rows,int past,int qh,int kh,int dim) {
  int i=blockIdx.x*blockDim.x+threadIdx.x;if(i>=rows*qh*dim)return;
  int d=i%dim,h=(i/dim)%qh,t=i/(dim*qh),kv=h/(qh/kh),visible=past+t+1;
  const float* query=q+(t*qh+h)*dim;
  float maxscore=-INFINITY,denom=0,sum=0,scale=1.0f/sqrtf(float(dim));
  for(int s=0;s<visible;++s){float dot=0;for(int f=0;f<dim;++f)dot+=query[f]*keys[(s*kh+kv)*dim+f];maxscore=fmaxf(maxscore,dot*scale);}
  for(int s=0;s<visible;++s){float dot=0;for(int f=0;f<dim;++f)dot+=query[f]*keys[(s*kh+kv)*dim+f];float p=expf(dot*scale-maxscore);denom+=p;sum+=p*values[(s*kh+kv)*dim+d];}
  float g=gate[i],e=expf(-fabsf(g)),sig=g>=0?1.0f/(1.0f+e):e/(1.0f+e);
  output[i]=sum/denom*sig;
}
}
