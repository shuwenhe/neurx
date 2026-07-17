#pragma once

#include <algorithm>
#include <cstdint>
#include <map>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

// Control-plane runtime for a decoder-only model.  Device adapters execute the
// batches produced here; this layer deliberately owns no device memory and is
// therefore deterministic and testable without CUDA/CANN hardware.
namespace neurx::inference {

enum class Backend { cuda, ascend, cpu };
enum class Phase { prefill, decode };
enum class RequestState { queued_prefill, prefilling, queued_decode, decoding, finished };

inline const char* backend_name(Backend backend) {
  switch (backend) {
    case Backend::cuda: return "cuda";
    case Backend::ascend: return "ascend";
    case Backend::cpu: return "cpu";
  }
  return "unknown";
}

struct BackendCapabilities {
  Backend backend;
  bool fp16;
  bool bf16;
  bool fp8;
  bool paged_attention;
  bool graph_decode;
  const char* attention_kernel;
  const char* collective;
  const char* kv_transfer;
};

inline BackendCapabilities capabilities(Backend backend) {
  switch (backend) {
    case Backend::cuda:
      return {backend, true, true, true, true, true, "FlashAttention/paged-attention", "NCCL", "cudaMemcpyPeerAsync/RDMA"};
    case Backend::ascend:
      return {backend, true, false, false, true, true, "CANN paged-attention", "none (single-card replica)", "ACL runtime"};
    case Backend::cpu:
      return {backend, false, false, false, false, false, "reference attention", "none", "host memcpy"};
  }
  throw std::logic_error("unreachable backend");
}

struct ExecutionPlan {
  Backend backend;
  std::string dtype;
  std::string attention;
  std::string collective;
  bool use_cuda_or_acl_graph;
  bool fuse_rmsnorm_qkv;
  bool fuse_logits_sampling;
};

inline ExecutionPlan make_execution_plan(Backend backend, bool fp8_requested) {
  const auto caps = capabilities(backend);
  return {backend,
          fp8_requested && caps.fp8
              ? "fp8"
              : (caps.bf16 ? "bf16" : (caps.fp16 ? "fp16" : "fp32")),
          caps.attention_kernel,
          caps.collective,
          caps.graph_decode,
          backend != Backend::cpu,
          backend != Backend::cpu};
}

struct BatchKey {
  Backend backend = Backend::cpu;
  std::string dtype = "fp32";

  bool operator==(const BatchKey& other) const { return backend == other.backend && dtype == other.dtype; }
};

struct Request {
  std::string id;
  BatchKey key;
  int prompt_tokens = 0;
  int remaining_prompt_tokens = 0;
  int max_new_tokens = 0;
  int generated_tokens = 0;
  RequestState state = RequestState::queued_prefill;
};

struct WorkItem {
  std::string request_id;
  int token_count = 0;
};

struct Batch {
  Phase phase = Phase::prefill;
  BatchKey key;
  std::vector<WorkItem> items;
  int total_tokens = 0;
};

struct RuntimeConfig {
  int max_prefill_batch_tokens = 4096;
  int max_prefill_requests = 16;
  int max_decode_batch_size = 64;
  // Decode is scheduled first so time-to-next-token is bounded even while a
  // large prompt is arriving.  Prefill remains independent and chunked.
  bool prioritize_decode = true;
};

struct RuntimeMetrics {
  uint64_t prefills_started = 0;
  uint64_t decode_steps = 0;
  uint64_t prefetched_tokens = 0;
  uint64_t generated_tokens = 0;
  uint64_t kv_handoffs = 0;
};

class DisaggregatedScheduler {
 public:
  explicit DisaggregatedScheduler(RuntimeConfig config) : config_(config) {
    if (config_.max_prefill_batch_tokens <= 0 || config_.max_prefill_requests <= 0 ||
        config_.max_decode_batch_size <= 0) {
      throw std::invalid_argument("inference scheduler limits must be positive");
    }
  }

  void submit(std::string id, BatchKey key, int prompt_tokens, int max_new_tokens) {
    if (id.empty() || requests_.count(id) || prompt_tokens < 0 || max_new_tokens <= 0) {
      throw std::invalid_argument("invalid or duplicate inference request");
    }
    Request request{std::move(id), std::move(key), prompt_tokens, prompt_tokens, max_new_tokens};
    const std::string request_id = request.id;
    requests_.emplace(request_id, std::move(request));
    // Empty prompts skip prompt execution but still use the same decode lane.
    if (prompt_tokens == 0) {
      requests_.at(request_id).state = RequestState::queued_decode;
      decode_queue_.push_back(request_id);
    } else {
      prefill_queue_.push_back(request_id);
    }
  }

  // Returns at most one homogeneous device batch. Call complete_prefill or
  // complete_decode before scheduling the same request again.
  Batch schedule() {
    if (config_.prioritize_decode && !decode_queue_.empty()) return take_decode_batch();
    if (!prefill_queue_.empty()) return take_prefill_batch();
    if (!decode_queue_.empty()) return take_decode_batch();
    return {};
  }

  void complete_prefill(const std::string& id, int processed_tokens) {
    Request& request = mutable_request(id, RequestState::prefilling);
    if (processed_tokens <= 0 || processed_tokens > request.remaining_prompt_tokens) {
      throw std::invalid_argument("invalid prefill completion token count");
    }
    request.remaining_prompt_tokens -= processed_tokens;
    metrics_.prefetched_tokens += static_cast<uint64_t>(processed_tokens);
    if (request.remaining_prompt_tokens == 0) {
      request.state = RequestState::queued_decode;
      decode_queue_.push_back(id);
      ++metrics_.kv_handoffs;
    } else {
      request.state = RequestState::queued_prefill;
      prefill_queue_.push_back(id);
    }
  }

  // A decode completion produces exactly one token.  EOS must be supplied by
  // the backend sampler; max_new_tokens is enforced here as a safety bound.
  void complete_decode(const std::string& id, bool eos = false) {
    Request& request = mutable_request(id, RequestState::decoding);
    ++request.generated_tokens;
    ++metrics_.decode_steps;
    ++metrics_.generated_tokens;
    if (eos || request.generated_tokens >= request.max_new_tokens) {
      request.state = RequestState::finished;
    } else {
      request.state = RequestState::queued_decode;
      decode_queue_.push_back(id);
    }
  }

  const Request& request(const std::string& id) const {
    const auto it = requests_.find(id);
    if (it == requests_.end()) throw std::out_of_range("unknown inference request");
    return it->second;
  }
  const RuntimeMetrics& metrics() const { return metrics_; }

 private:
  Batch take_decode_batch() {
    return take_homogeneous_batch(decode_queue_, Phase::decode, config_.max_decode_batch_size, 0);
  }

  Batch take_prefill_batch() {
    return take_homogeneous_batch(prefill_queue_, Phase::prefill, config_.max_prefill_requests,
                                  config_.max_prefill_batch_tokens);
  }

  Batch take_homogeneous_batch(std::vector<std::string>& queue, Phase phase, int item_limit, int token_limit) {
    Batch batch;
    batch.phase = phase;
    const std::string first_id = queue.front();
    batch.key = requests_.at(first_id).key;
    std::vector<std::string> deferred;
    while (!queue.empty() && static_cast<int>(batch.items.size()) < item_limit) {
      const std::string id = queue.front();
      queue.erase(queue.begin());
      Request& request = requests_.at(id);
      if (!(request.key == batch.key)) { deferred.push_back(id); continue; }
      const int tokens = phase == Phase::decode ? 1 : std::min(request.remaining_prompt_tokens, token_limit - batch.total_tokens);
      if (tokens <= 0) { deferred.push_back(id); continue; }
      request.state = phase == Phase::decode ? RequestState::decoding : RequestState::prefilling;
      batch.items.push_back({id, tokens});
      batch.total_tokens += tokens;
      if (phase == Phase::prefill) ++metrics_.prefills_started;
      if (token_limit > 0 && batch.total_tokens >= token_limit) break;
    }
    queue.insert(queue.begin(), deferred.begin(), deferred.end());
    return batch;
  }

  Request& mutable_request(const std::string& id, RequestState expected) {
    Request& request = const_cast<Request&>(this->request(id));
    if (request.state != expected) throw std::logic_error("inference request completed in wrong phase");
    return request;
  }

  RuntimeConfig config_;
  RuntimeMetrics metrics_;
  std::map<std::string, Request> requests_;
  std::vector<std::string> prefill_queue_;
  std::vector<std::string> decode_queue_;
};

}  // namespace neurx::inference
