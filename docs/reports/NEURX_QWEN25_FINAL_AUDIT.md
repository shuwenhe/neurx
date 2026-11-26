# NEURX Qwen2.5 Final Independent Audit (Pre-commit)

Date: 2026-11-26  
Workspace: `/home/shuwen/shuwen/neurx`

## 1) Scope

Audited:

- HTTP parsing hardening in [`inference_server.s`](/home/shuwen/shuwen/neurx/backend/platform/cuda/inference_server.s)
- Trace authenticity and semantics
- Multi-turn/session/KV-cache claims
- Real-model revalidation (Qwen2.5 + DeepSeek-V2-Lite)
- Regression/test status before commit

## 2) HTTP fix audit

### PASS

- 分块读取已实现（按 `Content-Length` 继续读取，不再单次 read）。
- Header/body 分离已实现。
- 缺失 prompt 返回 400（显式 JSON 错误，不再静默 `"Hello"` fallback）。
- 非法 JSON/截断导致 prompt 解析失败时返回 400。

### PARTIAL

- `Content-Length` 过大（大于实际发送）场景：当前仍可能处理“已收到部分 body”并继续生成。
- duplicate key 场景：按首次匹配解析（行为可预期但非严格 JSON 语义校验）。

### UNVERIFIED

- 严格 UTF-8 非法字节在所有路径都能稳定拒绝（值内非法字节仍可被替换后进入生成路径）。

## 3) Trace authenticity audit

结论：**PASS（语义已校正）**

- 已明确将计数字段改为 loop 计数：
  - `attention_loop_count`
  - `lm_head_loop_count`
  - `kv_cache_loop_updates`
  - `trace_counter_scope=generated_loop`
- 不再将其描述为 CUDA kernel 实际执行计数。

## 4) Multi-turn / session / KV cache audit

- Prompt history correctness: **PASS**
- Session persistence (cross-request runtime session): **PARTIAL**  
  证据：每个请求重新 `session_create/session_destroy`。
- KV cache cross-request reuse: **UNVERIFIED / no implementation evidence**  
  目前仅可证明单请求内 prefill+decode。

## 5) Revalidation results

### Qwen2.5 native GPU

- 英文/中文/中英混合：流式生成成功，`done=true`。
- 三轮连续多轮：可持续回答，第二轮可回答项目名语义。

### DeepSeek-V2-Lite regression

- Preflight: PASS
- Native GPU smoke: PASS（流式 `done=true`，有真实 token 生成）

### Dense regression

- Qwen2.5（dense）链路本轮已重复验证：PASS（在本次审计范围内）

## 6) Test execution summary

- ✅ `python3 test/native-stage4/test_gpu_backend_http_request_parsing.py`
- ❌ `python3 test/native-stage4/test_serving.py`  
  失败根因：`unresolved external function: neurx.runtime.tensor_builder.__native_builder_new`
- ✅ Qwen2.5 native GPU revalidation (custom audit harness)
- ✅ DeepSeek-V2-Lite native GPU smoke (custom audit harness)

## 7) Git and change boundaries

Changed (this round):

- [`inference_server.s`](/home/shuwen/shuwen/neurx/backend/platform/cuda/inference_server.s)
- [`test_gpu_backend_http_request_parsing.py`](/home/shuwen/shuwen/neurx/test/native-stage4/test_gpu_backend_http_request_parsing.py)
- [`NEURX_QWEN25_NATIVE_INFERENCE_ACCEPTANCE.md`](/home/shuwen/shuwen/neurx/docs/reports/NEURX_QWEN25_NATIVE_INFERENCE_ACCEPTANCE.md)
- [`NEURX_QWEN25_CHINESE_MULTITURN_FIX.md`](/home/shuwen/shuwen/neurx/docs/reports/NEURX_QWEN25_CHINESE_MULTITURN_FIX.md)
- [`NEURX_QWEN25_FINAL_AUDIT.md`](/home/shuwen/shuwen/neurx/docs/reports/NEURX_QWEN25_FINAL_AUDIT.md)

No evidence of edits to:

- Qwen3.6 preflight rejection logic
- external S repo
- model weights

## 8) Conclusion matrix

- PASS: 核心中文/多轮 fallback 修复、请求读取加固、Qwen2.5+DeepSeek 基础回归
- PARTIAL: HTTP 异常 `Content-Length` 过大处理策略、跨请求 session 语义
- BLOCKED: 无
- UNVERIFIED: 严格非法 UTF-8 全路径拒绝、跨请求 KV cache reuse

## 9) Final verdict (pre-commit)

**PARTIAL**

> 按“独立审计通过后再提交”的标准，当前不建议立即提交。建议先补齐：
> 1) `Content-Length` 过大时的明确拒绝/超时策略；  
> 2) 非法 UTF-8 值统一拒绝；  
> 3) （若目标是 PASS）补充 session 持久化与 KV reuse 的真实实现/证据。

