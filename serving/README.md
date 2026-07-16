# serving

This directory is the canonical home for NeurX serving runtime modules.

## Status

- `serving/serve/admission_control.s` and `serving/serve/continuous_batch.s` now exist as canonical S sources.
- `serving/serve/serve.s` now owns the canonical request/response state plus the serving control plane.
- `serving/cache/kv_cache.s`, `serving/cache/paged_kv_cache.s`, `serving/cache/prefix_cache.s`, `serving/decode/decode.s`, and `serving/sampling/sampling.s` are also canonical.
- `serving/vllm/` now contains the canonical request queue, scheduler, metrics, prefix cache, paged attention, and runtime entrypoint.
- `serving/runtime/production_runtime.s` provides decode-priority disaggregated scheduling, homogeneous CUDA/Ascend batches, admission backpressure and explicit batch completion.
- `serving/protocol/openai_tgi.s` provides OpenAI and TGI route classification plus SSE wire-format encoding.
- `serving/security/request_governance.s` provides API-key fingerprint validation, tenant RBAC and token/request quotas.
- `serving/lifecycle/request_lifecycle.s` provides timeout, cancellation, bounded retry and graceful drain state.
- `serving/network/native_socket.s` binds the S control plane to the tested non-blocking POSIX socket ABI in `serving/native/`.
- `serving/cache/physical_paged_kv.s` owns physical device-address block tables, reference counts and shared prefixes.
- The runtime bridge prefers `serving/*` IR when available and falls back to `infer/*` for the remaining compatibility modules.
- More serving modules will move here in batches, starting with cache, decode, and sampling helpers.

## Migration Plan

1. Keep authoring new serving control-plane APIs under `serving/` naming.
2. Keep runtime compatibility through module-name aliasing.
3. Move the remaining S sources from `infer/` to `serving/` in batches.
4. Remove fallback alias only after all tests and downstream callers are updated.

## Priority Serving Modules

- `serving/serve/serve`
- `serving/serve/continuous_batch`
- `serving/cache/paged_kv_cache`
- `serving/cache/prefix_cache`
- `serving/decode/speculative_decode`
- `serving/serve/admission_control`
