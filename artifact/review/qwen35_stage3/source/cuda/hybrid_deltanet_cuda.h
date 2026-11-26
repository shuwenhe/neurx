#pragma once
#include <cstdint>
#include <memory>
#include <vector>
namespace neurx::cuda::hybrid {
// B=1 FP32 baseline; input is already layer-normalized. Row-major weights.
// Build with --fmad=false and without fast-math. No BF16 arithmetic claim.
struct DeltaConfig {
  int hidden,key_heads,value_heads,key_dim,value_dim,conv_kernel;
  int context,max_chunk;
  double epsilon;
};
struct DeltaWeights {
  std::vector<float> qkv,z,a,b,conv,alog,dt,norm,out;
};
// Trace is token-major. state[T,VH,KD,VD], history[T,raw,K],
// q/k[T,KH,KD], core[T,VH,VD], beta/decay[T,VH].
struct DeltaTrace {
  std::vector<float> output,core,state,history,q,k,beta,decay;
};
class DeltaNetSession {
 public:
  DeltaNetSession(const DeltaConfig&,const DeltaWeights&,uint64_t budget_bytes,
                  uint64_t headroom_bytes);
  ~DeltaNetSession();
  DeltaNetSession(const DeltaNetSession&)=delete;
  DeltaNetSession& operator=(const DeltaNetSession&)=delete;
  DeltaTrace forward(const std::vector<float>& input,int position,bool trace=false);
  // Empty vectors mean zero state/history. Nonempty vectors must match exactly.
  // A supplied initial history is chronological oldest->newest raw QKV.
  void reset(const std::vector<float>& state={},const std::vector<float>& history={});
  int length() const;
  uint64_t allocated_bytes() const;
 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};
}
