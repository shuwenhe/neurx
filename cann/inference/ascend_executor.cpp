#include "ascend_executor.h"

#include <map>
#include <utility>

namespace neurx::inference {

AscendExecutor::AscendExecutor(AscendExecutorConfig config)
    : config_(std::move(config)), kv_cache_(config_.kv_cache) {}

AdapterStatus AscendExecutor::initialize(int device_id) {
  if (ready_) return AdapterStatus::success();
  auto status = operators_.load(config_.operator_library);
  if (!status.ok) return AdapterStatus::failure(status.message);
  adapter_.bind_launchers(operators_.prefill_launcher(),
                          operators_.decode_launcher());
  auto adapter_status = adapter_.initialize(device_id);
  if (!adapter_status.ok) return adapter_status;
  status = kv_cache_.initialize();
  if (!status.ok) return AdapterStatus::failure(status.message);
  status = model_.load(config_.checkpoint, adapter_.native_session(), config_.model);
  if (!status.ok) return AdapterStatus::failure(status.message);
  ready_ = true;
  return AdapterStatus::success();
}

AdapterStatus AscendExecutor::execute(const DeviceBatch& batch) {
  if (!ready_) return AdapterStatus::failure("Ascend executor is not initialized");
  if (batch.schedule.items.empty()) {
    return AdapterStatus::failure("Ascend executor received an empty device batch");
  }

  std::map<std::string, std::size_t> previous_tokens;
  for (const auto& item : batch.schedule.items) {
    const std::size_t previous = kv_cache_.token_count(item.request_id);
    previous_tokens.emplace(item.request_id, previous);
    const std::size_t added = batch.schedule.phase == Phase::decode
                                  ? 1
                                  : static_cast<std::size_t>(item.token_count);
    const auto status = kv_cache_.reserve(item.request_id, previous + added);
    if (!status.ok) {
      for (const auto& rollback : previous_tokens) {
        kv_cache_.resize(rollback.first, rollback.second);
      }
      return AdapterStatus::failure(item.request_id + ": " + status.message);
    }
  }

  DeviceBatch launch = batch;
  launch.model = &model_;
  launch.kv_cache = &kv_cache_;
  launch.batch_size = launch.schedule.items.size();
  launch.token_count = static_cast<std::size_t>(launch.schedule.total_tokens);
  const auto status = adapter_.execute(launch);
  if (!status.ok) {
    for (const auto& rollback : previous_tokens) {
      kv_cache_.resize(rollback.first, rollback.second);
    }
  }
  return status;
}

bool AscendExecutor::release_request(const std::string& request_id) {
  return kv_cache_.release(request_id);
}

}  // namespace neurx::inference
