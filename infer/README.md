# neurx infer

This directory hosts inference-specific orchestration in S modules.

- decode: autoregressive decode state and step runner
- cache: kv-cache state for incremental decoding
- sampling: temperature/top-k/top-p sampling policy state
- serve: serving request/response state
- eval: inference evaluation state
- infer.s: unified inference entry points

The infer entry module is connected to ops-level generation APIs through logits-driven helpers.
