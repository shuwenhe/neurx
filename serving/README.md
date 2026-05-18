# serving

This directory is the canonical home for NeurX serving runtime modules.

## Status

- Runtime S modules are currently implemented under `infer/` for compatibility.
- The Python runtime bridge now resolves `serving/*` module requests to `infer/*`.
- This allows incremental migration without breaking existing callers.

## Migration Plan

1. Keep authoring new serving control-plane APIs under `serving/` naming.
2. Keep runtime compatibility through module-name aliasing.
3. Move S sources from `infer/` to `serving/` in batches.
4. Remove alias only after all tests and downstream callers are updated.

## Priority Serving Modules

- `serving/serve/continuous_batch`
- `serving/cache/paged_kv_cache`
- `serving/cache/prefix_cache`
- `serving/decode/speculative_decode`
- `serving/serve/admission_control`
