# NEURX Qwen2.5 Native Inference Smoke Test

Date: 2026-11-26  
Workspace: `/home/shuwen/shuwen/neurx`  
Target model: `/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct`

## 1) Git baseline and workspace status

- Branch: `feat/qwen35-native`
- HEAD: `8e063ef39d83018210d4c58935059077771a7b94`
- Working tree had pre-existing uncommitted changes before this test (left untouched).
- No reset/clean/override actions were executed.

## 2) Model file checks

Model directory exists and contains required files:

- `config.json`
- `tokenizer.json`
- `model.safetensors` (single-file checkpoint, ~943MB)

Additional check:

- `model_type`: `qwen2`
- `architectures`: `["Qwen2ForCausalLM"]`
- Weight files present: `1`

## 3) Preflight result

Command:

```bash
python3 scripts/check_inference_model.py /home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct
```

Result: **PASS**

- `Model asset preflight passed: /home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct`

## 4) CUDA environment

- GPU: `NVIDIA GeForce RTX 4060 Ti`
- Driver: `580.159.03`
- `nvidia-smi` CUDA runtime: `13.0`
- `nvcc --version`: `12.0` (`V12.0.140`)

## 5) Weight loading results

Backend startup log confirms model load path:

- `Initializing model weights (device residency is backend-managed)...`
- `GPU Available: YES`
- `Backend Status: READY`

Measured model-loading-to-health-ready time:

- **Model Loading Time: 7.487s** (measured from backend process start to `/health`=ok)

## 6) Prefill / Decode results

Observed in backend logs:

- Prompt tokenization/prefill evidence:
  - `Prompt tokens: 25` (non-stream request sample)
- Decode evidence:
  - Streaming completed with token counts (`43`, `64`, `43`, `12`) on stream-enabled calls
- EOS/stop behavior:
  - Responses ended with `done=true` events.
  - Some requests stopped before `max_new_tokens=64` (e.g. `43`, `12`), consistent with normal stop condition.

KV cache update internals:

- **UNVERIFIED** (no explicit KV-cache update counters/messages exposed in current logs).

## 7) Token generation results (requested prompts)

All requests used existing `/v1/generate` service endpoint.

| Case | Input | Output tokens | Errors | Duration |
|---|---|---:|---|---:|
| case1 | Hello, introduce yourself briefly. | 43 | none | 0.917s |
| case2 | 请用中文解释什么是大语言模型。 | 1* | none | 0.324s |
| case3 | What is the difference between CPU and GPU? | 64 | none | 1.086s |

\* `case2` returned non-stream payload (`{"status":"ok","output":"Hello! How can I assist you today?"}`) instead of stream chunks with `done=true/generated_tokens`. Token count is fallback-counted as `1` response chunk and should be treated as **not reliable token accounting**.

### Additional multi-turn context test

| Round | Input pattern | Output tokens | Duration |
|---|---|---:|---:|
| multi_turn_round1 | system + user1 | 43 | 0.789s |
| multi_turn_round2 | system + user1 + assistant1 + user2 | 12 | 0.444s |

Result: multi-turn prompt-with-history path is functioning (history-bearing prompt produced context-aware Chinese response).

## 8) Multi-turn dialogue result

Status: **PASS (basic)**

- Second round accepted prior assistant text + new user query in one ChatML prompt.
- Returned Chinese summary-style answer.
- This validates history-bearing request handling on current endpoint contract.

## 9) Performance and resource data

- Model Loading Time: **7.487s**
- TTFT (stream cases average): **0.272s**
- Decode TPS (stream cases average): **72.0738 tokens/s**
- Average Token Latency (stream cases average): **0.01392s/token**
- Peak GPU VRAM during smoke run: **4033 MiB**
- Peak CPU RSS (backend sampler): **3684 KiB** (**likely under-reported by sampler granularity/runtime visibility**)
- Peak RSS from full `make inference` process (`/usr/bin/time -v`): **2286456 KiB** (includes build + launcher/client process scope)
- CUDA Kernel Errors: **not observed in logs** (no explicit CUDA kernel error messages)

## 10) Failures and root causes

1. **Chinese prompt single-turn path inconsistent (`case2`)**
   - Symptom: Returned non-stream generic output while request asked for stream mode.
   - Impact: Required per-token stream metrics unavailable/reduced reliability for this case.
   - Evidence: response payload lacked `done=true/generated_tokens`; backend behavior diverged from other stream cases.
   - Root-cause hypothesis: request parsing/stream-mode decision around this prompt path is inconsistent.

2. **KV cache internal update visibility**
   - Symptom: no explicit log field for per-step KV-cache updates.
   - Impact: KV cache update requirement cannot be directly evidenced from current logs.
   - Status: instrumentation gap (not bypassed; reported as UNVERIFIED).

---

## Final verdict

**PARTIAL**

- Preflight, model loading, backend readiness, and core GPU inference path are working on `Qwen2.5-0.5B-Instruct`.
- Multi-turn context request path works.
- However, one required prompt (`请用中文解释什么是大语言模型。`) showed stream-path inconsistency and non-reliable token accounting, so this is not a full PASS for all acceptance points.
