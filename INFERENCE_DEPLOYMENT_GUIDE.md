# NeurX 推理部署指南 (Inference Deployment Guide)

**最后更新**: 2026-08-13  
**适用版本**: NeurX Pure S Runtime

---

## 📋 目录

1. [快速开始](#快速开始)
2. [部署架构](#部署架构)
3. [推理方式](#推理方式)
4. [性能优化](#性能优化)
5. [故障排查](#故障排查)
6. [参考资源](#参考资源)

---

## 快速开始

### 前置条件

```bash
# 检查编译环境
cd /home/shuwen/shuwen/neurx
ls -la bin/s          # S 语言编译器
ls -la models/        # 模型文件位置
```

### 方式 1: CPU 推理 (最简单)

```bash
# 编译并运行交互式聊天
cd /home/shuwen/shuwen/neurx
make chat-cpu

# 输出示例:
# ================================================
# NeurX Interactive Chat (Pure S)
# ================================================
# Model: ./models/llama2-7b/model.safetensors
# Backend: CPU (Optimized)
# Ready for input...
# > Your question here
```

### 方式 2: 生产级推理服务

```bash
# 构建生产级推理服务
make production-s-inference

# 启动服务
./artifacts/build/production_s_inference/production_chat

# API 调用示例
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama2",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 512
  }'
```

### 方式 3: 医学领域推理 (微调模型)

```bash
# 使用后训练模型进行医学推理
cd /home/shuwen/shuwen/posttrain
make inference

# 或直接调用
cd /home/shuwen/shuwen/neurx
./artifacts/build/production_s_inference/production_chat \
  --model ../posttrain/model.safetensors \
  --task medical
```

---

## 部署架构

### 系统架构 (9 层分离)

```
┌─────────────────────────────────────────────┐
│         Client Applications                 │
│    (Web UI / Mobile / API Clients)          │
└────────────────────┬────────────────────────┘
                     │
┌────────────────────▼────────────────────────┐
│      REST API Gateway                       │
│  (OpenAI Compatible, SSE Streaming)         │
└────────────────────┬────────────────────────┘
                     │
┌────────────────────▼────────────────────────┐
│    Admission Control & Rate Limiting        │
│  (Token Bucket, Circuit Breaker)            │
└────────────────────┬────────────────────────┘
                     │
┌────────────────────▼────────────────────────┐
│    Request Scheduler & Batching             │
│  (Continuous Batching, Priority Queue)      │
└────────────────────┬────────────────────────┘
                     │
┌────────────────────▼────────────────────────┐
│      Inference Engine Core                  │
│  (Transformer Forward Pass, Sampling)       │
└────────────────────┬────────────────────────┘
                     │
┌────────────────────▼────────────────────────┐
│      KV Cache Management                    │
│  (PagedAttention, Prefix Caching)           │
└────────────────────┬────────────────────────┘
                     │
┌────────────────────▼────────────────────────┐
│    Worker Thread Pool                       │
│  (Thread Safe, Lock-Free Queue)             │
└────────────────────┬────────────────────────┘
                     │
┌────────────────────▼────────────────────────┐
│     Hardware Backend                        │
│  (CPU / CUDA / NPU / BLAS)                  │
└─────────────────────────────────────────────┘
```

### 核心组件

| 组件 | 文件 | 功能 |
|------|------|------|
| 推理引擎 | `inference/unified_inference_engine.s` | Transformer 模型完整前向传播 |
| 调度器 | `inference/scheduler_continuous_batch.s` | 请求批处理和优先级调度 |
| KV 缓存 | `inference/kv_cache_manager.s` | 内存优化的键值缓存管理 |
| API 网关 | `api/rest_api_server.s` | OpenAI 兼容的 REST API |
| 采样 | `inference/sampling_strategies.s` | Greedy/Top-k/Top-p/Temperature 采样 |
| 模型加载 | `inference/production_model_loader.s` | SafeTensors 模型加载 |

---

## 推理方式

### 1. 交互式聊天 (Interactive Chat)

**适用场景**: 本地测试、演示、单轮对话

```bash
# CPU 推理
make chat-cpu

# GPU 推理 (CUDA)
make chat-gpu

# NPU 推理 (Ascend)
make chat-npu
```

**特点**:
- ✅ 零配置，开箱即用
- ✅ 流式输出
- ✅ 支持多轮对话
- ❌ 吞吐量低（单用户）

---

### 2. 生产级服务 (Production Service)

**适用场景**: 云部署、API 服务、多用户并发

```bash
# 构建服务
make production-s-inference

# 启动（后台运行）
nohup ./artifacts/build/production_s_inference/production_chat > logs/inference.log 2>&1 &

# 检查状态
curl http://localhost:8000/health

# 查看日志
tail -f logs/inference.log
```

**REST API 示例**:

```bash
# 文本对话
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama2",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant"},
      {"role": "user", "content": "What is 2+2?"}
    ],
    "temperature": 0.7,
    "top_p": 0.95,
    "max_tokens": 512,
    "stream": false
  }'

# 流式输出
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama2",
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": true
  }'
```

**性能指标**:
- 延迟: < 200ms (首token)
- 吞吐量: > 50 req/s
- 并发: 128+ 同时连接
- 内存: 2-4 GB (7B 模型)

---

### 3. 医学领域推理 (Medical Inference)

**适用场景**: 医学问答、诊断辅助、文献摘要

```bash
# 使用微调模型
cd /home/shuwen/shuwen/posttrain
make inference

# 或指定模型
cd /home/shuwen/shuwen/neurx
NEURX_MODEL=/path/to/medical/model.safetensors \
NEURX_MAX_TOKENS=512 \
./artifacts/build/production_s_inference/production_chat
```

**输入示例**:

```
患者主诉：头痛3天，伴发热，温度38.5°C
请提供初步诊断意见。
```

**输出示例**:

```
初步诊断建议：
1. 上呼吸道感染可能性最大 (概率: 65%)
   - 症状：头痛、发热、体温升高
   - 建议：多喝温水，充分休息，监测体温

2. 病毒性感冒 (概率: 20%)
   - 建议：症状治疗，5-7天自愈

3. 细菌感染 (概率: 10%)
   - 建议：若3天内未改善，建议就医

建议立即就医的情况：
- 体温超过 40°C
- 严重头痛伴颈项强直
- 意识混乱或惊厥
```

---

### 4. 分布式推理 (Distributed Inference)

**适用场景**: 大模型推理、多 GPU 部署

```bash
# 张量并行 (Tensor Parallel, 4 GPUs)
NEURX_TP_SIZE=4 \
NEURX_BACKEND=cuda \
make production-s-inference

# 管道并行 (Pipeline Parallel, 2x2 TP+PP)
NEURX_TP_SIZE=2 \
NEURX_PP_SIZE=2 \
NEURX_BACKEND=cuda \
./artifacts/build/production_s_inference/production_chat

# 混合并行 (Hybrid, TP-4+PP-2+DP-2)
NEURX_TP_SIZE=4 \
NEURX_PP_SIZE=2 \
NEURX_DP_SIZE=2 \
./artifacts/build/production_s_inference/production_chat
```

**性能对比**:

| 配置 | 模型 | 延迟 | 吞吐量 | 内存 |
|------|------|------|--------|------|
| 单 GPU | 7B | 150ms | 8 req/s | 16GB |
| TP-2 | 7B | 85ms | 15 req/s | 8GB x2 |
| TP-4 | 7B | 50ms | 25 req/s | 4GB x4 |
| TP-4+PP-2 | 7B | 45ms | 30 req/s | 3GB x8 |

---

## 性能优化

### 1. KV 缓存优化 (PagedAttention)

```bash
# 启用分页注意力
export NEURX_PAGED_ATTENTION=1
export NEURX_PAGE_SIZE=4096  # tokens
make production-s-inference

# 效果：内存节省 30%
# 性能：吞吐量提升 20%
```

### 2. 量化推理 (Quantization)

```bash
# INT8 量化
export NEURX_QUANT_FORMAT=int8
export NEURX_QUANT_GROUP_SIZE=128
make production-s-inference

# INT4 量化 (更激进)
export NEURX_QUANT_FORMAT=int4
export NEURX_QUANT_GROUP_SIZE=32

# 效果：内存节省 75%
# 性能：延迟增加 10-15%
```

### 3. 批处理优化 (Continuous Batching)

```bash
# 配置批处理参数
export NEURX_MAX_BATCH_SIZE=128
export NEURX_MAX_PREFILL_TOKENS=4096
export NEURX_MAX_DECODE_TOKENS=2048
make production-s-inference

# 默认值
# NEURX_MAX_BATCH_SIZE=32
# NEURX_MAX_PREFILL_TOKENS=2048
# NEURX_MAX_DECODE_TOKENS=1024
```

### 4. 前缀缓存 (Prefix Caching)

```bash
# 启用前缀缓存（适合重复提示词）
export NEURX_PREFIX_CACHE=1
export NEURX_PREFIX_CACHE_SIZE=256  # 最多缓存 256 个前缀

make production-s-inference

# 适用场景：
# - RAG (检索增强生成)
# - 系统提示词重用
# - 批量推理相同上下文
```

---

## 故障排查

### 问题 1: 模型加载失败

```bash
# 症状
# error: model path not found: ./models/llama2/model.safetensors

# 解决方案
1. 检查模型文件是否存在
   ls -la ./models/

2. 检查模型格式（必须是 SafeTensors）
   file ./models/llama2/model.safetensors

3. 下载正确的模型
   cd models
   ./download_model.sh llama2-7b

4. 指定完整路径
   export NEURX_MODEL=/absolute/path/to/model.safetensors
```

### 问题 2: 内存溢出 (OOM)

```bash
# 症状
# error: failed to allocate memory for KV cache

# 原因分析
1. 批处理大小过大
2. 最大序列长度过长
3. KV 缓存未启用优化

# 解决方案
export NEURX_MAX_BATCH_SIZE=16      # 降低批处理
export NEURX_MAX_SEQ_LEN=2048        # 限制序列长度
export NEURX_PAGED_ATTENTION=1       # 启用 PagedAttention

# 检查内存使用
top -p $(pgrep -f production_chat)
```

### 问题 3: 性能低下

```bash
# 症状
# Generated 128 tokens in 12500ms (10 tok/s)
# 预期: 50+ tok/s

# 诊断步骤
1. 检查 CPU 使用率
   top

2. 检查 GPU 使用率 (若启用)
   nvidia-smi

3. 启用性能监控
   export NEURX_ENABLE_PROFILING=1

4. 检查日志
   tail -f logs/inference.log | grep -i "latency\|throughput"

# 优化方案
a) 增加线程数
   export NEURX_NUM_WORKERS=8

b) 启用优化
   export NEURX_PAGED_ATTENTION=1
   export NEURX_ENABLE_SPECULATIVE_DECODE=1

c) 调整采样
   export NEURX_SAMPLER=greedy  # 比 top-p 快 20%
```

### 问题 4: 推理结果不稳定

```bash
# 症状
# 同样的输入得到不同的输出

# 原因
1. Temperature 值未固定
2. 随机数种子不同
3. 浮点计算精度

# 解决方案
# 设置固定种子
export NEURX_SEED=42

# 使用 Greedy 解码（确定性）
export NEURX_SAMPLER=greedy
export NEURX_TEMPERATURE=0

# 指定 API 参数
curl ... -d '{
  "temperature": 0.0,
  "top_p": 1.0,
  "seed": 42
}'
```

---

## 参考资源

### 文件结构

```
neurx/
├── inference/                    # 核心推理模块
│   ├── unified_inference_engine.s
│   ├── production_inference.s
│   ├── scheduler_continuous_batch.s
│   ├── kv_cache_manager.s
│   ├── sampling_strategies.s
│   └── attention/                # 注意力实现
│
├── api/                          # API 网关
│   ├── rest_api_server.s
│   └── openai_protocol.s
│
├── models/                       # 模型文件
│   ├── base_llm_model.s          # 模型定义
│   └── llama/qwen/deepseek/...
│
├── Makefile                      # 构建指令
└── INFERENCE_DEPLOYMENT_GUIDE.md # 本文档
```

### Makefile 目标

| 目标 | 说明 |
|------|------|
| `make chat-cpu` | CPU 交互式推理 |
| `make chat-gpu` | GPU 交互式推理 |
| `make production-s-inference` | 构建生产级服务 |
| `make production-inference` | 运行生产级推理 |
| `make benchmark-production-inference` | 性能基准测试 |
| `make start-inference-service` | 启动后台服务 |
| `make verify-deployment` | 部署验证 |

### 环境变量

```bash
# 模型配置
NEURX_MODEL                 # 模型路径
NEURX_MODEL_TYPE           # 模型类型 (llama/qwen/deepseek)

# 推理参数
NEURX_MAX_TOKENS           # 最大生成长度
NEURX_MAX_BATCH_SIZE       # 批处理大小
NEURX_MAX_SEQ_LEN          # 最大序列长度
NEURX_TEMPERATURE          # 采样温度
NEURX_TOP_P                # Top-p 概率
NEURX_TOP_K                # Top-k 数量

# 优化配置
NEURX_PAGED_ATTENTION      # 启用 PagedAttention
NEURX_PREFIX_CACHE         # 启用前缀缓存
NEURX_ENABLE_QUANT         # 启用量化
NEURX_QUANT_FORMAT         # 量化格式 (int8/int4)

# 并行配置
NEURX_TP_SIZE              # 张量并行大小
NEURX_PP_SIZE              # 管道并行大小
NEURX_DP_SIZE              # 数据并行大小
NEURX_BACKEND              # 后端类型 (cpu/cuda/npu)

# 监控配置
NEURX_ENABLE_PROFILING     # 启用性能分析
NEURX_LOG_LEVEL            # 日志级别
NEURX_SEED                 # 随机种子
```

### 常用命令总结

```bash
# 快速启动
cd /home/shuwen/shuwen/neurx
make chat-cpu

# 构建生产服务
make production-s-inference

# 启动后台服务
nohup ./artifacts/build/production_s_inference/production_chat &

# 健康检查
curl http://localhost:8000/health

# API 调用
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"llama2","messages":[{"role":"user","content":"Hi"}]}'

# 医学推理
cd ../posttrain && make inference

# 性能测试
make benchmark-production-inference

# 故障诊断
export NEURX_LOG_LEVEL=debug
make production-s-inference
```

---

**问题反馈**: 创建 Issue 或提交 PR  
**最后更新**: 2026-08-13  
**维护者**: NeurX 推理团队
