# NeurX 分布式推理 - 192.168.10.39 + 192.168.10.75 部署方案

## 🎯 系统架构

```
┌─────────────────────────────────────────┐
│  Controller (Master)                    │
│  192.168.10.39:29500                    │
│  - Node Orchestration                   │
│  - Task Scheduling                      │
│  - REST API Server :8000                │
│  - Heartbeat Management                 │
└────────────────┬────────────────────────┘
                 │
    NCCL AllReduce Protocol (Port 29500)
                 │
    ┌────────────▼──────────────┐
    │  Worker (Slave)           │
    │  192.168.10.75:29501      │
    │  - GPU Inference Engine   │
    │  - KV Cache Management    │
    │  - Model Inference        │
    └───────────────────────────┘
```

## 📋 配置文件位置

所有配置文件已生成到：
```
/Users/shuwen/shuwen/neurx/config/clusters/2node_deployment/
├── controller.env              # Controller 环境变量
├── worker_rank0.env            # Worker 环境变量
├── start_controller.sh         # Controller 启动脚本
├── start_worker.sh             # Worker 启动脚本 (SSH)
├── monitor.sh                  # 集群监控脚本
└── DEPLOYMENT_GUIDE.md         # 详细部署指南
```

## 🚀 部署步骤（3 步）

### 第 1 步：在 Controller 上启动 (192.168.10.39)

**方式 A：手动启动（推荐）**

```bash
# 在 Controller 机器上
cd /Users/shuwen/shuwen/neurx

# 加载配置
source config/clusters/2node_deployment/controller.env

# 创建必要目录
mkdir -p /tmp/neurx_cluster/{heartbeat,logs}
mkdir -p artifact/{checkpoints,inference_output}

# 启动 Controller
./cmd/controller/main.s

# 或者如果已编译：
# ./build/neurx-controller
```

**预期输出：**
```
[neurx-controller] discovery result:
[neurx-controller] selected node=controller-0
[neurx-controller] placement ready
[neurx-controller] heartbeat=...
Listening on 0.0.0.0:8000
```

### 第 2 步：在 Worker 上启动 (192.168.10.75)

**方式 A：通过脚本 SSH 启动**

```bash
# 在 Controller 机器上运行
bash /Users/shuwen/shuwen/neurx/config/clusters/2node_deployment/start_worker.sh
```

**方式 B：手动 SSH 启动**

```bash
# 在 Controller 机器上
ssh shuwen@192.168.10.75
```

然后在 Worker 机器上运行：
```bash
cd ~/neurx

# 加载配置
source config/clusters/2node_deployment/worker_rank0.env

# 创建必要目录
mkdir -p /tmp/neurx_cluster/{heartbeat,logs}

# 启动 Worker
./cmd/worker/main.s

# 或者如果已编译：
# ./build/neurx-worker
```

**预期输出：**
```
[neurx-worker] rank=0 local_rank=0
[neurx-worker] master=192.168.10.39:29500
[neurx-worker] heartbeat=...
```

### 第 3 步：验证集群状态

```bash
# 在 Controller 机器上运行
bash /Users/shuwen/shuwen/neurx/config/clusters/2node_deployment/monitor.sh
```

**预期输出：**
```
✅ NCCL Port (29500):    LISTENING
✅ API Server (8000):    LISTENING
✅ NCCL Port (29501):    LISTENING
💓 HEARTBEAT: 1 file(s) found
```

## 🧪 测试推理

### 简单测试

```bash
# 获取模型列表
curl http://192.168.10.39:8000/v1/models
```

### 完整推理测试

```bash
curl -X POST http://192.168.10.39:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-0.5B-Instruct",
    "prompt": "What is machine learning?",
    "max_tokens": 100,
    "temperature": 0.7,
    "top_p": 0.9
  }'
```

### 流式推理测试

```bash
curl -X POST http://192.168.10.39:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-0.5B-Instruct",
    "prompt": "Explain quantum computing",
    "max_tokens": 200,
    "stream": true
  }'
```

## 📊 监控和日志

### 实时监控

```bash
# 监控集群状态
bash /Users/shuwen/shuwen/neurx/config/clusters/2node_deployment/monitor.sh

# 持续监控
watch bash /Users/shuwen/shuwen/neurx/config/clusters/2node_deployment/monitor.sh
```

### 查看日志

```bash
# Controller 日志
tail -f /tmp/neurx_cluster/logs/controller.log

# Worker 日志 (需要 SSH)
ssh shuwen@192.168.10.75 "tail -f /tmp/neurx_cluster/logs/worker.log"

# 所有日志
tail -f /tmp/neurx_cluster/logs/*
```

### 检查心跳

```bash
# 查看心跳文件
ls -la /tmp/neurx_cluster/heartbeat/

# 监视心跳更新
watch ls -la /tmp/neurx_cluster/heartbeat/
```

## 🔧 环境变量说明

### Controller 配置 (controller.env)

| 变量 | 值 | 说明 |
|-----|-----|------|
| `MASTER_ADDR` | 192.168.10.39 | Controller IP |
| `MASTER_PORT` | 29500 | NCCL 通信端口 |
| `WORLD_SIZE` | 2 | Worker 总数 |
| `NEURX_PORT` | 8000 | API 服务端口 |
| `NEURX_BACKEND` | nccl | 通信后端 |
| `NEURX_MAX_CONCURRENCY` | 128 | 最大并发请求 |

### Worker 配置 (worker_rank0.env)

| 变量 | 值 | 说明 |
|-----|-----|------|
| `RANK` | 0 | Worker 全局排序 |
| `LOCAL_RANK` | 0 | 本机 GPU 排序 |
| `MASTER_ADDR` | 192.168.10.39 | Controller IP |
| `WORLD_SIZE` | 2 | Worker 总数 |
| `NEURX_NODE_HOST` | 192.168.10.75 | Worker IP |

## 🐛 故障排查

### 问题 1：无法连接到 Controller

```bash
# 检查网络
ping 192.168.10.39

# 检查端口
nc -zv 192.168.10.39 29500

# 检查防火墙
sudo firewall-cmd --add-port=29500/tcp --permanent
sudo firewall-cmd --reload
```

### 问题 2：Worker 无法连接

```bash
# 检查网络连接
ping 192.168.10.75

# 检查 SSH
ssh shuwen@192.168.10.75 echo "OK"

# 检查 Worker 进程
ssh shuwen@192.168.10.75 "ps aux | grep neurx-worker"
```

### 问题 3：GPU 不可用

```bash
# Controller 检查本地 GPU
nvidia-smi

# Worker 检查 GPU
ssh shuwen@192.168.10.75 nvidia-smi

# 检查 CUDA
ssh shuwen@192.168.10.75 "nvcc --version"
```

### 问题 4：模型未找到

```bash
# 检查模型目录
ls -la /model/Qwen2.5-0.5B-Instruct/

# Worker 上检查
ssh shuwen@192.168.10.75 "ls -la /model/"

# 如果缺失，下载模型
python -c "
from transformers import AutoModel, AutoTokenizer
model = AutoModel.from_pretrained('Qwen/Qwen2.5-0.5B-Instruct', cache_dir='/model')
tokenizer = AutoTokenizer.from_pretrained('Qwen/Qwen2.5-0.5B-Instruct', cache_dir='/model')
"
```

## 📈 性能基准

**预期性能指标（2x RTX 4090）：**

| 指标 | 值 | 说明 |
|-----|-----|------|
| **吞吐量** | 500-1000 req/s | 每秒请求数 |
| **TTFT** | 10-15ms | 首字延迟 |
| **Per-token** | 5-8ms | 单字生成时间 |
| **P99 延迟** | 100-150ms | 99% 的请求延迟 |
| **GPU 内存** | ~4GB/node | 模型 + KV Cache |
| **总功耗** | ~400W | 两个 GPU |

## 💾 快速命令集

```bash
# 启动 Controller
cd /Users/shuwen/shuwen/neurx
source config/clusters/2node_deployment/controller.env
./cmd/controller/main.s

# 启动 Worker
ssh shuwen@192.168.10.75 'cd ~/neurx && source config/clusters/2node_deployment/worker_rank0.env && ./cmd/worker/main.s'

# 监控
bash /Users/shuwen/shuwen/neurx/config/clusters/2node_deployment/monitor.sh

# 测试
curl -X POST http://192.168.10.39:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "Qwen/Qwen2.5-0.5B-Instruct", "prompt": "Hi!", "max_tokens": 50}'

# 查看日志
tail -f /tmp/neurx_cluster/logs/*.log

# 停止
killall neurx-controller
ssh shuwen@192.168.10.75 'killall neurx-worker'
```

## 🔗 文件位置

| 文件 | 位置 |
|-----|------|
| 主项目 | `/Users/shuwen/shuwen/neurx` |
| 配置目录 | `config/clusters/2node_deployment/` |
| Controller 源代码 | `cmd/controller/main.s` |
| Worker 源代码 | `cmd/worker/main.s` |
| 部署指南 | `config/clusters/2node_deployment/DEPLOYMENT_GUIDE.md` |

## ✅ 部署检查清单

- [ ] 两台机器网络连通
- [ ] 两台机器都有 NVIDIA GPU
- [ ] 两台机器都有 nvidia-smi
- [ ] 配置文件已生成
- [ ] 模型已下载到 `/model` 目录
- [ ] Controller 进程已启动
- [ ] Worker 进程已启动
- [ ] 心跳文件已生成
- [ ] API 服务已启动
- [ ] 测试推理成功

## 💡 最佳实践

1. **首先运行 dry-run**：Controller 会输出诊断信息
2. **监控日志**：使用 `tail -f` 实时查看错误
3. **检查心跳**：确保 Worker 连接正常
4. **渐进式扩展**：先验证 2 节点，再添加更多节点
5. **定期备份**：保存成功的配置

## 📞 获得帮助

- 查看详细指南：`config/clusters/2node_deployment/DEPLOYMENT_GUIDE.md`
- 项目文档：`/Users/shuwen/shuwen/neurx/README.md`
- GitHub Issues：https://github.com/shuwenhe/neurx/issues

---

**准备好了？开始部署！** 🚀

