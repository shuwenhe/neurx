# NEURX Qwen2.5-0.5B-Instruct Native GPU Inference Acceptance

Date: 2026-11-26  
Workspace: `/home/shuwen/shuwen/neurx`  
Model: `/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct`

---

## 1) Git 基线

- Branch: `feat/qwen35-native`
- HEAD: `8e063ef3 feat(cuda): add DeltaNet state baseline and record BF16 reference blocker`
- `git status --short`: 存在预先未提交修改（未被本次验收覆盖/回滚）

---

## 2) 模型信息

- `model_type`: `qwen2`
- `architectures`: `["Qwen2ForCausalLM"]`
- `num_hidden_layers`: `24`
- `hidden_size`: `896`
- `num_attention_heads`: `14`
- `num_key_value_heads`: `2`
- `vocab_size`: `151936`
- `torch_dtype`: `bfloat16`

模型关键文件存在：

- `config.json`
- `tokenizer.json`
- `tokenizer_config.json`
- `model.safetensors` (~943MB)

---

## 3) Preflight 结果

执行：

```bash
python3 scripts/check_inference_model.py /home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct
```

结果：**PASS**

- `Model asset preflight passed: /home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct`

---

## 4) CUDA 环境

- GPU: `NVIDIA GeForce RTX 4060 Ti`
- Driver: `580.159.03`
- `nvidia-smi` CUDA Version: `13.0`
- `nvcc --version`: `12.0 (V12.0.140)`

---

## 5) 权重加载

后端日志出现：

- `Initializing model weights (device residency is backend-managed)...`
- `GPU Available: YES`
- `Backend Status: READY`

说明：

- 服务启动成功 ≠ 模型加载成功 ≠ 推理生成成功。
- 本次三者分别做了独立记录（见后续章节）。

---

## 6) 英文生成（Test 1）

输入：

`Hello, introduce yourself briefly.`

结果（stream）：

- 生成成功
- `generated_tokens=43`（>=32）
- TTFT: `0.310s`
- Decode TPS: `74.65 tok/s`
- 输出可读，无乱码

---

## 7) 中文生成（Test 2）

输入：

`请用中文解释什么是大语言模型，并举一个实际应用例子。`

结果（异常路径）：

- 返回为非流式 `{"status":"ok","output":"Hello! How can I assist you today?"}`
- 非预期中文回答，且未提供 `done=true/generated_tokens` 流式收尾
- 记录 token 为 `1`（仅按块回退计数，不可视作可靠 token 数）

结论：**中文测试未通过验收要求**（内容不符合输入语义，流式链路不一致）。

---

## 8) 中英文混合（Test 3）

输入：

`Explain the difference between CPU and GPU，用中文总结它们在AI推理中的作用。`

结果（stream）：

- 生成成功
- `generated_tokens=128`（>=32）
- TTFT: `0.233s`
- Decode TPS: `69.15 tok/s`
- 输出为中英混合文本，UTF-8 显示正常（未见乱码/截断）

---

## 9) 多轮对话（Test 4）

第一轮输入：

`我的名字是 NeurX，请记住这个项目名称。`

第一轮结果：

- stream 生成成功
- `generated_tokens=15`
- 回答为“已记住项目名称”语义

第二轮输入：

`刚才我告诉你的项目名称是什么？`

第二轮结果（异常路径）：

- 返回非流式通用回复 `Hello! How can I assist you today?`
- 未正确引用上一轮记忆

结论：**多轮上下文保留未达标**。

---

## 10) Prefill / Decode / KV Cache 证据

### 10.1 运行期日志证据

- `Prompt tokens` / `Generated tokens` / `Stream completed` 日志出现，说明存在 prefill+decode 的执行迹象。
- stream 请求可见 `done=true` 帧与 `generated_tokens`（部分请求）。

### 10.2 代码路径证据（实现侧）

在 [`inference_server.s`](/home/shuwen/shuwen/neurx/backend/platform/cuda/inference_server.s) 可见：

- 会话接口：`neurx_s_cuda_session_begin` / `neurx_s_cuda_session_next`
- 流式输出：`perform_inference_gpu_stream`
- 贪心采样：`argmax` / `greedy_decode_tokens`
- KV Cache 初始化与更新函数：`init_kv_cache` / `update_kv_cache`

### 10.3 可验证性结论

- Embedding：**PARTIAL**（实现与启动路径存在证据；缺少逐请求 embedding trace）
- Prefill：**PARTIAL**（有 `Prompt tokens` 日志，但并非每次 stream 请求都有同粒度日志）
- Attention(Q/K/V)：**UNVERIFIED**（无逐层运行时指标输出）
- KV Cache 更新：**UNVERIFIED**（无请求级 cache length/position trace）
- Decode：**PASS（部分请求）**（有连续 token 流与 `Stream completed`）
- LM Head / Logits：**UNVERIFIED**（无 logits/LM head runtime trace导出）
- Sampling(Greedy)：**PARTIAL**（代码路径为 greedy；运行时未输出每步 token id/logit）
- EOS/停止：**PARTIAL**（有提前停止与 done 帧，但非每次都可归因 EOS）
- Session 状态：**PARTIAL/FAIL**（第二轮记忆未稳定保留）

---

## 11) 性能数据（实测）

> 未实测项均标注 UNVERIFIED。

- Model Loading Time（进程启动到 `/health`=ok）: **7.517s**
- TTFT（3个流式成功请求平均）: **0.257s**
- 首次流式请求 TTFT: **0.310s**
- 后续流式请求平均 TTFT: **0.231s**
- Decode TPS（3个流式成功请求平均）: **73.38 tok/s**
- Average Token Latency（3个流式成功请求平均）: **0.01365 s/token**
- Prefill TPS: **UNVERIFIED**（当前日志未提供可直接计算字段）
- Peak GPU VRAM: **3855 MiB**
- Peak CPU RSS（backend 进程）: **277876 KiB**
- `make inference` 总进程峰值 RSS（含构建/客户端）: **2288032 KiB**
- CUDA Kernel Errors: **未在日志中观测到显式报错**

---

## 12) 失败项与剩余风险

1. 中文请求与多轮第二轮出现非流式 fallback，且返回与输入不匹配的通用英文回复。  
   - 风险：生产中可能导致语言/上下文失真，token 指标不可用。
2. 运行时链路缺少可审计 trace（attention/KV/LM head/logits/prefill tps）。  
   - 风险：无法完成“模块级强证据”验收闭环。
3. 非交互管道喂入 `make inference` 时，多行输入会聚合为单请求（已观察到）。  
   - 风险：脚本化验收与人工交互行为存在偏差。

---

## 最终状态

**PARTIAL**

- ✅ 已证明：Preflight、GPU可用、后端加载、部分真实流式 token 生成可用。  
- ❌ 未证明/未通过：中文单轮稳定性、多轮上下文稳定性、KV/LMHead/Attention 的运行时可观测强证据、Prefill TPS量化。

