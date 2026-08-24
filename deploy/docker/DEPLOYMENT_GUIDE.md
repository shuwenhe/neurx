# Docker 完整部署指南

## 🚀 核心概念

NeurX Docker 设置分为三层：

1. **Dockerfile** - 生产级镜像（最优化）
2. **Dockerfile.dev** - 开发镜像（便于调试）
3. **Dockerfile.prod** - 超轻量生产镜像（distroless）

---

## 📦 一键启动

### 最简单的方式

```bash
# 1. 构建镜像
make docker-build-cpu

# 2. 下载模型
make docker-download-model MODEL=Qwen/Qwen2.5-0.5B-Instruct

# 3. 启动服务
make docker-start-cpu
```

### 完全自动化（一条命令）

```bash
#!/bin/bash
# 创建 quick-start.sh

cd neurx

# 构建
docker build -t neurx:latest -f Dockerfile .

# 创建模型目录
mkdir -p src/models/catalog/default

# 运行（需要提前下载模型或容器会提示）
docker run -it \
  -v $(pwd)/models:/models \
  -e NEURX_INFER_DEVICE=cpu \
  neurx:latest start
```

---

## 🎯 常见场景

### 场景 1: 个人开发（CPU）

```bash
# 构建
make docker-build-cpu

# 启动交互式 shell
make docker-shell

# 或者直接启动服务
docker run -it \
  -v ./models:/models \
  -p 8000:8000 \
  neurx:latest start
```

### 场景 2: 企业部署（GPU 集群）

```yaml
# kubernetes/neurx-deployment.yaml

apiVersion: app/v1
kind: Deployment
metadata:
  name: neurx-inference
  namespace: ai-services
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
        image: registry.company.com/neurx:latest-gpu
        resources:
          requests:
            nvidia.com/gpu: 1
            memory: "8Gi"
            cpu: "4"
          limits:
            nvidia.com/gpu: 1
            memory: "16Gi"
            cpu: "8"
        ports:
        - containerPort: 8000
          name: http
        - containerPort: 9090
          name: metrics
        env:
        - name: NEURX_INFER_DEVICE
          value: "gpu"
        - name: NEURX_CHAT_MAX_NEW_TOKENS
          value: "1024"
        volumeMounts:
        - name: models
          mountPath: /models
        - name: logs
          mountPath: /logs
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 5
      volumes:
      - name: models
        persistentVolumeClaim:
          claimName: neurx-models-pvc
      - name: logs
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: neurx-inference-service
  namespace: ai-services
spec:
  selector:
    app: neurx
  ports:
  - port: 8000
    targetPort: 8000
    name: http
  - port: 9090
    targetPort: 9090
    name: metrics
  type: LoadBalancer
```

### 场景 3: CI/CD 管道

```yaml
# .github/workflow/docker-build.yml

name: Build Docker Image

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: deploy/docker/setup-buildx-action@v2
    
    - name: Build and push
      uses: deploy/docker/build-push-action@v4
      with:
        context: .
        file: ./Dockerfile
        push: true
        tags: |
          ${{ secrets.REGISTRY }}/neurx:latest
          ${{ secrets.REGISTRY }}/neurx:${{ github.sha }}
        build-args: |
          CUDA_VERSION=12.1
```

### 场景 4: 本地开发环境

```bash
# 使用 docker-compose 启动完整开发栈

docker-compose up -d neurx-cpu

# 查看实时日志
docker-compose logs -f neurx-cpu

# 进入容器调试
docker-compose exec neurx-cpu bash

# 停止
docker-compose down
```

---

## 🔧 配置参考

### 环境变量完整列表

| 变量 | 默认值 | 说明 | 示例 |
|------|-------|------|------|
| `NEURX_MODEL_DIR` | `/models/default` | 模型权重路径 | `/models/qwen-7b` |
| `NEURX_INFER_DEVICE` | `cpu` | 推理设备 | `gpu`, `cpu` |
| `NEURX_S_PORT` | `8000` | 服务端口 | `8001` |
| `NEURX_S_HOST` | `0.0.0.0` | 监听地址 | `127.0.0.1` |
| `NEURX_CPU_THREADS` | `4` | CPU 线程数 | `8` |
| `NEURX_CHAT_MAX_NEW_TOKENS` | `512` | 最大生成长度 | `2048` |

### 使用示例

```bash
docker run \
  -e NEURX_INFER_DEVICE=gpu \
  -e NEURX_CHAT_MAX_NEW_TOKENS=1024 \
  -e NEURX_CPU_THREADS=8 \
  -v ./models:/models \
  neurx:latest start
```

---

## 📊 镜像大小对比

| 镜像 | 大小 | 基础镜像 | 用途 |
|------|------|---------|------|
| neurx:latest | ~500MB | ubuntu:22.04 | 生产通用 |
| neurx:latest-gpu | ~800MB | ubuntu:22.04 + CUDA | GPU 推理 |
| neurx:dev | ~600MB | ubuntu:22.04 | 开发调试 |
| neurx:prod-slim | ~200MB | distroless | 极限优化 |

---

## 🚨 故障排查

### 问题 1: 容器启动失败

```bash
# 检查日志
docker logs <container-id>

# 进入调试模式
docker run -it neurx:latest shell

# 检查模型文件
docker run -it \
  -v ./models:/models \
  neurx:latest ls -lah /models/default/
```

### 问题 2: GPU 不识别

```bash
# 检查 NVIDIA Docker
docker run --rm --gpus all nvidia/cuda:12.1-runtime-ubuntu22.04 nvidia-smi

# 在容器中检查
docker run --rm --gpus all neurx:latest-gpu nvidia-smi

# 指定特定 GPU
docker run --gpus '"device=0,1"' neurx:latest-gpu start
```

### 问题 3: 内存不足

```bash
# 限制内存使用
docker run \
  -m 4g \
  --memory-swap 4g \
  -v ./models:/models \
  neurx:latest start

# 使用量化或小模型
docker run \
  -e NEURX_MODEL_DIR=/models/small \
  neurx:latest start
```

---

## 📈 性能优化

### 1. 使用 BuildKit 加速构建

```bash
DOCKER_BUILDKIT=1 docker build -t neurx:latest .
```

### 2. 多阶段构建

```dockerfile
# 自动清理中间层
FROM ubuntu as builder
RUN apt-get install build-essential
RUN make build

FROM ubuntu
COPY --from=builder /build /app
```

### 3. 缓存优化

```bash
# 分离改动频率
# 先 COPY 变化不频繁的文件
COPY requirements.txt .
RUN pip install -r requirements.txt

# 再 COPY 经常变化的代码
COPY . .
```

---

## 🔐 安全实践

### 1. 使用 distroless 基础镜像

```dockerfile
FROM gcr.io/distroless/cc-debian12:nonroot
```

### 2. 非 root 用户运行

```dockerfile
USER nobody
```

### 3. 只读根文件系统

```bash
docker run --read-only \
  --tmpfs /tmp \
  -v ./models:/models:ro \
  neurx:latest start
```

### 4. 网络隔离

```bash
docker run \
  --network custom-network \
  -p 8000:8000 \
  neurx:latest start
```

---

## 📋 检查清单

生产部署前的检查：

- [ ] 镜像大小 < 1GB
- [ ] 构建时间 < 10 分钟
- [ ] 启动时间 < 60 秒
- [ ] 健康检查通过
- [ ] GPU 测试通过
- [ ] 模型加载成功
- [ ] API 响应正常
- [ ] 日志输出正确
- [ ] 内存使用稳定
- [ ] CPU 使用合理

---

## 相关文档

- [Dockerfile 最佳实践](https://docs.docker.com/develop/dev-best-practices/dockerfile_best-practices/)
- [NVIDIA Docker](https://github.com/NVIDIA/nvidia-docker)
- [Docker Compose](https://docs.docker.com/compose/)
- [Kubernetes 部署](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
