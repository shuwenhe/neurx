# serving

This directory is the canonical home for NeurX serving runtime modules.

## Status

- `serving/serve/admission_control.s` and `serving/serve/continuous_batch.s` now exist as canonical S sources.
- `serving/serve/serve.s` now owns the canonical request/response state plus the serving control plane.
- `serving/cache/kv_cache.s`, `serving/cache/paged_kv_cache.s`, `serving/cache/prefix_cache.s`, `serving/decode/decode.s`, and `serving/sampling/sampling.s` are also canonical.
- `serving/vllm/` now contains the canonical request queue, scheduler, metrics, prefix cache, paged attention, and runtime entrypoint.
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
