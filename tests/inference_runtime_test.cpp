#include "../inference/runtime/inference_runtime.h"
#include "../cann/inference/ascend_adapter.h"
#include "../cann/hccl/hccl_dynamic.h"

#include <cassert>
#include <cstdio>

using neurx::inference::Backend;
using neurx::inference::batch_key;
using neurx::inference::DisaggregatedScheduler;
using neurx::inference::Phase;
using neurx::inference::RequestState;
using neurx::inference::runtime_config_2;

int main() {
  const auto cuda = neurx::inference::make_execution_plan(Backend::cuda, true);
  const auto ascend = neurx::inference::make_execution_plan(Backend::ascend, true);
  assert(cuda.dtype == "fp8" && cuda.collective == "NCCL" && cuda.use_cuda_or_acl_graph);
  assert(ascend.dtype == "fp16" && ascend.collective == "none (single-card replica)" &&
         ascend.use_cuda_or_acl_graph);

  neurx::inference::AscendAdapter ascend_adapter(nullptr, nullptr);
  const auto ascend_status = ascend_adapter.initialize(0);
  assert(ascend_status.ok ? ascend_adapter.ready() : !ascend_status.message.empty());
  const bool hccl_runtime_present = neurx::hccl::available();

  runtime_config_2 config;
  config.max_prefill_batch_tokens = 8;
  config.max_prefill_requests = 1;
  config.max_decode_batch_size = 4;
  DisaggregatedScheduler scheduler(config);
  scheduler.submit("cuda-long", {Backend::cuda, "bf16"}, 12, 3);
  scheduler.submit("cuda-short", {Backend::cuda, "bf16"}, 4, 2);
  scheduler.submit("ascend", {Backend::ascend, "fp16"}, 4, 2);

  auto prefill = scheduler.schedule();
  assert(prefill.phase == Phase::prefill && prefill.key.backend == Backend::cuda);
  assert(prefill.total_tokens == 8 && prefill.items.size() == 1 && prefill.items[0].request_id == "cuda-long");
  scheduler.complete_prefill("cuda-long", 8);

  prefill = scheduler.schedule();
  assert(prefill.phase == Phase::prefill && prefill.items[0].request_id == "cuda-short");
  scheduler.complete_prefill("cuda-short", 4);
  auto decode = scheduler.schedule();
  assert(decode.phase == Phase::decode && decode.key.backend == Backend::cuda);
  assert(decode.items.size() == 1 && decode.items[0].request_id == "cuda-short");
  scheduler.complete_decode("cuda-short");
  assert(scheduler.request("cuda-short").state == RequestState::queued_decode);

  decode = scheduler.schedule();
  assert(decode.phase == Phase::decode && decode.key.backend == Backend::cuda);
  scheduler.complete_decode("cuda-short", true);
  prefill = scheduler.schedule();
  assert(prefill.phase == Phase::prefill && prefill.key.backend == Backend::ascend);
  assert(prefill.items[0].request_id == "ascend");
  scheduler.complete_prefill("ascend", 4);
  decode = scheduler.schedule();
  assert(decode.phase == Phase::decode && decode.key.backend == Backend::ascend);
  scheduler.complete_decode("ascend", true);
  prefill = scheduler.schedule();
  assert(prefill.phase == Phase::prefill && prefill.key.backend == Backend::cuda);
  assert(prefill.items[0].request_id == "cuda-long" && prefill.total_tokens == 4);
  scheduler.complete_prefill("cuda-long", 4);
  decode = scheduler.schedule();
  assert(decode.phase == Phase::decode && decode.key.backend == Backend::cuda);
  scheduler.complete_decode("cuda-long", true);

  assert(scheduler.metrics().kv_handoffs == 3);
  assert(scheduler.metrics().generated_tokens == 4);
  std::printf("inference-runtime PASS cuda_attention=%s ascend_collective=%s hccl_runtime=%s kv_handoffs=%llu generated_tokens=%llu\n",
              cuda.attention.c_str(), ascend.collective.c_str(),
              hccl_runtime_present ? "available" : "unavailable",
              static_cast<unsigned long long>(scheduler.metrics().kv_handoffs),
              static_cast<unsigned long long>(scheduler.metrics().generated_tokens));
  return 0;
}
