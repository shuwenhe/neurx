#pragma once

#include "ascend_adapter.h"
#include "../cache/paged_kv_cache.h"
#include "../model/nxtrfmv2_loader.h"
#include "../operators/operator_library.h"

#include <string>

namespace neurx::inference {

struct ascend_executor_config {
  std::string operator_library;
  std::string checkpoint;
  cann::model_load_options model;
  cann::kv_cache_config_2 kv_cache;
};

class AscendExecutor final : public BackendAdapter {
 public:
  explicit AscendExecutor(ascend_executor_config config);
  ~AscendExecutor() override = default;

  Backend kind() const override { return Backend::ascend; }
  const char* name() const override { return "ascend-cann-executor"; }
  adapter_status initialize(int device_id) override;
  bool ready() const override { return ready_; }
  adapter_status execute(const device_batch& batch) override;
  adapter_status synchronize() override { return adapter_.synchronize(); }

  bool release_request(const std::string& request_id);
  const cann::Nxtrfmv2Model& model() const { return model_; }
  const cann::PagedKvCache& kv_cache() const { return kv_cache_; }
  cann::PagedKvCache& mutable_kv_cache() { return kv_cache_; }
  cann::Stream stream() const { return adapter_.native_session().stream(); }
  cann::Context context() const { return adapter_.native_session().context(); }

 private:
  ascend_executor_config config_;
  AscendAdapter adapter_;

  cann::OperatorLibrary operators_;
  cann::Nxtrfmv2Model model_;
  cann::PagedKvCache kv_cache_;
  bool ready_ = false;
};

}
