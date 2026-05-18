# neurx infer

This directory hosts inference-specific orchestration in S modules.
It now serves as the compatibility layer while `serving/` becomes the canonical home for migrated runtime modules.

- decode: autoregressive decode state and step runner
- cache: kv-cache state for incremental decoding
- cache/paged_kv_cache: block-based paged kv-cache state
- cache/prefix_cache: prefix cache hit/miss and resident token accounting
- sampling: temperature/top-k/top-p sampling policy state
- serve: serving request/response state
- serve/continuous_batch: continuous batching scheduler state
- serve/admission_control: serving admission policy and counters
- vllm/request_queue: token-level request queue state
- vllm/scheduler: fcfs/srpt scheduler state and selection
- vllm/prefix_cache: vllm-facing prefix cache adapter
- vllm/paged_attention: vllm-facing paged attention state
- vllm/metrics: serving metrics state
- vllm/vllm: unified vllm runtime state
- eval: inference evaluation state
- infer.s: unified inference entry points

The infer entry module is connected to ops-level generation APIs through logits-driven helpers.
