# NeurX 推理快速参考 (Quick Reference)

## 一、快速启动（60 秒）

### 最快方式：CPU 推理
```bash
cd /home/shuwen/shuwen/neurx
make chat-cpu
# 等待编译...
# > Your prompt here
```

### 完整流程：7 步
```bash
# 1. 进入项目目录
cd /home/shuwen/shuwen/neurx

# 2. 检查模型
ls -la models/base_llm_model.s

# 3. 构建推理引擎
make build-real-inference-s

# 4. 运行聊天
make chat-cpu

# 5. 输入提示词
> Tell me about machine learning

# 6. 查看输出
# 实时流式输出...

# 7. 退出 (Ctrl+C)
```

---

## 二、部署方式对比

| 方式 | 命令 | 硬件 | 延迟 | 吞吐量 | 用途 |
|------|------|------|------|--------|------|
| **交互式** | `make chat-cpu` | CPU | 500ms | 1-2 req/s | 本地测试 |
| **GPU 推理** | `make chat-gpu` | GPU | 150ms | 8-10 req/s | 演示 |
| **生产服务** | `make production-s-inference` | CPU/GPU | <200ms | 50+ req/s | 云部署 |
| **医学推理** | `cd posttrain && make inference` | CPU | 1-2s | 1-2 req/s | 医学应用 |

---

## 三、核心命令速查

### 推理命令
```bash
make chat-cpu              # CPU 交互式聊天
make chat-gpu              # GPU 交互式聊天
make production-s-inference   # 生产级服务
make verify-deployment     # 验证部署
```

### 构建命令
```bash
make build-real-inference-s        # 构建推理引擎
make build-production-s-inference  # 构建生产服务
make build-real-model-chat-s       # 构建聊天模块
```

### 测试命令
```bash
make benchmark-production-inference    # 性能测试
make production-inference              # 单次推理测试
```

---

## 四、API 使用 (OpenAI 兼容)

### 启动服务
```bash
# 方式 1: 前台运行
make production-s-inference

# 方式 2: 后台运行
nohup make production-s-inference > logs/inference.log 2>&1 &

# 检查状态
curl http://localhost:8000/health
```

### 文本对话
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama2",
    "messages": [
      {"role": "system", "content": "You are helpful"},
      {"role": "user", "content": "What is 2+2?"}
    ],
    "temperature": 0.7,
    "max_tokens": 256
  }'
```

### 流式输出
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama2",
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": true
  }'
```

### Python 客户端
```python
import requests

# 发送请求
response = requests.post(
    "http://localhost:8000/v1/chat/completions",
    json={
        "model": "llama2",
        "messages": [{"role": "user", "content": "Hi"}],
        "max_tokens": 256
    }
)

# 获取结果
print(response.json()["choices"][0]["message"]["content"])
```

---

## 五、环境变量速查表

```bash
# 模型
export NEURX_MODEL=/path/to/model.safetensors

# 推理参数
export NEURX_MAX_TOKENS=512          # 最大生成长度
export NEURX_TEMPERATURE=0.7         # 采样温度
export NEURX_TOP_P=0.95              # Top-p 采样

# 性能优化
export NEURX_PAGED_ATTENTION=1       # 启用 PagedAttention
export NEURX_PREFIX_CACHE=1          # 启用前缀缓存
export NEURX_MAX_BATCH_SIZE=32       # 批处理大小

# 量化
export NEURX_ENABLE_QUANT=1
export NEURX_QUANT_FORMAT=int8
export NEURX_QUANT_GROUP_SIZE=128

# 并行 (GPU)
export NEURX_TP_SIZE=4               # 张量并行
export NEURX_PP_SIZE=2               # 管道并行
export NEURX_BACKEND=cuda            # 后端

# 监控
export NEURX_ENABLE_PROFILING=1
export NEURX_LOG_LEVEL=info
export NEURX_SEED=42
```

---

## 六、性能指标参考

### CPU 推理 (16 核)
```
模型: Llama2-7B
批处理大小: 1
延迟: 500-800ms (首token)
吞吐量: 20-40 tok/s (实际)
内存: 6-8 GB
```

### GPU 推理 (单 A100)
```
模型: Llama2-7B
批处理大小: 16
延迟: 50-100ms (首token)
吞吐量: 150-200 tok/s
内存: 16 GB
```

### 分布式推理 (4x GPU)
```
模型: Llama2-7B (TP-4)
批处理大小: 64
延迟: 30-50ms (首token)
吞吐量: 250-350 tok/s
内存: 16 GB x4
```

---

## 七、常见问题速答

**Q1: 推理速度慢？**
```bash
# 启用 PagedAttention
export NEURX_PAGED_ATTENTION=1

# 使用 Greedy 采样 (而不是 Top-p)
export NEURX_SAMPLER=greedy

# 启用 GPU
make chat-gpu
```

**Q2: 内存溢出？**
```bash
# 降低批处理大小
export NEURX_MAX_BATCH_SIZE=8

# 限制最大序列长度
export NEURX_MAX_SEQ_LEN=2048

# 启用量化
export NEURX_ENABLE_QUANT=1
export NEURX_QUANT_FORMAT=int8
```

**Q3: 如何使用微调模型？**
```bash
# 使用后训练的医学模型
cd /home/shuwen/shuwen/posttrain
make inference

# 或指定路径
export NEURX_MODEL=/path/to/finetuned_model.safetensors
make chat-cpu
```

**Q4: 如何部署到生产环境？**
```bash
# 1. 构建服务
make production-s-inference

# 2. 后台启动
nohup ./artifacts/build/production_s_inference/production_chat &

# 3. 验证
curl http://localhost:8000/health

# 4. 通过 Docker 部署
docker build -t neurx-inference .
docker run -p 8000:8000 neurx-inference
```

**Q5: 如何监控性能？**
```bash
# 启用性能分析
export NEURX_ENABLE_PROFILING=1

# 查看日志
tail -f logs/inference.log | grep -E "latency|throughput|tokens"

# 监听资源使用
watch -n 1 'top -p $(pgrep -f production_chat)'
```

---

## 八、核心文件位置

```
/home/shuwen/shuwen/neurx/
├── inference/
│   ├── unified_inference_engine.s      # 推理核心
│   ├── production_inference.s          # 生产推理
│   ├── scheduler_continuous_batch.s    # 批处理调度
│   ├── kv_cache_manager.s              # KV 缓存管理
│   └── sampling_strategies.s           # 采样策略
│
├── models/
│   ├── base_llm_model.s                # 模型基类
│   └── [其他模型定义]
│
├── api/
│   └── rest_api_server.s               # REST API
│
├── Makefile                            # 构建脚本
├── INFERENCE_DEPLOYMENT_GUIDE.md       # 完整指南
├── INFERENCE_QUICK_REFERENCE.md        # 本文件
└── README.md                           # 项目文档
```

---

## 九、工作流示例

### 场景 1: 本地快速测试
```bash
# 1 分钟内完成
cd /home/shuwen/shuwen/neurx
make chat-cpu
# 输入: "What is the capital of France?"
# 输出: "The capital of France is Paris..."
# Ctrl+C 退出
```

### 场景 2: 批量推理
```bash
# 处理多个提示词
cat prompts.txt | while read prompt; do
  export NEURX_PROMPT="$prompt"
  make production-inference >> results.txt
done
```

### 场景 3: 生产服务部署
```bash
# 启动服务
nohup make production-s-inference &

# 通过 API 调用
for i in {1..10}; do
  curl -X POST http://localhost:8000/v1/chat/completions \
    -d '{"model":"llama2","messages":[{"role":"user","content":"Hello"}]}'
done
```

### 场景 4: 医学应用
```bash
# 使用微调模型
cd /home/shuwen/shuwen/posttrain
make inference

# 输入医学问题
# 输出诊断建议
```

---

## 十、性能调优清单

- [ ] 启用 PagedAttention (内存 -30%)
- [ ] 启用前缀缓存 (重复提示词 -50% 延迟)
- [ ] 调整批处理大小 (吞吐量 +3-5 倍)
- [ ] 选择合适的采样器 (Greedy 快 20%)
- [ ] 启用量化 (内存 -75%, 延迟 +10%)
- [ ] 使用 GPU (吞吐量 +5-10 倍)
- [ ] 配置分布式推理 (大模型必需)
- [ ] 启用性能监控 (问题诊断)

---

**更新时间**: 2026-08-13  
**完整指南**: 见 INFERENCE_DEPLOYMENT_GUIDE.md
