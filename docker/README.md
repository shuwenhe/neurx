# NeurX Docker 部署指南

## 📋 快速开始

### 方式 1: 使用 docker-compose (推荐)

```bash
# 进入 docker 目录
cd /home/shuwen/shuwen/neurx/docker

# 构建镜像
docker-compose build

# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f neurx-inference

# 停止服务
docker-compose down
```

### 方式 2: 手动 docker build & run

```bash
# 构建镜像·
docker build -t neurx-inference:latest \
  -f /home/shuwen/shuwen/neurx/docker/Dockerfile.inference \
  /home/shuwen/shuwen

# 启动容器
docker run -d \
  --name neurx-inference \
  --gpus all \
  -e NEURX_BACKEND=cuda \
  -p 8080:8080 \
  -p 8081:8081 \
  -p 9090:9090 \
  -v /home/shuwen/shuwen/posttrain:/opt/app/posttrain:ro \
  neurx-inference:latest

# 查看日志
docker logs -f neurx-inference
```

---

## 🔧 配置说明

### 环境变量

编辑 `docker-compose.yml` 中的 `environment` 部分：

| 变量 | 说明 | 默认值 | 选项 |
|------|------|--------|------|
| `NEURX_BACKEND` | 推理后端 | `cpu` | `cpu`, `cuda`, `npu` |
| `NEURX_BATCH_SIZE` | 批处理大小 | `4` | 1-32 |
| `NEURX_KV_BLOCKS` | KV缓存块数 | `64` | 16-256 |
| `NEURX_NUM_WORKERS` | 工作者数 | `4` | 1-16 |
| `NEURX_LOG_LEVEL` | 日志级别 | `INFO` | `DEBUG`, `INFO`, `WARN`, `ERROR` |

### GPU 支持

如果需要使用 CUDA，确保：

1. 安装 nvidia-docker:
```bash
sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker
```

2. 修改 `docker-compose.yml`:
```yaml
environment:
  NEURX_BACKEND: "cuda"
```

或使用 docker run:
```bash
docker run -d \
  --gpus all \
  -e NEURX_BACKEND=cuda \
  ...
```

---

## ✅ 验证服务

### 1. 检查容器状态

```bash
docker ps | grep neurx-inference
docker stats neurx-inference
```

### 2. 查看日志

```bash
docker logs neurx-inference
docker logs -f neurx-inference  # 实时日志
```

### 3. 健康检查

```bash
# 健康检查端点
curl http://localhost:8080/health/ready
curl http://localhost:8080/health/live

# 返回示例:
# {"status": "ready", "version": "1.0"}
```

### 4. API 测试

```bash
# 发送推理请求
curl -X POST http://localhost:8080/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "base-model-posttrain",
    "prompt": "What is medical treatment?",
    "max_tokens": 100,
    "temperature": 0.7
  }'

# 流式输出
curl -X POST http://localhost:8080/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "base-model-posttrain",
    "prompt": "Describe medical care",
    "stream": true
  }'
```

### 5. 监控指标

```bash
# Prometheus 指标
curl http://localhost:9090/metrics | grep neurx_

# 关键指标:
# - neurx_request_latency_ms
# - neurx_throughput_tokens_per_sec
# - neurx_kv_cache_hit_rate
# - neurx_gpu_memory_used_gb
```

---

## 🚀 常用操作

### 停止和删除容器

```bash
# 停止容器
docker stop neurx-inference

# 删除容器
docker rm neurx-inference

# 停止并删除
docker stop neurx-inference && docker rm neurx-inference

# 使用 docker-compose
docker-compose down
```

### 查看容器信息

```bash
# 进入容器
docker exec -it neurx-inference bash

# 查看容器详情
docker inspect neurx-inference

# 查看容器资源使用
docker stats neurx-inference
```

### 重新构建镜像

```bash
# 清除旧镜像
docker rmi neurx-inference:latest

# 重新构建
docker build -t neurx-inference:latest \
  -f Dockerfile.inference \
  /home/shuwen/shuwen

# 使用 compose
docker-compose build --no-cache
```

### 导出日志和指标

```bash
# 导出日志到文件
docker logs neurx-inference > neurx-inference.log 2>&1

# 导出 Prometheus 指标
curl http://localhost:9090/metrics > metrics.txt

# 导出容器配置
docker inspect neurx-inference > container-config.json
```

---

## 🐛 常见问题

### Q1: Docker 构建失败 - "no such file or directory"

**原因**: 目录结构不对

**解决方案**:
```bash
# 确保在正确的位置运行
cd /home/shuwen/shuwen

# 检查文件存在
ls -la neurx/docker/Dockerfile.inference
ls -la posttrain/model.safetensors
ls -la train/s/bin/s

# 重新构建
docker build -t neurx-inference:latest \
  -f neurx/docker/Dockerfile.inference \
  .
```

### Q2: 容器启动后立即退出

**原因**: 推理引擎找不到模型文件

**解决方案**:
```bash
# 检查容器日志
docker logs neurx-inference

# 检查挂载的模型文件
docker exec neurx-inference ls -lah /opt/app/posttrain/

# 确保路径正确
docker run -d \
  -v /home/shuwen/shuwen/posttrain:/opt/app/posttrain:ro \
  ...
```

### Q3: GPU 不可用 - "could not open GPU"

**原因**: nvidia-docker 未安装或未配置

**解决方案**:
```bash
# 安装 nvidia-docker
sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker

# 验证 GPU 可用
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi

# 使用 --gpus 参数
docker run -d --gpus all ...
```

### Q4: 内存溢出 - "Out of memory"

**原因**: 批大小过大或 KV 缓存配置不当

**解决方案**:
```bash
# 降低批大小
-e NEURX_BATCH_SIZE=2

# 减少 KV 缓存块数
-e NEURX_KV_BLOCKS=32

# 限制容器内存
docker run -m 8g ...

# 或在 docker-compose 中:
# mem_limit: 8g
```

### Q5: 端口被占用 - "bind: address already in use"

**原因**: 端口已被其他服务占用

**解决方案**:
```bash
# 查看占用端口的进程
sudo lsof -i :8080
sudo netstat -tlnp | grep 8080

# 修改端口映射
docker run -p 8081:8080 ...

# 或修改 docker-compose.yml
# ports:
#   - "8081:8080"
```

### Q6: 日志输出过多 - "disk space full"

**原因**: Docker 日志占用过多磁盘空间

**解决方案**:
```bash
# 限制日志大小 (已在 docker-compose 中配置)
# logging:
#   options:
#     max-size: "10m"
#     max-file: "3"

# 手动清理日志
docker logs --tail 100 neurx-inference
docker container prune -f
```

---

## 📊 性能配置建议

### 开发环境

```yaml
environment:
  NEURX_BACKEND: "cpu"
  NEURX_BATCH_SIZE: 1
  NEURX_KV_BLOCKS: 16
  NEURX_NUM_WORKERS: 2
```

### 单机生产 (CPU)

```yaml
environment:
  NEURX_BACKEND: "cpu"
  NEURX_BATCH_SIZE: 4
  NEURX_KV_BLOCKS: 64
  NEURX_NUM_WORKERS: 4
```

### 单机生产 (GPU)

```yaml
environment:
  NEURX_BACKEND: "cuda"
  NEURX_BATCH_SIZE: 8
  NEURX_KV_BLOCKS: 128
  NEURX_NUM_WORKERS: 4

deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all
          capabilities: [gpu]
```

---

## 🔗 相关文档

- [完整部署指南](../INFERENCE_DEPLOYMENT_GUIDE.md#方案-2-docker-容器部署)
- [快速参考](../INFERENCE_QUICK_REFERENCE.md#-docker-快速启动)
- [文档导航索引](../INFERENCE_DOCUMENTATION_INDEX.md)

---

**最后更新**: 2026-08-12
