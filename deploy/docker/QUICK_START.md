# NeurX Docker Quick Start Guide

快速使用 NeurX Docker 镜像启动推理服务。

## Prerequisites

- Docker >= 20.10
- Docker Compose >= 1.29
- (For GPU) NVIDIA Docker Runtime 和 NVIDIA GPU

## One-Command Quick Start

### 1️⃣ CPU 推理服务（最简单）

```bash
# 构建镜像
make docker-build-cpu

# 启动服务（需要先下载模型）
make docker-start-cpu
```

### 2️⃣ 一键启动（包含模型下载）

```bash
# 下载模型 (Qwen 0.5B - 轻量模型)
make docker-download-model MODEL=Qwen/Qwen2.5-0.5B-Instruct

# 启动推理服务
make docker-start-cpu
```

### 3️⃣ GPU 加速推理

```bash
# 构建 GPU 镜像
make docker-build-gpu

# 启动 GPU 服务
make docker-start-gpu
```

### 4️⃣ OpenAI 兼容 API 服务器

```bash
# 启动 API 服务
make docker-start-api

# 测试 API
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'
```

---

## 命令参考

| 命令 | 说明 |
|------|------|
| `make docker-build-cpu` | 构建 CPU 镜像 |
| `make docker-build-gpu` | 构建 GPU 镜像 |
| `make docker-build-all` | 构建所有镜像 |
| `make docker-start-cpu` | 启动 CPU 服务 |
| `make docker-start-gpu` | 启动 GPU 服务 |
| `make docker-start-api` | 启动 API 服务器 |
| `make docker-download-model MODEL=xxx` | 下载模型 |
| `make docker-stop` | 停止所有容器 |
| `make docker-logs` | 查看日志 |
| `make docker-shell` | 进入容器 Shell |
| `make docker-test` | 健康检查测试 |

---

## Docker 直接命令

### 交互式推理（CPU）

```bash
docker run -it \
  -v $(pwd)/models:/models \
  neurx:latest start
```

### API 服务器（CPU）

```bash
docker run -d \
  -v $(pwd)/models:/models \
  -p 8000:8000 \
  -e NEURX_INFER_DEVICE=cpu \
  neurx:latest api
```

### API 服务器（GPU）

```bash
docker run -d \
  --gpus all \
  -v $(pwd)/models:/models \
  -p 8000:8000 \
  -e NEURX_INFER_DEVICE=gpu \
  neurx:latest api
```

### 下载模型

```bash
docker run -it \
  -v $(pwd)/models:/models \
  neurx:latest download-model Qwen/Qwen2.5-0.5B-Instruct
```

---

## 环境变量配置

| 变量 | 默认值 | 说明 |
|------|-------|------|
| `NEURX_MODEL_DIR` | `/models/default` | 模型权重路径 |
| `NEURX_INFER_DEVICE` | `cpu` | 推理设备 (backends/cpu/gpu) |
| `NEURX_S_PORT` | `8000` | 服务端口 |
| `NEURX_S_HOST` | `0.0.0.0` | 服务地址 |
| `NEURX_CPU_THREADS` | `4` | CPU 线程数 |
| `NEURX_CHAT_MAX_NEW_TOKENS` | `512` | 最大生成 Token 数 |

**示例**:
```bash
docker run -it \
  -v $(pwd)/models:/models \
  -e NEURX_CPU_THREADS=8 \
  -e NEURX_CHAT_MAX_NEW_TOKENS=1024 \
  neurx:latest start
```

---

## 支持的模型

推荐在 Hugging Face 上使用以下模型：

| 模型 | 大小 | 速度 | 质量 |
|------|------|------|------|
| `Qwen/Qwen2.5-0.5B-Instruct` | 0.5B | ⚡⚡⚡ | ⭐⭐ |
| `Qwen/Qwen2.5-1.5B-Instruct` | 1.5B | ⚡⚡ | ⭐⭐⭐ |
| `Qwen/Qwen2.5-3B-Instruct` | 3B | ⚡ | ⭐⭐⭐⭐ |
| `Qwen/Qwen2.5-7B-Instruct` | 7B | ⏱ | ⭐⭐⭐⭐ |
| `meta-llama/Llama-2-7b-hf` | 7B | ⏱ | ⭐⭐⭐⭐ |

**对于 CPU 推理建议**: Qwen2.5-0.5B 或 1.5B
**对于 GPU 推理建议**: Qwen2.5-3B 或 7B (需要 ≥8GB 显存)

---

## Docker Compose 配置

已内置三个预配置的服务：

### CPU 推理 (默认)
```bash
docker-compose up neurx-cpu
```

### GPU 推理
```bash
docker-compose --profile gpu up neurx-gpu
```

### API 服务器
```bash
docker-compose --profile api up neurx-api
```

---

## 镜像大小和性能

| 镜像 | 大小 | 构建时间 | 启动时间 |
|------|------|---------|---------|
| neurx:latest | ~500MB | ~10min | ~30s |
| neurx:latest-gpu | ~800MB | ~15min | ~60s |

---

## 常见问题

### Q: 镜像很大怎么办？
**A**: 由于需要编译 S 语言和 CUDA 支持，镜像可能较大。可以用以下方法优化：
- 使用多阶段构建（已内置）
- 清理构建缓存: `docker system prune`

### Q: GPU 推理不工作？
**A**: 检查以下几点：
```bash
# 检查 NVIDIA Docker
docker run --rm --gpus all nvidia/cuda:12.1-runtime-ubuntu22.04 nvidia-smi

# 指定 GPU
docker run --gpus '"device=0"' neurx:latest api
```

### Q: 如何自定义模型路径？
**A**:
```bash
docker run -it \
  -v /path/to/custom/models:/models \
  -e NEURX_MODEL_DIR=/models/custom \
  neurx:latest start
```

### Q: 如何保留日志？
**A**:
```bash
docker run -it \
  -v $(pwd)/models:/models \
  -v $(pwd)/logs:/logs \
  neurx:latest api
```

---

## 生产部署建议

### 1. 使用 docker-compose 编排多个服务

```yaml
version: '3.8'
services:
  neurx-api:
    image: neurx:latest
    ports:
      - "8000:8000"
    environment:
      NEURX_INFER_DEVICE: gpu
      NEURX_S_PORT: 8000
    volumes:
      - /data/models:/models
      - /data/logs:/logs
    restart: always
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### 2. Kubernetes 部署

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: neurx-inference
spec:
  replicas: 3
  selector:
    matchLabels:
      app: neurx
  template:
    metadata:
      labels:
        app: neurx
    spec:
      containers:
      - name: neurx
        image: neurx:latest
        resources:
          requests:
            nvidia.com/gpu: 1
          limits:
            nvidia.com/gpu: 1
        ports:
        - containerPort: 8000
        volumeMounts:
        - name: models
          mountPath: /models
      volumes:
      - name: models
        hostPath:
          path: /data/models
```

### 3. 监控和日志收集

```bash
# 使用 Prometheus 导出指标
docker run -d \
  -p 8000:8000 \
  -p 9090:9090 \
  neurx:latest api

# 查看实时性能
curl http://localhost:9090/metrics
```

---

## 更多帮助

```bash
# 查看容器帮助信息
docker run neurx:latest help

# 进入调试模式
make docker-shell

# 查看构建日志
docker build -t neurx:latest --progress=plain .
```

---

## 相关文档

- [NeurX 官方文档](../README.md)
- [Docker 最佳实践](https://docs.docker.com/develop/dev-best-practices/)
- [NVIDIA Docker 文档](https://github.com/NVIDIA/nvidia-docker)
