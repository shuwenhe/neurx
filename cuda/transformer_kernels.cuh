#pragma once
#include <cuda_runtime.h>
#include <cmath>

namespace neurx_cuda_transformer {

__global__ void add(const float* a,const float* b,float* y,int n){int i=blockIdx.x*blockDim.x+threadIdx.x;if(i<n)y[i]=a[i]+b[i];}
__global__ void add_inplace(float* a,const float* b,int n){int i=blockIdx.x*blockDim.x+threadIdx.x;if(i<n)a[i]+=b[i];}
__global__ void embedding_fwd(const int* ids,const float* w,float* x,int t,int d){int i=blockIdx.x*blockDim.x+threadIdx.x;if(i<t*d)x[i]=w[ids[i/d]*d+i%d];}
__global__ void embedding_bwd(const int* ids,const float* dx,float* dw,int t,int d){int i=blockIdx.x*blockDim.x+threadIdx.x;if(i<t*d)atomicAdd(&dw[ids[i/d]*d+i%d],dx[i]);}
__global__ void adamw(float* p,const float* g,float* m,float* v,int n,int step,float lr,float wd){int i=blockIdx.x*blockDim.x+threadIdx.x;if(i>=n)return;float b1=.9f,b2=.999f;m[i]=b1*m[i]+(1-b1)*g[i];v[i]=b2*v[i]+(1-b2)*g[i]*g[i];float mh=m[i]/(1-powf(b1,step)),vh=v[i]/(1-powf(b2,step));p[i]-=lr*(mh/(sqrtf(vh)+1e-8f)+wd*p[i]);}

__global__ void gemm_fwd(const float* a,const float* b,float* c,int m,int k,int n) {
    int q=blockIdx.x*blockDim.x+threadIdx.x; if(q>=m*n)return; int i=q/n,j=q%n; float s=0;
    for(int p=0;p<k;p++)s+=a[i*k+p]*b[p*n+j]; c[q]=s;
}
__global__ void gemm_dx(const float* dy,const float* w,float* dx,int m,int k,int n) {
    int q=blockIdx.x*blockDim.x+threadIdx.x; if(q>=m*k)return; int i=q/k,p=q%k; float s=0;
    for(int j=0;j<n;j++)s+=dy[i*n+j]*w[p*n+j]; dx[q]=s;
}
__global__ void gemm_dw(const float* x,const float* dy,float* dw,int m,int k,int n) {
    int q=blockIdx.x*blockDim.x+threadIdx.x; if(q>=k*n)return; int p=q/n,j=q%n; float s=0;
    for(int i=0;i<m;i++)s+=x[i*k+p]*dy[i*n+j]; dw[q]=s;
}

__global__ void rms_fwd(const float* x,const float* g,float* y,float* inv,int rows,int d) {
    int r=blockIdx.x*blockDim.x+threadIdx.x;if(r>=rows)return;float ss=0;
    for(int j=0;j<d;j++)ss+=x[r*d+j]*x[r*d+j];float z=rsqrtf(ss/d+1e-5f);inv[r]=z;
    for(int j=0;j<d;j++)y[r*d+j]=x[r*d+j]*z*g[j];
}
__global__ void rms_dx(const float* x,const float* g,const float* inv,const float* dy,float* dx,int rows,int d) {
    int r=blockIdx.x*blockDim.x+threadIdx.x;if(r>=rows)return;float dot=0;
    for(int j=0;j<d;j++)dot+=dy[r*d+j]*g[j]*x[r*d+j];float z=inv[r];
    for(int j=0;j<d;j++)dx[r*d+j]=dy[r*d+j]*g[j]*z-x[r*d+j]*z*z*z*dot/d;
}
__global__ void rms_dg(const float* x,const float* inv,const float* dy,float* dg,int rows,int d) {
    int j=blockIdx.x*blockDim.x+threadIdx.x;if(j>=d)return;float s=0;
    for(int r=0;r<rows;r++)s+=dy[r*d+j]*x[r*d+j]*inv[r];dg[j]=s;
}

__global__ void rope(float* x,int t,int d,int heads,bool inverse) {
    int q=blockIdx.x*blockDim.x+threadIdx.x,hd=d/heads,pairs=hd/2,total=t*heads*pairs;if(q>=total)return;
    int pair=q%pairs,h=(q/pairs)%heads,p=q/(pairs*heads),j=pair*2;float angle=p/powf(10000.0f,float(j)/hd);
    float cs=cosf(angle),sn=sinf(angle);if(inverse)sn=-sn;int z=p*d+h*hd+j;float a=x[z],b=x[z+1];x[z]=a*cs-b*sn;x[z+1]=a*sn+b*cs;
}

__global__ void rope_position(float* x,int d,int heads,int position) {
    int q=blockIdx.x*blockDim.x+threadIdx.x,hd=d/heads,pairs=hd/2,total=heads*pairs;if(q>=total)return;
    int pair=q%pairs,h=q/pairs,j=pair*2;float angle=position/powf(10000.0f,float(j)/hd);
    float cs=cosf(angle),sn=sinf(angle);int z=h*hd+j;float a=x[z],b=x[z+1];x[z]=a*cs-b*sn;x[z+1]=a*sn+b*cs;
}

__global__ void swiglu_fwd(const float* gate,const float* up,float* y,int n) {
    int i=blockIdx.x*blockDim.x+threadIdx.x;if(i>=n)return;float s=1/(1+expf(-gate[i]));y[i]=gate[i]*s*up[i];
}
__global__ void swiglu_bwd(const float* gate,const float* up,const float* dy,float* dg,float* du,int n) {
    int i=blockIdx.x*blockDim.x+threadIdx.x;if(i>=n)return;float s=1/(1+expf(-gate[i]));dg[i]=dy[i]*up[i]*(s+gate[i]*s*(1-s));du[i]=dy[i]*gate[i]*s;
}

__global__ void cross_entropy_fwd_bwd(const float* logits,const int* targets,float* loss,float* dlogits,int rows,int vocab) {
    int r=blockIdx.x*blockDim.x+threadIdx.x;if(r>=rows)return;float mx=-INFINITY;
    for(int j=0;j<vocab;j++)mx=fmaxf(mx,logits[r*vocab+j]);float sum=0;for(int j=0;j<vocab;j++)sum+=expf(logits[r*vocab+j]-mx);
    atomicAdd(loss,(logf(sum)+mx-logits[r*vocab+targets[r]])/rows);
    for(int j=0;j<vocab;j++)dlogits[r*vocab+j]=(expf(logits[r*vocab+j]-mx)/sum-(j==targets[r]))/rows;
}

__global__ void attention_fwd(const float* q,const float* k,const float* v,float* att,float* ctx,int t,int d,int heads) {
    int z=blockIdx.x*blockDim.x+threadIdx.x;if(z>=heads*t)return;int h=z/t,i=z%t,hd=d/heads;float scale=rsqrtf(float(hd)),mx=-INFINITY;
    for(int j=0;j<=i;j++){float s=0;for(int p=0;p<hd;p++)s+=q[i*d+h*hd+p]*k[j*d+h*hd+p];s*=scale;att[(h*t+i)*t+j]=s;mx=fmaxf(mx,s);}float sum=0;
    for(int j=0;j<=i;j++)sum+=expf(att[(h*t+i)*t+j]-mx);for(int j=0;j<=i;j++)att[(h*t+i)*t+j]=expf(att[(h*t+i)*t+j]-mx)/sum;
    for(int p=0;p<hd;p++){float s=0;for(int j=0;j<=i;j++)s+=att[(h*t+i)*t+j]*v[j*d+h*hd+p];ctx[i*d+h*hd+p]=s;}
}

__global__ void attention_decode(const float* q,const float* k_cache,const float* v_cache,
                                 float* att,float* ctx,int position,int max_seq,int d,int heads) {
    int h=blockIdx.x*blockDim.x+threadIdx.x;if(h>=heads)return;int hd=d/heads;float scale=rsqrtf(float(hd)),mx=-INFINITY;
    for(int j=0;j<=position;j++){float s=0;for(int p=0;p<hd;p++)s+=q[h*hd+p]*k_cache[j*d+h*hd+p];s*=scale;att[h*max_seq+j]=s;mx=fmaxf(mx,s);}
    float sum=0;for(int j=0;j<=position;j++)sum+=expf(att[h*max_seq+j]-mx);
    for(int j=0;j<=position;j++)att[h*max_seq+j]=expf(att[h*max_seq+j]-mx)/sum;
    for(int p=0;p<hd;p++){float s=0;for(int j=0;j<=position;j++)s+=att[h*max_seq+j]*v_cache[j*d+h*hd+p];ctx[h*hd+p]=s;}
}
__global__ void attention_bwd(const float* q,const float* k,const float* v,const float* att,const float* dctx,float* dq,float* dk,float* dv,int t,int d,int heads) {
    int z=blockIdx.x*blockDim.x+threadIdx.x;if(z>=heads*t)return;int h=z/t,i=z%t,hd=d/heads;float scale=rsqrtf(float(hd));
    extern __shared__ float work[];
    float* da=work;float* ds=work+t;float dot=0;
    for(int j=0;j<=i;j++){float s=0;for(int p=0;p<hd;p++){s+=dctx[i*d+h*hd+p]*v[j*d+h*hd+p];atomicAdd(&dv[j*d+h*hd+p],att[(h*t+i)*t+j]*dctx[i*d+h*hd+p]);}da[j]=s;dot+=s*att[(h*t+i)*t+j];}
    for(int j=0;j<=i;j++)ds[j]=att[(h*t+i)*t+j]*(da[j]-dot);
    for(int j=0;j<=i;j++)for(int p=0;p<hd;p++){atomicAdd(&dq[i*d+h*hd+p],ds[j]*k[j*d+h*hd+p]*scale);atomicAdd(&dk[j*d+h*hd+p],ds[j]*q[i*d+h*hd+p]*scale);}
}

inline int blocks(int n){return (n+255)/256;}
}
