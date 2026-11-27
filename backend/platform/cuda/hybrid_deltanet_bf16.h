#pragma once
#include "hybrid_deltanet_cuda.h"
#include <map>
#include <string>
namespace neurx::cuda::hybrid {
// Native B=1 recurrent implementation. GPU weights/activations/history use BF16,
// dot products and recurrent state use FP32. Host float vectors are transport.
class DeltaNetBF16Session {
 public:
  using Trace=std::map<std::string,std::vector<float>>;
  DeltaNetBF16Session(const DeltaConfig&,const DeltaWeights&,uint64_t budget,uint64_t headroom);
  ~DeltaNetBF16Session();
  DeltaNetBF16Session(const DeltaNetBF16Session&)=delete;
  DeltaNetBF16Session& operator=(const DeltaNetBF16Session&)=delete;
  Trace forward(const std::vector<float>&,int position);
  void reset(const std::vector<float>& state={},const std::vector<float>& history={});
  int length() const;
 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};
}
