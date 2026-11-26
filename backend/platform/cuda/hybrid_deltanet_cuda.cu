#include "hybrid_deltanet_cuda.h"
#include "gated_deltanet_kernels.cuh"
#include <cuda_runtime.h>
#include <climits>
#include <cmath>
#include <limits>
#include <mutex>
#include <stdexcept>
namespace neurx::cuda::hybrid {
namespace {
void check(cudaError_t error) {
  if(error!=cudaSuccess)throw std::runtime_error(cudaGetErrorString(error));
}
uint64_t multiply(uint64_t a,uint64_t b) {
  if(b&&a>std::numeric_limits<uint64_t>::max()/b)throw std::invalid_argument("size overflow");
  return a*b;
}
void finite(const std::vector<float>& values) {
  for(float x:values)if(!std::isfinite(x))throw std::invalid_argument("nonfinite tensor");
}
int blocks(int count){return (count+255)/256;}
}
struct DeltaNetSession::Impl {
  DeltaConfig c;
  uint64_t budget,headroom,used=0;
  int device=0,past=0,kw=0,vw=0,raw=0,state_count=0,history_count=0;
  bool valid=false;
  std::mutex mutex;
  std::vector<float*> allocations;
  float *wqkv=nullptr,*wz=nullptr,*wa=nullptr,*wb=nullptr,*wc=nullptr;
  float *alog=nullptr,*dt=nullptr,*norm=nullptr,*wo=nullptr;
  float *state=nullptr,*history=nullptr,*x=nullptr,*raw_values=nullptr,*zs=nullptr;
  float *as=nullptr,*bs=nullptr,*output=nullptr,*activated=nullptr,*q=nullptr,*k=nullptr;
  float *core=nullptr,*gated=nullptr,*beta=nullptr,*decay=nullptr;
  Impl(const DeltaConfig& config,uint64_t b,uint64_t h):c(config),budget(b),headroom(h) {
    check(cudaGetDevice(&device));
  }
  ~Impl() {
    int previous=0;cudaGetDevice(&previous);cudaSetDevice(device);
    for(float* p:allocations)cudaFree(p);
    cudaSetDevice(previous);
  }
  float* allocate(uint64_t count) {
    uint64_t bytes=multiply(count,sizeof(float));
    size_t free=0,total=0;check(cudaMemGetInfo(&free,&total));
    if(bytes>budget-used||headroom>free||bytes>free-headroom)
      throw std::runtime_error("GPU memory admission rejected");
    float* p=nullptr;check(cudaMalloc(&p,bytes));
    try {
      // Account for allocator granularity as well as requested tensor bytes.
      check(cudaMemGetInfo(&free,&total));
      if(free<headroom)throw std::runtime_error("GPU headroom admission rejected");
      allocations.push_back(p);
    }catch(...){cudaFree(p);throw;}
    used+=bytes;return p;
  }
  float* weight(const std::vector<float>& values,uint64_t count) {
    if(values.size()!=count)throw std::invalid_argument("weight shape mismatch");
    finite(values);float* p=allocate(count);
    check(cudaMemcpy(p,values.data(),count*sizeof(float),cudaMemcpyHostToDevice));return p;
  }
  void same_device() {
    int current=0;check(cudaGetDevice(&current));
    if(current!=device)throw std::runtime_error("session device mismatch");
  }
  void append(std::vector<float>& target,const float* source,int count) {
    size_t start=target.size();target.resize(start+count);
    check(cudaMemcpy(target.data()+start,source,count*sizeof(float),cudaMemcpyDeviceToHost));
    for(size_t i=start;i<target.size();++i)
      if(!std::isfinite(target[i]))throw std::runtime_error("nonfinite execution result");
  }
};
DeltaNetSession::DeltaNetSession(const DeltaConfig& c,const DeltaWeights& w,
                               uint64_t budget,uint64_t headroom) {
  if(c.hidden<=0||c.key_heads<=0||c.value_heads<=0||c.key_dim<=0||c.value_dim<=0||
     c.value_heads%c.key_heads||c.conv_kernel<=0||c.context<=0||c.max_chunk<=0||
     c.max_chunk>c.context||!std::isfinite(c.epsilon)||!std::isfinite(float(c.epsilon))||
     float(c.epsilon)<=0)throw std::invalid_argument("invalid deltanet config");
  uint64_t kw=multiply(c.key_heads,c.key_dim),vw=multiply(c.value_heads,c.value_dim);
  // Compute widths in checked/wide arithmetic before narrowing kernel indices.
  uint64_t raw=2*kw+vw,sc=multiply(multiply(c.value_heads,c.key_dim),c.value_dim);
  uint64_t hc=multiply(raw,c.conv_kernel);
  for(uint64_t n:{raw,kw,vw,sc,hc,multiply(raw,c.hidden),multiply(vw,c.hidden),
      multiply(c.value_heads,c.hidden),multiply(c.max_chunk,raw),multiply(c.max_chunk,vw),
      multiply(c.max_chunk,c.value_heads),multiply(c.max_chunk,c.hidden)})
    if(n>INT_MAX-256)throw std::invalid_argument("deltanet span exceeds int kernel limit");
  impl_=std::make_unique<Impl>(c,budget,headroom);auto& s=*impl_;
  s.kw=int(kw);s.vw=int(vw);s.raw=int(raw);s.state_count=int(sc);s.history_count=int(hc);
  s.wqkv=s.weight(w.qkv,multiply(raw,c.hidden));s.wz=s.weight(w.z,multiply(vw,c.hidden));
  s.wa=s.weight(w.a,multiply(c.value_heads,c.hidden));s.wb=s.weight(w.b,multiply(c.value_heads,c.hidden));
  s.wc=s.weight(w.conv,hc);s.alog=s.weight(w.alog,c.value_heads);s.dt=s.weight(w.dt,c.value_heads);
  s.norm=s.weight(w.norm,c.value_dim);s.wo=s.weight(w.out,multiply(c.hidden,vw));
  s.state=s.allocate(sc);s.history=s.allocate(hc);
  s.x=s.allocate(multiply(c.max_chunk,c.hidden));s.raw_values=s.allocate(multiply(c.max_chunk,raw));
  s.zs=s.allocate(multiply(c.max_chunk,vw));s.as=s.allocate(multiply(c.max_chunk,c.value_heads));
  s.bs=s.allocate(multiply(c.max_chunk,c.value_heads));s.output=s.allocate(multiply(c.max_chunk,c.hidden));
  s.activated=s.allocate(raw);s.q=s.allocate(kw);s.k=s.allocate(kw);
  s.core=s.allocate(vw);s.gated=s.allocate(vw);s.beta=s.allocate(c.value_heads);s.decay=s.allocate(c.value_heads);
  reset();
}
DeltaNetSession::~DeltaNetSession()=default;
int DeltaNetSession::length()const {
  std::lock_guard<std::mutex> lock(impl_->mutex);return impl_->past;
}
uint64_t DeltaNetSession::allocated_bytes()const{return impl_->used;}
void DeltaNetSession::reset(const std::vector<float>& state,const std::vector<float>& history) {
  auto& s=*impl_;std::lock_guard<std::mutex> lock(s.mutex);s.same_device();
  if((!state.empty()&&state.size()!=size_t(s.state_count))||
     (!history.empty()&&history.size()!=size_t(s.history_count)))throw std::invalid_argument("initial state/history shape mismatch");
  finite(state);finite(history);s.valid=false;
  if(state.empty())check(cudaMemset(s.state,0,s.state_count*sizeof(float)));
  else check(cudaMemcpy(s.state,state.data(),state.size()*sizeof(float),cudaMemcpyHostToDevice));
  if(history.empty())check(cudaMemset(s.history,0,s.history_count*sizeof(float)));
  else check(cudaMemcpy(s.history,history.data(),history.size()*sizeof(float),cudaMemcpyHostToDevice));
  check(cudaDeviceSynchronize());s.past=0;s.valid=true;
}
DeltaTrace DeltaNetSession::forward(const std::vector<float>& input,int position,bool trace) {
  auto& s=*impl_;std::lock_guard<std::mutex> lock(s.mutex);s.same_device();const auto& c=s.c;
  if(!s.valid)throw std::runtime_error("invalid session: reset required");
  if(input.empty()||input.size()%c.hidden)throw std::invalid_argument("input shape mismatch");
  uint64_t count=input.size()/c.hidden;
  if(position!=s.past||count>uint64_t(c.max_chunk)||count>uint64_t(c.context-s.past))
    throw std::invalid_argument("position/chunk/context mismatch");
  uint64_t trace_per=uint64_t(c.hidden)+s.vw+s.state_count+s.history_count+2ULL*s.kw+2ULL*c.value_heads;
  if(trace&&multiply(multiply(count,trace_per),sizeof(float))>(64ULL<<20))
    throw std::invalid_argument("trace exceeds 64MiB host budget");
  finite(input);int rows=int(count);DeltaTrace result;
  try {
    // Reserve final element storage before mutating GPU state. Incremental
    // vector growth can exceed the trace cap and briefly retain old buffers.
    result.output.reserve(input.size());
    if(trace) {
      result.core.reserve(multiply(count,s.vw));
      result.state.reserve(multiply(count,s.state_count));
      result.history.reserve(multiply(count,s.history_count));
      result.q.reserve(multiply(count,s.kw));result.k.reserve(multiply(count,s.kw));
      result.beta.reserve(multiply(count,c.value_heads));
      result.decay.reserve(multiply(count,c.value_heads));
      uint64_t capacity=result.output.capacity()+result.core.capacity()+result.state.capacity()+
          result.history.capacity()+result.q.capacity()+result.k.capacity()+
          result.beta.capacity()+result.decay.capacity();
      if(multiply(capacity,sizeof(float))>(64ULL<<20))
        throw std::runtime_error("trace capacity exceeds 64MiB host budget");
    }
    check(cudaMemcpy(s.x,input.data(),input.size()*sizeof(float),cudaMemcpyHostToDevice));
    delta_kernels::project<<<blocks(rows*s.raw),256>>>(s.x,s.wqkv,s.raw_values,rows,c.hidden,s.raw);
    delta_kernels::project<<<blocks(rows*s.vw),256>>>(s.x,s.wz,s.zs,rows,c.hidden,s.vw);
    delta_kernels::project<<<blocks(rows*c.value_heads),256>>>(s.x,s.wa,s.as,rows,c.hidden,c.value_heads);
    delta_kernels::project<<<blocks(rows*c.value_heads),256>>>(s.x,s.wb,s.bs,rows,c.hidden,c.value_heads);
    check(cudaGetLastError());
    for(int t=0;t<rows;++t) {
      delta_kernels::causal_conv<<<blocks(s.raw),256>>>(s.raw_values+t*s.raw,s.wc,s.history,s.activated,s.raw,c.conv_kernel);
      delta_kernels::normalize_qk<<<blocks(c.key_heads),256>>>(s.activated,s.q,s.k,c.key_heads,c.key_dim);
      delta_kernels::gates<<<blocks(c.value_heads),256>>>(s.as+t*c.value_heads,s.bs+t*c.value_heads,s.alog,s.dt,s.beta,s.decay,c.value_heads);
      delta_kernels::recurrence<<<blocks(s.vw),256>>>(s.q,s.k,s.activated,s.beta,s.decay,s.state,s.core,c.key_heads,c.value_heads,c.key_dim,c.value_dim);
      delta_kernels::norm_gate<<<blocks(c.value_heads),256>>>(s.core,s.zs+t*s.vw,s.norm,s.gated,c.value_heads,c.value_dim,float(c.epsilon));
      delta_kernels::project<<<blocks(c.hidden),256>>>(s.gated,s.wo,s.output+t*c.hidden,1,s.vw,c.hidden);
      check(cudaGetLastError());
      if(trace) {
        s.append(result.core,s.core,s.vw);s.append(result.state,s.state,s.state_count);
        s.append(result.history,s.history,s.history_count);s.append(result.q,s.q,s.kw);s.append(result.k,s.k,s.kw);
        s.append(result.beta,s.beta,c.value_heads);s.append(result.decay,s.decay,c.value_heads);
      }
    }
    check(cudaDeviceSynchronize());s.append(result.output,s.output,rows*c.hidden);
    s.past+=rows;return result;
  }catch(...){s.valid=false;throw;}
}
}
