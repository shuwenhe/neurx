#pragma once
#include <cstdint>
#include <memory>
#include <vector>

namespace neurx::cuda::hybrid {
// B=1 text-only FP32 correctness baseline. Weights row-major [out,in].
// Build contract: --fmad=false, no --use_fast_math; changed math flags require
// independent numerical revalidation. Calls synchronize the default stream.
struct AttentionConfig {
  int hidden, query_heads, kv_heads, head_dim, rotary_dim, context, max_chunk;
  double theta, epsilon;
};
struct AttentionWeights { std::vector<float> qg,k,v,o,qnorm,knorm; };
struct AttentionTrace { std::vector<float> output,q,k,v,attention; };
class FullAttentionSession {
 public:
  // Budget covers every cudaMalloc in this session including weights/workspace.
  // Headroom is additionally preserved against measured free memory.
  FullAttentionSession(const AttentionConfig&,const AttentionWeights&,
                       uint64_t budget_bytes,uint64_t headroom_bytes);
  ~FullAttentionSession();
  FullAttentionSession(const FullAttentionSession&)=delete;
  FullAttentionSession& operator=(const FullAttentionSession&)=delete;
  AttentionTrace forward(const std::vector<float>& input,int position,bool trace=false);
  void reset();
  int length() const;
  uint64_t allocated_bytes() const;
 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};
}
