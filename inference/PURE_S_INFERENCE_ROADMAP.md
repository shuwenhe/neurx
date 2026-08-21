# NeurX Inference Roadmap

This repository already has a real GPU inference path. The goal is to make the boundary explicit:

- `S` owns orchestration, request handling, prompt construction, sampling, and streaming.
- CUDA owns tensor math, attention, KV cache kernels, and device memory access.
- CPU fallback stays disabled for production GPU chat.

## Current Target

- Real model-backed inference on local NVIDIA GPU.
- No Ollama.
- No Python runtime in the inference loop.
- No PyTorch in the inference loop.
- No silent CPU fallback.

## What To Keep In `S`

- Chat/session lifecycle.
- Prompt templating and special-token handling.
- Tokenization and detokenization.
- Prefill/decode control flow.
- Stop conditions.
- Sampling policy.
- HTTP and SSE serving glue.

## What To Keep In CUDA

- Matmul and fused GEMM-style kernels.
- RMSNorm and activation kernels.
- RoPE.
- GQA attention and KV cache updates.
- Logit projection.
- GPU memory transfers and stream management.

## What Not To Do

- Do not reintroduce CPU as an implicit fallback path.
- Do not keep fake tokenizer or hash-based stand-ins in the production path.
- Do not mix demo-only code with the production GPU launcher.
- Do not claim a "pure S" inference engine when the math still runs in a C++/CUDA backend.

## Next Implementation Steps

1. Replace any remaining fake tokenizer or prompt stubs in the GPU path with the real Qwen tokenizer.
2. Move sampling and stop-token handling fully into the S control plane.
3. Keep CUDA limited to a small ABI: initialize, prefill, decode, fetch logits/result, and free cache.
4. Add golden tests for hello, identity, Chinese code generation, and formatting.
5. Measure prompt latency, decode throughput, and memory use on the local GPU.

## Acceptance Criteria

- `make chat-gpu` starts without CPU inference.
- The backend refuses to start if no local CUDA GPU is available.
- The chat path returns formatted, multi-turn-safe output.
- Golden prompts remain stable across restarts.
- The repository no longer describes CPU-backed inference as the main production path.
