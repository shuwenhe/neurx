#include "hybrid_attention_cuda.h"
#include "gated_attention_kernels.cuh"
#include <cuda_runtime.h>
#include <cmath>
#include <climits>
#include <limits>
#include <mutex>
#include <stdexcept>
#include <string>
#include <algorithm>
namespace neurx::cuda::hybrid {
namespace {
void check(cudaError_t e){if(e!=cudaSuccess)throw std::runtime_error(cudaGetErrorString(e));}
uint64_t mul(uint64_t a,uint64_t b){if(b&&a>std::numeric_limits<uint64_t>::max()/b)throw std::invalid_argument("size overflow");return a*b;}
void finite(const std::vector<float>& v){for(float x:v)if(!std::isfinite(x))throw std::invalid_argument("nonfinite tensor");}
int blocks(int n){return (n+255)/256;}
}
struct FullAttentionSession::Impl {
  AttentionConfig c;uint64_t budget,headroom,used=0;int past=0;bool valid=true;
  int device=0;std::mutex mutex;std::vector<float*> allocations;
  float *wq=nullptr,*wk=nullptr,*wv=nullptr,*wo=nullptr,*qn=nullptr,*kn=nullptr;
  float *x=nullptr,*qg=nullptr,*q=nullptr,*gate=nullptr,*k=nullptr,*v=nullptr,*att=nullptr,*out=nullptr,*keys=nullptr,*values=nullptr;
  Impl(AttentionConfig config,uint64_t b,uint64_t h):c(config),budget(b),headroom(h){check(cudaGetDevice(&device));}
  ~Impl(){int previous=0;cudaGetDevice(&previous);cudaSetDevice(device);for(auto p:allocations)cudaFree(p);cudaSetDevice(previous);}
  float* alloc(uint64_t count){
    uint64_t bytes=mul(count,sizeof(float));size_t free=0,total=0;check(cudaMemGetInfo(&free,&total));
    if(bytes>budget-used||headroom>free||bytes>free-headroom)throw std::runtime_error("GPU memory admission rejected");
    float* p=nullptr;check(cudaMalloc(&p,bytes));
    try{allocations.push_back(p);}catch(...){cudaFree(p);throw;}
    used+=bytes;return p;
  }
  float* weight(const std::vector<float>& v,uint64_t n){if(v.size()!=n)throw std::invalid_argument("weight shape mismatch");finite(v);auto p=alloc(n);check(cudaMemcpy(p,v.data(),n*sizeof(float),cudaMemcpyHostToDevice));return p;}
  std::vector<float> read(float* p,int n){std::vector<float> v(n);check(cudaMemcpy(v.data(),p,n*sizeof(float),cudaMemcpyDeviceToHost));finite(v);return v;}
  void same_device(){int current=0;check(cudaGetDevice(&current));if(current!=device)throw std::runtime_error("session device mismatch");}
};
FullAttentionSession::FullAttentionSession(const AttentionConfig& c,const AttentionWeights& w,uint64_t budget,uint64_t headroom){
  if(c.hidden<=0||c.query_heads<=0||c.kv_heads<=0||c.head_dim<=0||c.rotary_dim<=0||
     c.rotary_dim>c.head_dim||c.rotary_dim%2||c.query_heads%c.kv_heads||c.context<=0||
     c.max_chunk<=0||c.max_chunk>c.context||!std::isfinite(c.theta)||c.theta<=0||
     !std::isfinite(c.epsilon)||c.epsilon<=0||
     !std::isfinite(float(c.theta))||float(c.theta)<=0||
     !std::isfinite(float(c.epsilon))||float(c.epsilon)<=0)throw std::invalid_argument("invalid attention config");
  // Kernels currently use int indexing; reject every potentially overflowing span.
  uint64_t qw=mul(c.query_heads,c.head_dim),kw=mul(c.kv_heads,c.head_dim);
  for(uint64_t n:{mul(c.max_chunk,mul(2,qw)),mul(c.context,kw),mul(c.hidden,mul(2,qw)),mul(c.hidden,kw),mul(c.max_chunk,c.hidden)})
    if(n>INT_MAX-256)throw std::invalid_argument("attention span exceeds int kernel limit");
  impl_=std::make_unique<Impl>(c,budget,headroom);auto& s=*impl_;
  s.wq=s.weight(w.qg,mul(c.hidden,2*qw));s.wk=s.weight(w.k,mul(c.hidden,kw));s.wv=s.weight(w.v,mul(c.hidden,kw));s.wo=s.weight(w.o,mul(c.hidden,qw));
  s.qn=s.weight(w.qnorm,c.head_dim);s.kn=s.weight(w.knorm,c.head_dim);
  s.keys=s.alloc(mul(c.context,kw));s.values=s.alloc(mul(c.context,kw));
  s.x=s.alloc(mul(c.max_chunk,c.hidden));s.qg=s.alloc(mul(c.max_chunk,2*qw));
  s.q=s.alloc(mul(c.max_chunk,qw));s.gate=s.alloc(mul(c.max_chunk,qw));s.k=s.alloc(mul(c.max_chunk,kw));s.v=s.alloc(mul(c.max_chunk,kw));
  s.att=s.alloc(mul(c.max_chunk,qw));s.out=s.alloc(mul(c.max_chunk,c.hidden));
}
FullAttentionSession::~FullAttentionSession()=default;
int FullAttentionSession::length()const{std::lock_guard<std::mutex> lock(impl_->mutex);return impl_->past;}
uint64_t FullAttentionSession::allocated_bytes()const{return impl_->used;}
void FullAttentionSession::reset(){auto& s=*impl_;std::lock_guard<std::mutex> lock(s.mutex);s.same_device();check(cudaDeviceSynchronize());s.past=0;s.valid=true;}
AttentionTrace FullAttentionSession::forward(const std::vector<float>& input,int position,bool trace){
  auto& s=*impl_;std::lock_guard<std::mutex> lock(s.mutex);s.same_device();const auto& c=s.c;
  if(!s.valid)throw std::runtime_error("invalid session: reset required");
  if(input.empty()||input.size()%c.hidden)throw std::invalid_argument("input shape mismatch");
  uint64_t rows64=input.size()/c.hidden;
  if(position!=s.past||rows64>uint64_t(c.max_chunk)||rows64>uint64_t(c.context-s.past))throw std::invalid_argument("position/chunk/context mismatch");
  finite(input);int rows=int(rows64),qw=c.query_heads*c.head_dim,kw=c.kv_heads*c.head_dim;
  try{
    check(cudaMemcpy(s.x,input.data(),input.size()*sizeof(float),cudaMemcpyHostToDevice));
    kernels::linear<<<blocks(rows*2*qw),256>>>(s.x,s.wq,s.qg,rows,c.hidden,2*qw);
    kernels::linear<<<blocks(rows*kw),256>>>(s.x,s.wk,s.k,rows,c.hidden,kw);
    kernels::linear<<<blocks(rows*kw),256>>>(s.x,s.wv,s.v,rows,c.hidden,kw);
    kernels::normalize_qg<<<blocks(rows*c.query_heads),256>>>(s.qg,s.qn,s.q,s.gate,rows,c.query_heads,c.head_dim,float(c.epsilon));
    kernels::normalize_k<<<blocks(rows*c.kv_heads),256>>>(s.k,s.kn,rows*c.kv_heads,c.head_dim,float(c.epsilon));
    kernels::partial_rope<<<blocks(rows*c.query_heads*c.rotary_dim/2),256>>>(s.q,rows,c.query_heads,c.head_dim,c.rotary_dim,position,float(c.theta));
    kernels::partial_rope<<<blocks(rows*c.kv_heads*c.rotary_dim/2),256>>>(s.k,rows,c.kv_heads,c.head_dim,c.rotary_dim,position,float(c.theta));
    check(cudaGetLastError());check(cudaMemcpy(s.keys+position*kw,s.k,rows*kw*sizeof(float),cudaMemcpyDeviceToDevice));
    check(cudaMemcpy(s.values+position*kw,s.v,rows*kw*sizeof(float),cudaMemcpyDeviceToDevice));
    kernels::gated_gqa<<<blocks(rows*qw),256>>>(s.q,s.gate,s.keys,s.values,s.att,rows,position,c.query_heads,c.kv_heads,c.head_dim);
    kernels::linear<<<blocks(rows*c.hidden),256>>>(s.att,s.wo,s.out,rows,qw,c.hidden);
    check(cudaGetLastError());check(cudaDeviceSynchronize());
    AttentionTrace t;t.output=s.read(s.out,rows*c.hidden);
    if(trace){t.q=s.read(s.q,rows*qw);t.k=s.read(s.k,rows*kw);t.v=s.read(s.v,rows*kw);t.attention=s.read(s.att,rows*qw);}
    s.past+=rows;return t;
  }catch(...){s.valid=false;throw;}
}
}
