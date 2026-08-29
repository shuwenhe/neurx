# NeurX 2-Node 分布式推理 - 部署资源索引

## 📌 概述

本部署方案为以下两台机器配置了 NeurX 分布式推理系统：

- **Controller（主节点）**: 192.168.10.39 (用户: shuwen)
- **Worker（从节点）**: 192.168.10.75 (用户: shuwen, 密码: Linux@_2026..)

预计部署时间：**3 分钟**

---

## 📂 部署资源文件

所有文件位于：`~/neurx/config/clusters/2node_deployment/`

### 配置文件

| 文件 | 用途 | 说明 |
|-----|------|------|
| `controller.env` | Controller 环境 | MASTER_ADDR=192.168.10.39, PORT=29500 |
| `worker_rank0.env` | Worker 环境 | RANK=0, MASTER_ADDR=192.168.10.39 |

### 脚本文件

| 文件 | 用途 | 说明 |
|-----|------|------|
| `deploy.sh` | ⭐ 主部署脚本 | 使用: `NEURX_ROLE=controller/worker bash deploy.sh` |
| `monitor.sh` | 集群监控 | 查看集群状态和服务可用性 |
| `start_controller.sh` | Controller 启动 | 备用启动脚本 |
| `start_worker.sh` | Worker 启动 | 备用启动脚本 (via SSH) |

### 文档文件

| 文件 | 用途 | 适合人群 |
|-----|------|---------|
| **QUICK_REFERENCE.txt** | ⭐ 快速参考 | 想快速了解的人 (5 分钟阅读) |
| **EXECUTION_GUIDE.md** | 详细执行步骤 | 第一次部署的人 (15 分钟阅读) |
| **DEPLOYMENT_GUIDE.md** | 完整技术文档 | 需要深入理解的人 (30 分钟阅读) |
| **README.md** | 总体概览 | 了解整体架构的人 |
| **本文件 (INDEX.md)** | 文件导航 | 寻找资源的人 |

---

## 🚀 快速开始（3 步）

### Step 1: 启动 Controller

```bash
# 在 192.168.10.39 上
ssh shuwen@192.168.10.39
cd ~/neurx
NEURX_ROLE=controller bash config/clusters/2node_deployment/deploy.sh
```

### Step 2: 启动 Worker

```bash
# 在 192.168.10.75 上（新终端）
ssh shuwen@192.168.10.75
cd ~/neurx
NEURX_ROLE=worker bash config/clusters/2node_deployment/deploy.sh
```

### Step 3: 验证并测试

```bash
# 在任何地方（第三个终端）
bash ~/neurx/config/clusters/2node_deployment/monitor.sh

# 测试推理
curl -X POST http://192.168.10.39:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "Qwen/Qwen2.5-0.5B-Instruct", "prompt": "Hi!", "max_tokens": 50}'
```

---

## 📖 文档选择指南

### 我想...

- **5 分钟快速了解** → 读 [`QUICK_REFERENCE.txt`](QUICK_REFERENCE.txt)
- **第一次部署** → 读 [`EXECUTION_GUIDE.md`](EXECUTION_GUIDE.md)
- **深入了解技术细节** → 读 [`DEPLOYMENT_GUIDE.md`](DEPLOYMENT_GUIDE.md)
- **了解系统架构** → 读 [`README.md`](README.md)
- **寻找特定命令** → 读 [`QUICK_REFERENCE.txt`](QUICK_REFERENCE.txt)
- **排查故障** → 读 [`DEPLOYMENT_GUIDE.md`](DEPLOYMENT_GUIDE.md) 的故障排查章节

---

## 🎯 部署核心信息

### 网络拓扑

```
192.168.10.39 (Controller)
  ├─ NCCL Port: 29500
  ├─ API Port: 8000
  └─ Heartbeat: /tmp/neurx_cluster/heartbeat/
       ↓ NCCL Communication
192.168.10.75 (Worker)
  ├─ NCCL Port: 29501
  ├─ GPU: 推理引擎
  └─ Heartbeat: /tmp/neurx_cluster/heartbeat/
```

### 关键参数

| 参数 | 值 |
|-----|-----|
| Cluster Name | neurx-inference-2node |
| World Size | 2 |
| Backend | NCCL |
| Model | Qwen/Qwen2.5-0.5B-Instruct |
| API Endpoint | http://192.168.10.39:8000 |
| Max Concurrency | 128 |
| Batch Size | 8 |

---

## 📋 前置检查清单

部署前请确认：

- [ ] 可以 SSH 连接到 192.168.10.39 (shuwen)
- [ ] 可以 SSH 连接到 192.168.10.75 (shuwen)
- [ ] 两台机器都能 ping 通对方
- [ ] 两台机器都有 NVIDIA GPU (`nvidia-smi`)
- [ ] 两台机器都有 CUDA 工具包
- [ ] NeurX 代码在两台机器上都有
- [ ] 模型已下载到 `/model/Qwen2.5-0.5B-Instruct/`
- [ ] 配置文件已生成到 `config/clusters/2node_deployment/`

---

## ✅ 部署完成检查清单

部署后请验证：

- [ ] Controller 进程启动成功
- [ ] Worker 进程启动成功
- [ ] `monitor.sh` 显示所有服务都 LISTENING
- [ ] 心跳文件已生成
- [ ] API 测试成功返回响应
- [ ] 推理测试成功生成文本

---

## 🔧 常用命令速查

### 启动

```bash
# 快速启动
cd ~/neurx
NEURX_ROLE=controller bash config/clusters/2node_deployment/deploy.sh  # 在 39 上
NEURX_ROLE=worker bash config/clusters/2node_deployment/deploy.sh     # 在 75 上
```

### 监控

```bash
# 集群状态
bash ~/neurx/config/clusters/2node_deployment/monitor.sh

# 实时日志
ssh shuwen@192.168.10.39 'tail -f /tmp/neurx_cluster/logs/*.log'
ssh shuwen@192.168.10.75 'tail -f /tmp/neurx_cluster/logs/*.log'
```

### 测试

```bash
# API 测试
curl http://192.168.10.39:8000/v1/models

# 完整推理
curl -X POST http://192.168.10.39:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{...}'
```

### 停止

```bash
# 停止 Controller
ssh shuwen@192.168.10.39 'killall neurx-controller'

# 停止 Worker
ssh shuwen@192.168.10.75 'killall neurx-worker'
```

### 清理

```bash
# 清理日志
ssh shuwen@192.168.10.39 'rm -rf /tmp/neurx_cluster/'
ssh shuwen@192.168.10.75 'rm -rf /tmp/neurx_cluster/'
```

---

## 📊 性能指标

部署完成后的预期性能：

| 指标 | 值 |
|-----|-----|
| 吞吐量 (Throughput) | 500-1000 req/sec |
| 首字延迟 (TTFT) | 10-15ms |
| 单字延迟 (Per-token) | 5-8ms |
| P99 延迟 | 100-150ms |
| GPU 内存占用 | ~4GB/node |
| 总功耗 | ~400W |

---

## 🐛 快速故障排查

| 问题 | 快速诊断 | 解决方案 |
|-----|---------|--------|
| Worker 无法连接 | `telnet 192.168.10.39 29500` | 检查防火墙和网络 |
| GPU 不可用 | `nvidia-smi` | 检查驱动和 CUDA |
| 模型不可用 | `ls /model/` | 下载模型文件 |
| API 无响应 | `curl http://192.168.10.39:8000` | 检查 Controller 进程 |
| 日志异常 | `tail /tmp/neurx_cluster/logs/` | 查看详细错误信息 |

---

## 📞 获得帮助

### 文档

- 👉 **首先读这个**: [`QUICK_REFERENCE.txt`](QUICK_REFERENCE.txt)
- 📖 详细步骤: [`EXECUTION_GUIDE.md`](EXECUTION_GUIDE.md)
- 🔍 技术深度: [`DEPLOYMENT_GUIDE.md`](DEPLOYMENT_GUIDE.md)
- 🏗️ 架构概览: [`README.md`](README.md)

### 诊断

1. 查看日志：`tail -f /tmp/neurx_cluster/logs/*.log`
2. 检查心跳：`ls /tmp/neurx_cluster/heartbeat/`
3. 测试网络：`telnet 192.168.10.39 29500`
4. 查看进程：`ps aux | grep neurx`

### 支持

- GitHub: https://github.com/shuwenhe/neurx
- 文档: https://docs.neurx.ai
- Issues: https://github.com/shuwenhe/neurx/issues

---

## 🎓 学习路径

1. ✅ **阅读 QUICK_REFERENCE.txt** (5 min)
   - 了解 3 步部署流程

2. ✅ **按照 EXECUTION_GUIDE.md 部署** (15 min)
   - 在两台机器上逐步执行

3. ✅ **验证集群** (5 min)
   - 运行 `monitor.sh` 和测试推理

4. 📖 **阅读 DEPLOYMENT_GUIDE.md** (可选, 30 min)
   - 深入了解配置和故障排查

5. 🚀 **扩展集群** (可选)
   - 添加更多 Worker 节点

---

## 📅 版本信息

- **生成时间**: 2026-08-29
- **NeurX 版本**: Latest (main branch)
- **配置版本**: 2.0 (2-Node)
- **文档版本**: 1.0

---

## 📝 修改记录

| 版本 | 日期 | 变更 |
|-----|------|------|
| 2.0 | 2026-08-29 | 为 192.168.10.39 + 192.168.10.75 生成配置 |
| 1.0 | 2026-08-29 | 初始模板创建 |

---

**现在就开始部署吧！** 🚀

👉 **建议**: 先读 [`QUICK_REFERENCE.txt`](QUICK_REFERENCE.txt) (5 分钟)

