# NeurX GPU-Ready Distributed Inference System - 完整部署指南

## 📋 目录
1. [系统架构](#系统架构)
2. [当前状态](#当前状态)
3. [部署步骤](#部署步骤)
4. [GPU 推理启用](#gpu-推理启用)
5. [API 文档](#api-文档)
6. [故障排除](#故障排除)

---

## 🏗️ 系统架构

### 网络拓扑
```
┌─────────────┐
│   macOS     │  本地开发环境
│  127.0.0.1  │  ARM64 架构
└──────┬──────┘
       │ SSH 隧道 (端口转发)
       │ :8000 → 192.168.10.39:8000 (API)
       │ :8081 → 192.168.10.39:8081 (Web UI)
       │
     ──┴──
       │
   ┌───┴────────────────────┬──────────────────┐
   │                        │                  │
┌──▼──────────┐      ┌─────▼──────┐    ┌─────▼──────┐
│ Controller  │      │   Worker   │    │   Worker2  │
│192.168.10.39│◄─────►│192.168.10.75  192.168.10.76│
│ Port: 8000  │      │ Port: 8001 │    │ Port: 8002 │
│ Port: 8081  │      │            │    │            │
└─────────────┘      └────────────┘    └────────────┘
```

### 推理引擎层次结构

```
┌─────────────────────────────────────────┐
│  NeurX GPU-Ready Inference Service      │
│  (neurx_inference_gpu_ready.py)         │
└────────────────┬────────────────────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
    ▼            ▼            ▼
┌─────────┐  ┌────────┐  ┌──────────┐
│ GPU     │  │ S IR   │  │ Python   │
│ CUDA    │  │ Native │  │ Optimized│
│ Backend │  │ Backend│  │ Backend  │
└─────────┘  └────────┘  └──────────┘
    │            │            │
    └────────────┼────────────┘
                 │
    ┌────────────▼────────────┐
    │  Hardware Execution     │
    │  (GPU/CPU/Hybrid)       │
    └─────────────────────────┘
```

---

## 📊 当前状态

### ✅ 已部署组件
- **推理服务**: `neurx_inference_gpu_ready.py` (运行中)
- **启动脚本**: `start_inference_gpu_ready.sh` 
- **后端支持**: 
  - ✅ Python 优化实现
  - ✅ S IR Native (可用)
  - ⏳ GPU CUDA (待激活)

### 💻 硬件配置

| 组件 | Controller | Worker | 本地 Mac |
|------|-----------|--------|---------|
| **操作系统** | Ubuntu 24.04 | Ubuntu 24.04 | macOS Sonoma |
| **架构** | x86_64 | x86_64 | ARM64 |
| **CPU** | 12核 Intel i5-10400 | ? | 8核 Apple Silicon |
| **内存** | 31GB | ? | 16GB |
| **GPU** | ❌ 无 | ❓ 无法连接 | ❌ 无 |
| **推理** | 🟢 CPU-Ready | ⏳ 待部署 | ⏳ SSH 隧道 |

### 🔌 网络连接

| 服务 | 本地访问 | 远程地址 | 状态 |
|-----|---------|---------|------|
| **推理 API** | http://127.0.0.1:8000 | 192.168.10.39:8000 | ✅ 运行 |
| **Web UI** | http://127.0.0.1:8081 | 192.168.10.39:8081 | ✅ 运行 |
| **SSH 隧道** | 本地 8000/8081 | 远程 8000/8081 | ✅ 活跃 |

---

## 🚀 部署步骤

### 步骤 1: 启动 SSH 隧道（本地）
```bash
bash /Users/shuwen/shuwen/neurx/config/clusters/2node_deployment/start_web_ui_local.sh
```

### 步骤 2: 在 Controller 上部署 GPU-Ready 服务

```bash
# 远程连接
ssh shuwen@192.168.10.39

# 停止旧服务
pkill -9 -f "neurx_inference" || true

# 启动新服务
cd /app/neurx/config/clusters/2node_deployment
bash start_inference_gpu_ready.sh
```

### 步骤 3: 验证部署
```bash
# 检查 API 状态
curl http://127.0.0.1:8000/health | jq '.'

# 查看 Web UI
open http://127.0.0.1:8081
```

---

## 🎮 GPU 推理启用

### 前置条件
要启用 GPU 推理，您的服务器需要：
1. ✅ NVIDIA GPU (Tesla/RTX series)
2. ✅ CUDA Toolkit (11.8+)
3. ✅ cuDNN (8.0+)
4. ✅ NVIDIA Driver

### 当前状态
- **Controller**: ❌ 无 NVIDIA GPU
- **Worker**: ❓ 无法连接验证
- **本地 Mac**: ❌ 无 NVIDIA GPU

### 启用 GPU 推理（如果有 GPU）

#### 方式 1: 自动检测（推荐）
```bash
# 服务会自动检测 GPU 并启用
export NEURX_USE_GPU=auto  # 默认值
bash start_inference_gpu_ready.sh
```

#### 方式 2: 强制使用 GPU
```bash
export NEURX_USE_GPU=true
export NEURX_GPU_DEVICE=0  # GPU ID (0,1,2...)
bash start_inference_gpu_ready.sh
```

#### 方式 3: 强制使用 CPU
```bash
export NEURX_USE_GPU=false
bash start_inference_gpu_ready.sh
```

### 检查 GPU 状态
```bash
# 从 /health 端点查看 GPU 信息
curl -s http://127.0.0.1:8000/health | python3 -m json.tool | grep -A 5 '"gpu"'

# 输出示例：
# "gpu": {
#     "available": true,           # GPU 是否可用
#     "device_count": 2,           # GPU 数量
#     "backend": "CUDA",           # 后端类型
#     "active_device": 0           # 当前使用的 GPU ID
# }
```

---

## 📡 API 文档

### 1. 健康检查 (Health Check)
```bash
GET /health

响应示例：
{
  "status": "healthy",
  "timestamp": "2026-08-29T16:48:59.498395",
  "role": "controller",
  "cluster": "neurx-distributed-2node",
  "rank": 0,
  "world_size": 2,
  "inference_backend": "S-IR-Native-CPU",
  "model": "Qwen/Qwen2.5-0.5B-Instruct",
  "gpu": {
    "available": false,
    "device_count": 0,
    "backend": "CPU",
    "active_device": null
  },
  "uptime_seconds": 29
}
```

### 2. 获取模型列表
```bash
GET /v1/models

响应示例：
{
  "object": "list",
  "data": [
    {
      "id": "Qwen/Qwen2.5-0.5B-Instruct",
      "object": "model",
      "owned_by": "neurx",
      "backend": "S-IR-Native-CPU"
    }
  ]
}
```

### 3. 文本补全
```bash
POST /v1/completions
Content-Type: application/json

请求体：
{
  "prompt": "Hello, how are you?",
  "max_tokens": 50,
  "temperature": 0.7,
  "stream": false
}

响应示例：
{
  "id": "cmpl-1787993339",
  "object": "text_completion",
  "created": 1787993339,
  "model": "Qwen/Qwen2.5-0.5B-Instruct",
  "choices": [
    {
      "text": "I'm doing well, thank you for asking...",
      "index": 0,
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 3,
    "completion_tokens": 50
  }
}
```

### 4. Chat 补全
```bash
POST /v1/chat/completions
Content-Type: application/json

请求体：
{
  "messages": [
    {"role": "user", "content": "What is AI?"}
  ],
  "max_tokens": 100,
  "temperature": 0.7
}

响应示例：
{
  "id": "chatcmpl-...",
  "object": "chat.completion",
  "created": 1787993339,
  "model": "Qwen/Qwen2.5-0.5B-Instruct",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "AI stands for Artificial Intelligence..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 5,
    "completion_tokens": 100
  }
}
```

---

## 🔍 故障排除

### 问题 1: "Failed to fetch" 错误
**症状**: Web UI 无法连接到 API

**解决方案**:
```bash
# 1. 检查 SSH 隧道
ps aux | grep "ssh -N" | grep 8000

# 2. 检查推理服务
curl http://127.0.0.1:8000/health

# 3. 重启隧道
pkill -f "ssh -N.*8000"
bash start_web_ui_local.sh
```

### 问题 2: API 响应缓慢
**症状**: 推理请求超时或响应很慢

**解决方案**:
```bash
# 1. 检查 CPU 使用情况
ssh shuwen@192.168.10.39 "top -b -n 1 | head -10"

# 2. 检查内存
ssh shuwen@192.168.10.39 "free -h"

# 3. 查看推理日志
ssh shuwen@192.168.10.39 "tail -50 /app/neurx/config/clusters/2node_deployment/inference_gpu_ready.log"
```

### 问题 3: Worker 连接失败
**症状**: SSH 连接到 Worker (192.168.10.75) 被拒绝

**解决方案**:
```bash
# 1. 测试网络连接
ping -c 3 192.168.10.75

# 2. 尝试带密钥的 SSH
ssh -i ~/.ssh/id_rsa shuwen@192.168.10.75

# 3. 检查 SSH 配置
ssh -vvv shuwen@192.168.10.75

# 4. 从 Controller 连接 Worker
ssh shuwen@192.168.10.39
ssh shuwen@192.168.10.75  # 内部网络连接
```

### 问题 4: GPU 推理未启用
**症状**: `/health` 端点显示 `"available": false`

**解决方案**:
```bash
# 1. 检查 NVIDIA 驱动
ssh shuwen@192.168.10.39 "nvidia-smi"

# 2. 检查 CUDA 工具包
ssh shuwen@192.168.10.39 "nvcc --version"

# 3. 安装 CUDA (如果缺失)
ssh shuwen@192.168.10.39 << 'EOF'
sudo apt-get update
sudo apt-get install -y nvidia-cuda-toolkit
EOF

# 4. 强制启用 GPU
export NEURX_USE_GPU=true
bash start_inference_gpu_ready.sh
```

---

## 📈 性能优化

### CPU 推理优化
```bash
# 增加线程数
export OMP_NUM_THREADS=12
bash start_inference_gpu_ready.sh

# 启用 SIMD 优化
export MKL_NUM_THREADS=12
bash start_inference_gpu_ready.sh
```

### GPU 推理优化
```bash
# 启用 GPU 缓存
export CUDA_LAUNCH_BLOCKING=0

# 设置 GPU 内存比例
export CUDA_VISIBLE_DEVICES=0

# 启用 TensorRT 优化
export USE_TENSORRT=1

bash start_inference_gpu_ready.sh
```

### 分布式推理
```bash
# Controller 节点
export NEURX_ROLE=controller
export MASTER_ADDR=192.168.10.39
export RANK=0
bash start_inference_gpu_ready.sh

# Worker 节点
export NEURX_ROLE=worker
export MASTER_ADDR=192.168.10.39
export RANK=1
bash start_inference_gpu_ready.sh
```

---

## 📚 相关文件

```
/app/neurx/config/clusters/2node_deployment/
├── neurx_inference_gpu_ready.py         # GPU-Ready 推理引擎
├── start_inference_gpu_ready.sh          # 启动脚本
├── neurx_inference_prod.py              # 基础推理引擎
├── start_inference_prod.sh               # 基础启动脚本
├── controller.env                        # Controller 环境变量
├── worker_rank0.env                      # Worker 环境变量
├── start_web_ui_local.sh                 # SSH 隧道脚本 (本地)
└── inference_gpu_ready.log               # 推理日志
```

---

## 🔗 快速链接

- **本地 Web UI**: http://127.0.0.1:8081
- **本地 API**: http://127.0.0.1:8000
- **Controller SSH**: `ssh shuwen@192.168.10.39`
- **Worker SSH**: `ssh shuwen@192.168.10.75`

---

## 📝 更新日志

### 2026-08-29
- ✅ 部署 GPU-Ready 推理服务
- ✅ 添加自动 GPU 检测
- ✅ 实现 CPU/GPU 自动降级
- ✅ 创建完整的部署文档

### TODO
- ⏳ 修复 Worker SSH 连接
- ⏳ 部署 Worker 节点
- ⏳ 启用分布式推理
- ⏳ 性能优化和基准测试

---

**最后更新**: 2026-08-29  
**维护者**: NeurX 开发团队  
**版本**: 1.0.0-GPU-Ready
