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
class ascend_executor final : public backend_adapter {
 public:
  explicit ascend_executor(ascend_executor_config config);
  ~ascend_executor() override = default;
  backend kind() const override { return backend::ascend; }
  const char* name() const override { return "ascend-cann-executor"; }
  adapter_status initialize(int device_id) override;
  bool ready() const override { return ready_; }
  adapter_status execute(const device_batch& batch) override;
  adapter_status synchronize() override { return adapter_.synchronize(); }
  bool release_request(const std::string& request_id);
  const cann::nxtrfmv2_model& model() const { return model_; }
  const cann::paged_kv_cache& kv_cache() const { return kv_cache_; }
  cann::paged_kv_cache& mutable_kv_cache() { return kv_cache_; }
  cann::stream stream() const { return adapter_.native_session().stream(); }
  cann::context context() const { return adapter_.native_session().context(); }
 private:
  ascend_executor_config config_;
  ascend_adapter adapter_;
  cann::operator_library operators_;
  cann::nxtrfmv2_model model_;
  cann::paged_kv_cache kv_cache_;
  bool ready_ = false;
};
}
