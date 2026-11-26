# NEURX Qwen2.5 Native GPU Inference Acceptance (Updated)

Date: 2026-11-26  
Workspace: `/home/shuwen/shuwen/neurx`  
Model: `/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct`

## Summary

- 真实模型流式生成（英文/中文/中英混合）已稳定运行。
- 多轮对话在“历史 Prompt 拼接”模式下可持续回答。
- HTTP 请求读取与 JSON body 解析已加固，缺失 prompt 不再静默回退到 `"Hello"`。
- 但独立审计发现仍有边界项未完全闭环（见风险与结论），因此状态更新为 **PARTIAL**。

## Key Changes

Core fix file:

- [`inference_server.s`](/home/shuwen/shuwen/neurx/backend/platform/cuda/inference_server.s)

Added:

- `Content-Length` 驱动的分块读取（替代单次 `read`）
- HTTP header/body 分离函数
- `prompt`/`stream` 从 body 解析
- 缺失 prompt 的显式 `400` 错误
- 请求级 trace 字段（prefill/decode/eos/loop计数/fallback）

Regression test added:

- [`test_gpu_backend_http_request_parsing.py`](/home/shuwen/shuwen/neurx/test/native-stage4/test_gpu_backend_http_request_parsing.py)

## Real-model acceptance (3 rounds)

Tests per round:

- A: English single-turn
- B: Chinese single-turn
- C: Mixed-language single-turn
- D: 3-turn conversation

Result:

- A/B/C/D 均 3/3 轮返回 `done=true` 且有真实 token 生成。
- 中文与中英混合不再出现通用英文静默 fallback。
- D-2 对“NeurX 项目名”问答能返回正确项目名语义。

## Performance (measured)

- Model Loading Time: 7.647s
- TTFT (avg): 0.2587s
- Decode TPS (avg): 71.1055 tok/s
- Avg token latency: 0.01412s
- P50 token latency (avg): 0.01406s
- P95 token latency (avg): 0.01506s
- Peak GPU VRAM: 3457 MiB
- Peak CPU RSS (backend): 280076 KiB
- Prefill TPS: **UNVERIFIED**（无直接 prefill throughput 计数）

## Trace authenticity note

`attention_exec_count/lm_head_exec_count/kv_cache_updates` 已改为：

- `attention_loop_count`
- `lm_head_loop_count`
- `kv_cache_loop_updates`
- `trace_counter_scope=generated_loop`

这些是 **generated-loop counters**，不是 CUDA kernel 实际执行计数。

## Session / KV cache conclusion split

- Prompt history correctness: **PASS**
- Session persistence across requests: **PARTIAL**（逻辑会话可持续，底层 session id 每请求新建）
- KV cache cross-request reuse: **UNVERIFIED / Not implemented evidence**

## Current risks

1. 非法 UTF-8（值中无效字节）仍可能被解码替换后进入生成路径（未统一 400 拒绝）。
2. `Content-Length` 与实际 body 不一致时，`too_large` 案例仍可能继续处理已收到内容。
3. 旧 serving 测试在当前环境下因外部符号缺失失败（与本次 HTTP 修复非同一根因）。

## Final status

**PARTIAL**

