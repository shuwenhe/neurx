#pragma once

#include "ascend_adapter.h"
#include "../cache/paged_kv_cache.h"
#include "../model/nxtrfmv2_loader.h"
#include "../operators/operator_library.h"

#include <string>

namespace neurx::inference {

struct AscendExecutorConfig {
  std::string operator_library;
  std::string checkpoint;
  cann::ModelLoadOptions model;
  cann::KvCacheConfig kv_cache;
};

// Complete CANN data-plane owner. The generic scheduler supplies DeviceBatch
// metadata; this class owns the device session, model, operator plugin and KV
// memory associated with exactly one NPU worker.
class AscendExecutor final : public BackendAdapter {
 public:
  explicit AscendExecutor(AscendExecutorConfig config);
  ~AscendExecutor() override = default;

  Backend kind() const override { return Backend::ascend; }
  const char* name() const override { return "ascend-cann-executor"; }
  AdapterStatus initialize(int device_id) override;
  bool ready() const override { return ready_; }
  AdapterStatus execute(const DeviceBatch& batch) override;
  AdapterStatus synchronize() override { return adapter_.synchronize(); }

  bool release_request(const std::string& request_id);
  const cann::Nxtrfmv2Model& model() const { return model_; }
  const cann::PagedKvCache& kv_cache() const { return kv_cache_; }

 private:
  AscendExecutorConfig config_;
  cann::OperatorLibrary operators_;
  AscendAdapter adapter_;
  cann::Nxtrfmv2Model model_;
  cann::PagedKvCache kv_cache_;
  bool ready_ = false;
};

}  // namespace neurx::inference
