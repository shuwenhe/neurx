#include "ascend_worker.h"

#include <cstring>
#include <limits>
#include <string>
#include <utility>

namespace neurx::inference {
namespace {

float fp16_to_float(uint16_t value) {
  const uint32_t sign = static_cast<uint32_t>(value & 0x8000U) << 16;
  uint32_t exponent = (value >> 10) & 0x1fU;
  uint32_t mantissa = value & 0x03ffU;
  uint32_t bits = 0;
  if (exponent == 0) {
    if (mantissa == 0) {
      bits = sign;
    } else {
      int shift = 0;
      while ((mantissa & 0x0400U) == 0) {
        mantissa <<= 1;
        ++shift;
      }
      mantissa &= 0x03ffU;
      bits = sign | static_cast<uint32_t>(127 - 15 - shift) << 23 |
             mantissa << 13;
    }
  } else if (exponent == 0x1fU) {
    bits = sign | 0x7f800000U | mantissa << 13;
  } else {
    bits = sign | (exponent + 112U) << 23 | mantissa << 13;
  }
  float result = 0.0F;
  std::memcpy(&result, &bits, sizeof(result));
  return result;
}

}  // namespace

AscendWorker::AscendWorker(AscendExecutorConfig config)
    : executor_(std::move(config)) {}

AdapterStatus AscendWorker::initialize(int device_id) {
  return executor_.initialize(device_id);
}

AdapterStatus AscendWorker::ensure_capacity(cann::DeviceBuffer& buffer,
                                            std::size_t bytes,
                                            const char* name) {
  if (buffer.size() >= bytes) return AdapterStatus::success();
  const AdapterStatus synchronized = executor_.synchronize();
  if (!synchronized.ok) return synchronized;
  const cann::Status status = buffer.allocate(bytes);
  return status.ok
             ? AdapterStatus::success()
             : AdapterStatus::failure(std::string(name) + ": " +
                                      status.message);
}

AdapterStatus AscendWorker::ensure_capacity(cann::HostBuffer& buffer,
                                            std::size_t bytes,
                                            const char* name) {
  if (buffer.size() >= bytes) return AdapterStatus::success();
  const AdapterStatus synchronized = executor_.synchronize();
  if (!synchronized.ok) return synchronized;
  const cann::Status status = buffer.allocate(bytes);
  return status.ok
             ? AdapterStatus::success()
             : AdapterStatus::failure(std::string(name) + ": " +
                                      status.message);
}

AdapterStatus AscendWorker::execute(
    const Batch& batch, const std::vector<int32_t>& token_ids,
    const std::vector<SamplingConfig>& sampling,
    const std::vector<std::vector<int32_t>>& token_histories,
    WorkerBatchResult* result) {
  if (!ready()) return AdapterStatus::failure("Ascend worker is not initialized");
  if (!result) return AdapterStatus::failure("Ascend worker result is null");
  if (batch.items.empty() || batch.total_tokens <= 0 ||
      token_ids.size() != static_cast<std::size_t>(batch.total_tokens)) {
    return AdapterStatus::failure("Ascend worker batch token count is invalid");
  }
  const std::size_t batch_size = batch.items.size();
  if ((!sampling.empty() && sampling.size() != batch_size) ||
      (!token_histories.empty() && token_histories.size() != batch_size)) {
    return AdapterStatus::failure(
        "Ascend worker sampling metadata does not match batch size");
  }
  const std::size_t vocabulary = executor_.model().metadata().vocabulary;
  if (vocabulary == 0 ||
      batch_size > std::numeric_limits<std::size_t>::max() / vocabulary) {
    return AdapterStatus::failure("Ascend worker logits shape overflows size_t");
  }
  for (const int32_t token : token_ids) {
    if (token < 0 || static_cast<std::size_t>(token) >= vocabulary) {
      return AdapterStatus::failure(
          "Ascend worker token id is outside the model vocabulary");
    }
  }
  const std::size_t logit_count = batch_size * vocabulary;
  if (logit_count >
      std::numeric_limits<std::size_t>::max() / sizeof(uint16_t)) {
    return AdapterStatus::failure("Ascend worker logits allocation overflows size_t");
  }
  const std::size_t token_bytes = token_ids.size() * sizeof(int32_t);
  const std::size_t logit_bytes = logit_count * sizeof(uint16_t);

  if (cann::set_current_context(executor_.context()) != cann::kSuccess) {
    return AdapterStatus::failure(std::string("aclrtSetCurrentContext: ") +
                                  cann::recent_error());
  }
  AdapterStatus status =
      ensure_capacity(device_tokens_, token_bytes, "device token buffer");
  if (!status.ok) return status;
  status = ensure_capacity(device_logits_, logit_bytes, "device logits buffer");
  if (!status.ok) return status;
  status = ensure_capacity(host_tokens_, token_bytes, "host token buffer");
  if (!status.ok) return status;
  status = ensure_capacity(host_logits_, logit_bytes, "host logits buffer");
  if (!status.ok) return status;

  std::memcpy(host_tokens_.data(), token_ids.data(), token_bytes);
  if (cann::memcpy_async(device_tokens_.data(), device_tokens_.size(),
                         host_tokens_.data(), token_bytes,
                         cann::MemcpyKind::host_to_device,
                         executor_.stream()) != cann::kSuccess) {
    return AdapterStatus::failure(std::string("token H2D copy: ") +
                                  cann::recent_error());
  }

  DeviceBatch launch;
  launch.schedule = batch;
  launch.token_ids = device_tokens_.data();
  launch.logits = device_logits_.data();
  launch.stream = executor_.stream();
  status = executor_.execute(launch);
  if (!status.ok) return status;

  if (cann::memcpy_async(host_logits_.data(), host_logits_.size(),
                         device_logits_.data(), logit_bytes,
                         cann::MemcpyKind::device_to_host,
                         executor_.stream()) != cann::kSuccess) {
    for (const auto& item : batch.items) executor_.release_request(item.request_id);
    return AdapterStatus::failure(std::string("logits D2H copy: ") +
                                  cann::recent_error());
  }
  status = executor_.synchronize();
  if (!status.ok) {
    // An asynchronous device failure makes these requests' newly written KV
    // state unsafe to reuse.
    for (const auto& item : batch.items) executor_.release_request(item.request_id);
    return status;
  }

  result->logits.resize(logit_count);
  const auto* fp16 = static_cast<const uint16_t*>(host_logits_.data());
  for (std::size_t index = 0; index < logit_count; ++index) {
    result->logits[index] = fp16_to_float(fp16[index]);
  }
  result->next_tokens.resize(batch_size);
  const SamplingConfig default_sampling;
  const std::vector<int32_t> empty_history;
  for (std::size_t row = 0; row < batch_size; ++row) {
    const SamplingConfig& config =
        sampling.empty() ? default_sampling : sampling[row];
    const std::vector<int32_t>& history =
        token_histories.empty() ? empty_history : token_histories[row];
    status = sample_logits(result->logits.data() + row * vocabulary,
                           vocabulary, config, history,
                           &result->next_tokens[row]);
    if (!status.ok) {
      return AdapterStatus::failure(batch.items[row].request_id + ": " +
                                    status.message);
    }
  }
  return AdapterStatus::success();
}

}  // namespace neurx::inference
