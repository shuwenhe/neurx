# NEURX Qwen2.5 Chinese + Multi-turn Fix Record

Date: 2026-11-26

## 1. Root Cause

Root cause is in GPU backend request handling, not model weights:

1. Single-read HTTP request handling (`__sys_read_string` once) caused partial-body parsing under TCP segmentation.
2. `prompt` parse failure silently fell back to `"Hello"`.
3. `stream` detection used brittle string matching and was affected by truncated bodies.

This produced:

- Chinese request occasionally becoming generic English response.
- Multi-turn second turn occasionally losing context and returning fallback-style output.

## 2. RED Evidence (before fix)

- Existing report showed Chinese and round-2 multi-turn fallback to generic English output.
- Backend logs showed `Extracted prompt: 'Hello'` on failed cases.

## 3. Fix Summary

Modified file:

- [`inference_server.s`](/home/shuwen/shuwen/neurx/backend/platform/cuda/inference_server.s)

Key changes:

1. Added full HTTP-body read by `Content-Length` (no one-shot read).
2. Parse `prompt` and `stream` from HTTP body only.
3. Removed silent `"Hello"` fallback.
4. Added explicit `400` rejection payload for invalid/missing prompt.
5. Added request-level trace fields:
   - request_id
   - session_id
   - prefill_start/end
   - decode_start/end
   - prompt_tokens
   - generated_tokens
   - kv_cache_length
   - attention_exec_count
   - lm_head_exec_count
   - kv_cache_updates
   - eos_reason
   - fallback_status

## 4. Added Regression Test

New test:

- [`test_gpu_backend_http_request_parsing.py`](/home/shuwen/shuwen/neurx/test/native-stage4/test_gpu_backend_http_request_parsing.py)

Covers:

- split-body Chinese stream request
- split-body multi-turn stream request
- missing prompt explicit error (no silent fallback)

Result:

- `Ran 3 tests ... OK`

## 5. GREEN Evidence

3-round real model acceptance after fix:

- English (A): all rounds stream success
- Chinese (B): all rounds stream success, no generic English fallback
- Mixed (C): all rounds stream success
- Multi-turn (D): all rounds stream success; round-2 correctly returns project name (`NeurX`)

## 6. Diff Scope

Files changed for this fix:

- [`inference_server.s`](/home/shuwen/shuwen/neurx/backend/platform/cuda/inference_server.s)
- [`test_gpu_backend_http_request_parsing.py`](/home/shuwen/shuwen/neurx/test/native-stage4/test_gpu_backend_http_request_parsing.py)
- [`NEURX_QWEN25_NATIVE_INFERENCE_ACCEPTANCE.md`](/home/shuwen/shuwen/neurx/docs/reports/NEURX_QWEN25_NATIVE_INFERENCE_ACCEPTANCE.md)
- [`NEURX_QWEN25_CHINESE_MULTITURN_FIX.md`](/home/shuwen/shuwen/neurx/docs/reports/NEURX_QWEN25_CHINESE_MULTITURN_FIX.md)

No changes to Qwen3.6 preflight rejection or external compiler repo.
