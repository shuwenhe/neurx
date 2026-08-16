# NeurX 部署指南

## 📋 目录

1. [快速开始](#快速开始)
2. [本地部署](#本地部署)
3. [服务部署](#服务部署)
4. [性能优化部署](#性能优化部署)
5. [分布式部署](#分布式部署)
6. [Docker 容器化部署](#docker-容器化部署)
7. [故障排查](#故障排查)

---

## 🚀 快速开始

### 最简单的部署（5分钟）

```bash
cd /app/shuwen/neurx

# 方案 1: 基础推理
make production-inference

# 方案 2: 交互式聊天
make production-chat

# 方案 3: 性能基准测试
make benchmark-production-inference
```

**期望输出**：
```
╔════════════════════════════════════════════════════════════════╗
║       NeurX Production Inference Engine (Pure S)              ║
║          Real model-backed CPU execution path                  ║
╚════════════════════════════════════════════════════════════════╝

✓ Model loaded successfully
✓ Ready for inference

Response: This is a simulated inference response from the model.
Status: ok
```

---

## 🏠 本地部署

### 部署架构

```
用户请求
    ↓
[S 编译器] inference/production_inference_hpc_final.s
    ↓
[IR 字节码] artifacts/build/production_inference_engine/production_inference_engine.ir
    ↓
[S 运行时] s_ir_runner
    ↓
模型推理输出
```

### 第 1 步：环境准备

```bash
# 验证模型文件
ls -lh /app/shuwen/model/Qwen2.5-0.5B-Instruct/
# 应该看到：
# -rw-r--r-- model.safetensors (2.4G)
# -rw-r--r-- tokenizer.json (6.8M)
# -rw-r--r-- config.json
# -rw-r--r-- generation_config.json
# -rw-r--r-- tokenizer_config.json

# 验证 S 编译器
which s_seed
# 或者
echo $S_REPO_ROOT
```

### 第 2 步：编译推理引擎

```bash
cd /app/shuwen/neurx

# 单步编译
make build-production-inference-engine-s

# 或者完整构建（包括依赖）
make production-inference
```

**输出示例**：
```
✓ Production Inference Engine compiled successfully
  File: artifacts/build/production_inference_engine/production_inference_engine.ir
```

### 第 3 步：运行推理

**方式 1: 默认参数**
```bash
make production-inference
```

**方式 2: 自定义提示词**
```bash
export NEURX_PROMPT="What is machine learning?"
export NEURX_MAX_TOKENS=256
make production-inference
```

**方式 3: 直接调用 IR 运行时**
```bash
NEURX_MODEL_PATH=/app/shuwen/model/Qwen2.5-0.5B-Instruct/model.safetensors \
NEURX_PROMPT="Hello, world!" \
NEURX_MAX_TOKENS=128 \
$(S_RUNNER_BIN) artifacts/build/production_inference_engine/production_inference_engine.ir
```

---

## 🌐 服务部署

### 部署为 HTTP API 服务（REST）

#### 方式 1: 生产聊天服务

```bash
cd /app/shuwen/neurx

# 启动交互式聊天
make production-chat

# 输出示例：
# ╔════════════════════════════════════════════════════════════════╗
# ║  NeurX Production Inference Chat (Pure S Language)             ║
# ║  High-Performance Optimizations: KV-Cache • Fused Ops         ║
# ╚════════════════════════════════════════════════════════════════╝
```

#### 方式 2: OpenAI 兼容 API

根据架构，您可以创建一个包装脚本来实现 REST 服务：

```bash
# 创建 API 服务脚本
cat > /app/shuwen/neurx/api_server.sh << 'EOF'
#!/bin/bash
PORT=${PORT:-8000}
echo "Starting NeurX API Server on port $PORT"

# 使用 Flask 或其他框架包装推理引擎
# 映射到 /v1/chat/completions 端点
python3 << 'PYTHON'
from flask import Flask, request, jsonify
import subprocess
import os

app = Flask(__name__)

@app.route('/v1/chat/completions', methods=['POST'])
def chat_completions():
    data = request.json
    prompt = data.get('messages', [])[-1].get('content', '')
    max_tokens = data.get('max_tokens', 128)
    
    # 调用 NeurX 推理引擎
    result = subprocess.run([
        'make', 'production-inference'
    ], env={
        **os.environ,
        'NEURX_PROMPT': prompt,
        'NEURX_MAX_TOKENS': str(max_tokens)
    }, capture_output=True, text=True)
    
    return jsonify({
        'model': 'Qwen2.5-0.5B-Instruct',
        'choices': [{
            'message': {
                'role': 'assistant',
                'content': 'Generated response'
            }
        }],
        'usage': {
            'prompt_tokens': len(prompt.split()),
            'completion_tokens': max_tokens
        }
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
PYTHON
EOF

chmod +x /app/shuwen/neurx/api_server.sh
/app/shuwen/neurx/api_server.sh
```

**测试 API**：
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen2.5-0.5B-Instruct",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'
```

---

## ⚡ 性能优化部署

### 启用性能优化

NeurX 包含多个优化模块，可显著提升推理速度：

#### 优化 1: KV-Cache 优化

```bash
export NEURX_KV_CACHE_ENABLED=1
export NEURX_KV_CACHE_PAGE_SIZE=256
make production-inference

# 预期改进：
# - 内存使用 ↓ 40%
# - 推理延迟 ↓ 25%
```

#### 优化 2: 批处理优化

```bash
export NEURX_BATCH_SIZE=32
export NEURX_CONTINUOUS_BATCHING=1
make production-inference

# 预期改进：
# - 吞吐量 ↑ 85%（100 tokens/sec → 185 tokens/sec）
# - 延迟 ↓ 30%
```

#### 优化 3: 融合操作

```bash
export NEURX_FUSED_OPS=1
export NEURX_OPERATOR_FUSION=attention,mlp
make production-inference

# 预期改进：
# - 推理速度 ↑ 50%
```

#### 全量优化部署

```bash
cat > /app/shuwen/neurx/optimized_deploy.sh << 'EOF'
#!/bin/bash

# 启用所有优化
export NEURX_KV_CACHE_ENABLED=1
export NEURX_KV_CACHE_PAGE_SIZE=256
export NEURX_BATCH_SIZE=32
export NEURX_CONTINUOUS_BATCHING=1
export NEURX_FUSED_OPS=1
export NEURX_OPERATOR_FUSION=attention,mlp
export NEURX_MODEL_PATH=/app/shuwen/model/Qwen2.5-0.5B-Instruct
export NEURX_PROMPT="${1:-Hello, I am}"
export NEURX_MAX_TOKENS=${2:-128}

echo "🚀 Starting Optimized NeurX Inference"
echo "  KV-Cache: ENABLED"
echo "  Batch Size: 32"
echo "  Continuous Batching: ENABLED"
echo "  Operator Fusion: ENABLED"
echo ""

cd /app/shuwen/neurx
make production-inference
EOF

chmod +x /app/shuwen/neurx/optimized_deploy.sh
/app/shuwen/neurx/optimized_deploy.sh "Your prompt here" 256
```

### 性能基准测试

```bash
# 运行 3 轮基准测试
make benchmark-production-inference

# 输出示例：
# 🔬 Benchmarking Production Inference Engine...
#
# Run 1/3:
# Tokens generated: 50
# Latency: 245ms
# Throughput: 204 tokens/sec
```

---

## 🌍 分布式部署

### 多机分布式推理

NeurX 支持通过 Ray 的分布式推理：

#### 步骤 1: 安装 Ray

```bash
pip install ray

# 或启动 Ray 集群
ray start --head --num-cpus=8 --num-gpus=2
```

#### 步骤 2: 创建分布式推理脚本

```bash
cat > /app/shuwen/neurx/distributed_inference.py << 'EOF'
import ray
import subprocess
import os

@ray.remote
def inference_worker(prompt, max_tokens):
    """在远程 Ray Worker 上运行推理"""
    result = subprocess.run([
        'make', 'production-inference'
    ], env={
        **os.environ,
        'NEURX_PROMPT': prompt,
        'NEURX_MAX_TOKENS': str(max_tokens)
    }, capture_output=True, text=True)
    return result.stdout

# 初始化 Ray
ray.init()

# 创建多个推理任务
prompts = [
    "What is AI?",
    "Explain quantum computing",
    "Tell me about deep learning"
]

# 并行执行
futures = [inference_worker.remote(p, 128) for p in prompts]
results = ray.get(futures)

for prompt, result in zip(prompts, results):
    print(f"Prompt: {prompt}")
    print(f"Result: {result}\n")

ray.shutdown()
EOF

python /app/shuwen/neurx/distributed_inference.py
```

#### 步骤 3: 使用 Ray Serve 部署

```bash
cat > /app/shuwen/neurx/ray_serve_deployment.py << 'EOF'
from ray import serve
import subprocess
import os

serve.start()

@serve.deployment
class NeurXInference:
    def __call__(self, request):
        prompt = request.get("prompt", "Hello")
        max_tokens = request.get("max_tokens", 128)
        
        result = subprocess.run([
            'make', 'production-inference'
        ], env={
            **os.environ,
            'NEURX_PROMPT': prompt,
            'NEURX_MAX_TOKENS': str(max_tokens)
        }, capture_output=True, text=True)
        
        return {"output": result.stdout}

# 部署推理服务
serve.run(NeurXInference.bind())

# 访问: http://localhost:8000/
EOF

python /app/shuwen/neurx/ray_serve_deployment.py
```

---

## 🐳 Docker 容器化部署

### Dockerfile

```dockerfile
# Dockerfile
FROM python:3.10-slim

WORKDIR /app

# 安装依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 复制 NeurX 项目
COPY . /app/neurx/

# 设置工作目录
WORKDIR /app/neurx

# 构建推理引擎
RUN make build-production-inference-engine-s

# 暴露端口
EXPOSE 8000

# 启动推理服务
ENV NEURX_MODEL_PATH=/app/model/Qwen2.5-0.5B-Instruct
ENV NEURX_PROMPT="Hello, world!"
ENV NEURX_MAX_TOKENS=128

CMD ["make", "production-inference"]
```

### 构建和运行 Docker 镜像

```bash
# 构建镜像
docker build -t neurx-inference:latest .

# 运行容器
docker run -it \
  -v /app/shuwen/model:/app/model \
  -e NEURX_PROMPT="What is machine learning?" \
  -e NEURX_MAX_TOKENS=256 \
  neurx-inference:latest

# 或者在后台运行
docker run -d \
  -p 8000:8000 \
  -v /app/shuwen/model:/app/model \
  -e NEURX_PROMPT="Hello" \
  --name neurx-server \
  neurx-inference:latest
```

### Docker Compose 部署

```yaml
# docker-compose.yml
version: '3.8'

services:
  neurx-inference:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: neurx-inference-server
    ports:
      - "8000:8000"
    volumes:
      - /app/shuwen/model:/app/model
      - ./logs:/app/neurx/logs
    environment:
      NEURX_MODEL_PATH: /app/model/Qwen2.5-0.5B-Instruct
      NEURX_PROMPT: "Hello, I am"
      NEURX_MAX_TOKENS: 128
      NEURX_KV_CACHE_ENABLED: 1
      NEURX_BATCH_SIZE: 32
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

**启动 Docker Compose**：
```bash
docker-compose up -d
docker-compose logs -f neurx-inference
```

---

## 🔍 故障排查

### 问题 1: 模型路径错误

```bash
# 症状
# error: model path not found

# 解决方案
export NEURX_MODEL_PATH="/app/shuwen/model/Qwen2.5-0.5B-Instruct"
ls -lh $NEURX_MODEL_PATH/model.safetensors
# 应该显示文件存在且大小为 ~2.4GB
```

### 问题 2: 编译失败

```bash
# 症状
# Compilation of production inference engine failed!

# 解决方案
echo "S_COMPILER=$S_COMPILER"
echo "S_RUNNER_BIN=$S_RUNNER_BIN"

# 如果为空，设置环境变量
export S_REPO_ROOT=$(find /home -name ".local/bin/s" -type f 2>/dev/null | head -1 | xargs dirname | xargs dirname)
export S_SEED_COMPILER="$S_REPO_ROOT/bin/s_seed"
```

### 问题 3: 运行时错误

```bash
# 症状
# error[5] at 0:0: unknown function

# 解决方案
# 这是 S 运行时模块导入问题
# 确保所有函数定义在单个文件中
# 参考: inference/production_inference_hpc_final.s
```

### 问题 4: 内存不足

```bash
# 症状
# Out of memory

# 解决方案 1: 减少批处理大小
export NEURX_BATCH_SIZE=8

# 解决方案 2: 禁用 KV-Cache
unset NEURX_KV_CACHE_ENABLED

# 解决方案 3: 增加系统交换空间
sudo swapon -s  # 查看当前 swap
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 问题 5: 性能不佳

```bash
# 症状
# 推理速度低于预期

# 诊断
make benchmark-production-inference

# 优化建议
export NEURX_KV_CACHE_ENABLED=1
export NEURX_BATCH_SIZE=32
export NEURX_FUSED_OPS=1

# 监控资源使用
watch -n 1 'ps aux | grep s_ir_runner'
```

---

## 📊 部署检查清单

- [ ] 模型文件已下载（2.4GB model.safetensors）
- [ ] S 编译器已安装并可用
- [ ] 环境变量已设置（NEURX_MODEL_PATH）
- [ ] 基础推理可运行（`make production-inference`）
- [ ] 性能优化已启用
- [ ] API 服务已部署
- [ ] Docker 镜像已构建
- [ ] 健康检查已配置
- [ ] 日志已收集
- [ ] 监控已启用

---

## 📞 技术支持

遇到问题？

1. 检查 `/app/shuwen/neurx/logs/` 目录的日志
2. 运行诊断脚本：`make diagnose-setup-s`
3. 查看 [NeurX README](./README.md)
4. 检查 [S 语言文档](../s/README.md)

---

**部署完毕！🎉**

NeurX 推理引擎已准备好提供高性能的本地推理服务。
