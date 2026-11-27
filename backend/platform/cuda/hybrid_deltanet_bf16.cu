#include "hybrid_deltanet_bf16.h"
#include <cuda_bf16.h>
#include <cuda_runtime.h>
#include <cmath>
#include <climits>
#include <mutex>
#include <stdexcept>
namespace neurx::cuda::hybrid {
namespace {
using B=__nv_bfloat16;
void ck(cudaError_t e){if(e!=cudaSuccess)throw std::runtime_error(cudaGetErrorString(e));}
__device__ float f(B x){return __bfloat162float(x);}
__device__ B b(float x){return __float2bfloat16_rn(x);}
__device__ float sig(float x){return 1.f/(1.f+expf(-x));}
__global__ void project(const B* x,const B* w,B* y,int in,int out){
 int i=blockIdx.x*blockDim.x+threadIdx.x;if(i>=out)return;
 float sum=0;for(int k=0;k<in;++k)sum+=f(x[k])*f(w[i*in+k]);y[i]=b(sum);
}
__global__ void conv_step(const B* raw,const B* w,B* history,B* pre,B* act,int width,int taps){
 int i=blockIdx.x*blockDim.x+threadIdx.x;if(i>=width)return;
 B* p=history+i*taps;for(int k=0;k<taps-1;++k)p[k]=p[k+1];p[taps-1]=raw[i];
 float sum=0;for(int k=0;k<taps;++k)sum+=f(p[k])*f(w[i*taps+k]);
 pre[i]=b(sum);float v=f(pre[i]);act[i]=b(v*sig(v));
}
__global__ void l2(const B* a,B* q,B* k,int heads,int dim){
 int h=blockIdx.x*blockDim.x+threadIdx.x;if(h>=heads)return;
 float sq=0,sk=0;for(int j=0;j<dim;++j){float x=f(a[h*dim+j]),y=f(a[(heads+h)*dim+j]);sq+=f(b(x*x));sk+=f(b(y*y));}
 float iq=f(b(rsqrtf(f(b(f(b(sq))+1e-6f))))),ik=f(b(rsqrtf(f(b(f(b(sk))+1e-6f)))));
 for(int j=0;j<dim;++j){q[h*dim+j]=b(f(a[h*dim+j])*iq);k[h*dim+j]=b(f(a[(heads+h)*dim+j])*ik);}
}
__global__ void gates(const B* a,const B* z,const B* alog,const B* dt,B* beta,float* decay,int n){
 int i=blockIdx.x*blockDim.x+threadIdx.x;if(i>=n)return;
 float x=f(a[i])+f(dt[i]);float soft=x>20.f?x:fmaxf(x,0.f)+log1pf(expf(-fabsf(x)));
 beta[i]=b(sig(f(z[i])));decay[i]=expf(-expf(f(alog[i]))*soft);
}
__global__ void recurrent(const B* q,const B* k,const B* a,const B* beta,const float* decay,float* state,B* core,int kh,int vh,int kd,int vd){
 int i=blockIdx.x*blockDim.x+threadIdx.x;if(i>=vh*vd)return;
 int h=i/vd,col=i%vd,g=h/(vh/kh);float* s=state+h*kd*vd+col;
 float prediction=0;for(int j=0;j<kd;++j){s[j*vd]*=decay[h];prediction+=s[j*vd]*f(k[g*kd+j]);}
 float delta=(f(a[2*kh*kd+i])-prediction)*f(beta[h]);float out=0,scale=1.f/sqrtf(float(kd));
 for(int j=0;j<kd;++j){s[j*vd]+=f(k[g*kd+j])*delta;out+=s[j*vd]*(f(q[g*kd+j])*scale);}core[i]=b(out);
}
__global__ void norm_gate(const B* core,const B* z,const B* weight,B* out,int heads,int dim,float eps){
 int h=blockIdx.x*blockDim.x+threadIdx.x;if(h>=heads)return;
 float sum=0;for(int j=0;j<dim;++j){float x=f(core[h*dim+j]);sum+=x*x;}
 float inv=rsqrtf(sum/float(dim)+eps);
 for(int j=0;j<dim;++j){int i=h*dim+j;B normalized=b(f(core[i])*inv);B weighted=b(f(normalized)*f(weight[j]));float gate=f(z[i]);out[i]=b(f(weighted)*(gate*sig(gate)));}
}
int blocks(int n){return (n+255)/256;}
}
struct DeltaNetBF16Session::Impl {
 DeltaConfig c;int device=0,past=0,kw=0,vw=0,raw=0,sc=0,hc=0;bool valid=false;
 uint64_t budget,headroom,used=0;std::mutex mutex;std::vector<void*> allocations;
 B *wq,*wz,*wa,*wb,*wc,*alog,*dt,*norm,*wo,*x,*qkv,*z,*a,*bb,*history,*pre,*act,*q,*k,*beta,*core,*gated,*out;
 float *state,*decay;
 Impl(const DeltaConfig& config,uint64_t budget_,uint64_t headroom_):c(config),budget(budget_),headroom(headroom_){ck(cudaGetDevice(&device));}
 ~Impl(){int old=0;cudaGetDevice(&old);cudaSetDevice(device);for(void* p:allocations)cudaFree(p);cudaSetDevice(old);}
 void same(){int d;ck(cudaGetDevice(&d));if(d!=device)throw std::runtime_error("session device mismatch");}
 template<class T>T* alloc(uint64_t n){
  if(n>UINT64_MAX/sizeof(T))throw std::invalid_argument("allocation overflow");
  uint64_t bytes=n*sizeof(T);size_t free,total;ck(cudaMemGetInfo(&free,&total));
  if(used>budget || bytes>budget-used || headroom>free || bytes>free-headroom)throw std::runtime_error("GPU memory admission rejected");
  T* p=nullptr;ck(cudaMalloc(&p,bytes));
  try{ck(cudaMemGetInfo(&free,&total));if(free<headroom)throw std::runtime_error("GPU headroom admission rejected");allocations.push_back(p);}catch(...){cudaFree(p);throw;}
  used+=bytes;return p;
 }
 void upload(B* target,const std::vector<float>& values){
  std::vector<B> raw;raw.reserve(values.size());for(float x:values){
   if(!std::isfinite(x))throw std::invalid_argument("nonfinite BF16 input");
   B y=__float2bfloat16_rn(x);if(!std::isfinite(__bfloat162float(y)))throw std::invalid_argument("BF16 overflow");raw.push_back(y);
  }ck(cudaMemcpy(target,raw.data(),raw.size()*sizeof(B),cudaMemcpyHostToDevice));
 }
 B* weight(const std::vector<float>& v,uint64_t n){if(v.size()!=n)throw std::invalid_argument("weight shape mismatch");auto p=alloc<B>(n);upload(p,v);return p;}
 template<class T>void snapshot(Trace& t,const char* name,const T* source,int n){
  std::vector<T> host(n);ck(cudaMemcpy(host.data(),source,n*sizeof(T),cudaMemcpyDeviceToHost));
  auto& dest=t[name];for(auto x:host){float v;if constexpr(sizeof(T)==2)v=__bfloat162float(x);else v=x;if(!std::isfinite(v))throw std::runtime_error("nonfinite execution result");dest.push_back(v);}
 }
};
DeltaNetBF16Session::DeltaNetBF16Session(const DeltaConfig& c,const DeltaWeights& w,uint64_t budget,uint64_t headroom){
 if(c.hidden<=0||c.key_heads<=0||c.value_heads<=0||c.key_dim<=0||c.value_dim<=0||c.conv_kernel<=0||c.context<=0||c.max_chunk<=0||c.max_chunk>c.context||c.value_heads%c.key_heads||!std::isfinite(c.epsilon)||!std::isfinite(float(c.epsilon))||float(c.epsilon)<=0)throw std::invalid_argument("invalid BF16 config");
 // Bound each dimension before products, then all kernel spans before narrowing.
 for(int n:{c.hidden,c.key_heads,c.value_heads,c.key_dim,c.value_dim,c.conv_kernel})if(n>65536)throw std::invalid_argument("BF16 dimension limit");
 uint64_t kw=uint64_t(c.key_heads)*c.key_dim,vw=uint64_t(c.value_heads)*c.value_dim,raw=2*kw+vw,sc=vw*c.key_dim,hc=raw*c.conv_kernel;
 for(uint64_t n:{kw,vw,raw,sc,hc,raw*c.hidden,vw*c.hidden,uint64_t(c.value_heads)*c.hidden})if(n>INT_MAX-256)throw std::invalid_argument("BF16 span limit");
 impl_=std::make_unique<Impl>(c,budget,headroom);auto& s=*impl_;s.kw=kw;s.vw=vw;s.raw=raw;s.sc=sc;s.hc=hc;
 s.wq=s.weight(w.qkv,raw*c.hidden);s.wz=s.weight(w.z,vw*c.hidden);s.wa=s.weight(w.a,uint64_t(c.value_heads)*c.hidden);s.wb=s.weight(w.b,uint64_t(c.value_heads)*c.hidden);
 s.wc=s.weight(w.conv,hc);s.alog=s.weight(w.alog,c.value_heads);s.dt=s.weight(w.dt,c.value_heads);s.norm=s.weight(w.norm,c.value_dim);s.wo=s.weight(w.out,uint64_t(c.hidden)*vw);
 s.x=s.alloc<B>(c.hidden);s.qkv=s.alloc<B>(raw);s.z=s.alloc<B>(vw);s.a=s.alloc<B>(c.value_heads);s.bb=s.alloc<B>(c.value_heads);s.history=s.alloc<B>(hc);s.pre=s.alloc<B>(raw);s.act=s.alloc<B>(raw);s.q=s.alloc<B>(kw);s.k=s.alloc<B>(kw);s.beta=s.alloc<B>(c.value_heads);s.core=s.alloc<B>(vw);s.gated=s.alloc<B>(vw);s.out=s.alloc<B>(c.hidden);s.state=s.alloc<float>(sc);s.decay=s.alloc<float>(c.value_heads);reset();
}
DeltaNetBF16Session::~DeltaNetBF16Session()=default;
int DeltaNetBF16Session::length()const{std::lock_guard<std::mutex> lock(impl_->mutex);return impl_->past;}
void DeltaNetBF16Session::reset(const std::vector<float>& state,const std::vector<float>& history){
 auto& s=*impl_;std::lock_guard<std::mutex> lock(s.mutex);s.same();
 if((!state.empty()&&state.size()!=size_t(s.sc))||(!history.empty()&&history.size()!=size_t(s.hc)))throw std::invalid_argument("state/history shape mismatch");
 for(float x:state)if(!std::isfinite(x))throw std::invalid_argument("nonfinite state");
 s.valid=false;if(state.empty())ck(cudaMemset(s.state,0,s.sc*sizeof(float)));else ck(cudaMemcpy(s.state,state.data(),s.sc*sizeof(float),cudaMemcpyHostToDevice));
 if(history.empty())ck(cudaMemset(s.history,0,s.hc*sizeof(B)));else s.upload(s.history,history);
 ck(cudaDeviceSynchronize());s.past=0;s.valid=true;
}
DeltaNetBF16Session::Trace DeltaNetBF16Session::forward(const std::vector<float>& input,int position){
 auto& s=*impl_;std::lock_guard<std::mutex> lock(s.mutex);s.same();auto& c=s.c;
 if(!s.valid)throw std::runtime_error("invalid session: reset required");
 if(input.empty()||input.size()%c.hidden)throw std::invalid_argument("input shape mismatch");
 auto rows=input.size()/c.hidden;
 if(position!=s.past||rows>uint64_t(c.max_chunk)||rows>uint64_t(c.context-s.past))throw std::invalid_argument("position/chunk/context mismatch");
 uint64_t per=uint64_t(s.raw)*3+uint64_t(s.vw)*3+uint64_t(c.value_heads)*4+2ULL*s.kw+c.hidden+s.sc+s.hc;
 if(rows>(64ULL<<20)/(per*sizeof(float)*2))throw std::invalid_argument("trace exceeds 64MiB host budget");
 for(float x:input)if(!std::isfinite(x))throw std::invalid_argument("nonfinite input");
 Trace trace;
 try{
 for(size_t t=0;t<rows;++t){
  s.upload(s.x,std::vector<float>(input.begin()+t*c.hidden,input.begin()+(t+1)*c.hidden));
  project<<<blocks(s.raw),256>>>(s.x,s.wq,s.qkv,c.hidden,s.raw);project<<<blocks(s.vw),256>>>(s.x,s.wz,s.z,c.hidden,s.vw);
  project<<<blocks(c.value_heads),256>>>(s.x,s.wa,s.a,c.hidden,c.value_heads);project<<<blocks(c.value_heads),256>>>(s.x,s.wb,s.bb,c.hidden,c.value_heads);
  conv_step<<<blocks(s.raw),256>>>(s.qkv,s.wc,s.history,s.pre,s.act,s.raw,c.conv_kernel);
  l2<<<blocks(c.key_heads),256>>>(s.act,s.q,s.k,c.key_heads,c.key_dim);
  gates<<<blocks(c.value_heads),256>>>(s.a,s.bb,s.alog,s.dt,s.beta,s.decay,c.value_heads);
  recurrent<<<blocks(s.vw),256>>>(s.q,s.k,s.act,s.beta,s.decay,s.state,s.core,c.key_heads,c.value_heads,c.key_dim,c.value_dim);
  norm_gate<<<blocks(c.value_heads),256>>>(s.core,s.z,s.norm,s.gated,c.value_heads,c.value_dim,float(c.epsilon));
  project<<<blocks(c.hidden),256>>>(s.gated,s.wo,s.out,s.vw,c.hidden);ck(cudaGetLastError());
  s.snapshot(trace,"qkv",s.qkv,s.raw);s.snapshot(trace,"z",s.z,s.vw);s.snapshot(trace,"a",s.a,c.value_heads);s.snapshot(trace,"b",s.bb,c.value_heads);
  s.snapshot(trace,"conv",s.pre,s.raw);s.snapshot(trace,"activated",s.act,s.raw);s.snapshot(trace,"q",s.q,s.kw);s.snapshot(trace,"k",s.k,s.kw);
  s.snapshot(trace,"beta",s.beta,c.value_heads);s.snapshot(trace,"decay",s.decay,c.value_heads);s.snapshot(trace,"core",s.core,s.vw);s.snapshot(trace,"gated",s.gated,s.vw);
  s.snapshot(trace,"output",s.out,c.hidden);s.snapshot(trace,"state",s.state,s.sc);s.snapshot(trace,"history",s.history,s.hc);
 }
 ck(cudaDeviceSynchronize());s.past+=rows;return trace;
 }catch(...){s.valid=false;throw;}
}
}
