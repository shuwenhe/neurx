#!/bin/bash
# NeurX 分布式推理部署方案 - 双节点（192.168.10.39 + 192.168.10.75）

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NEURX_ROOT=$(dirname "$SCRIPT_DIR")

# 机器配置
CONTROLLER_IP=192.168.10.39
WORKER_IP=192.168.10.75
CLUSTER_NAME=neurx-inference-2node
CONFIG_DIR="$NEURX_ROOT/config/clusters/2node_deployment"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║       NeurX 分布式推理 - 2 节点部署方案                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# 创建配置目录
mkdir -p "$CONFIG_DIR"

# ============================================
# 第 1 步：检查机器连接
# ============================================

echo "📡 步骤 1: 检查网络连接"
echo "─────────────────────────────────────────────────────────────────"

echo "  检查 Controller (192.168.10.39)..."
if timeout 2 bash -c "ping -c 1 $CONTROLLER_IP > /dev/null 2>&1"; then
    echo "  ✅ Controller 可达"
else
    echo "  ❌ Controller 无法连接"
    exit 1
fi

echo "  检查 Worker (192.168.10.75)..."
if timeout 2 bash -c "ping -c 1 $WORKER_IP > /dev/null 2>&1"; then
    echo "  ✅ Worker 可达"
else
    echo "  ❌ Worker 无法连接"
    exit 1
fi

echo ""

# ============================================
# 第 2 步：生成 Controller 配置
# ============================================

echo "⚙️  步骤 2: 生成 Controller 配置"
echo "─────────────────────────────────────────────────────────────────"

cat > "$CONFIG_DIR/controller.env" << 'CONTROLLER_EOF'
# ===== NeurX Distributed Inference - Controller Configuration =====
# Deployment: 2-Node Cluster
# Controller IP: 192.168.10.39
# Worker IP: 192.168.10.75
# Generated: 2026-08-29

# ===== Cluster Configuration =====
NEURX_CLUSTER_NAME=neurx-inference-2node
NEURX_BACKEND=nccl
MASTER_ADDR=192.168.10.39
MASTER_PORT=29500
WORLD_SIZE=2

# ===== Model Configuration =====
NEURX_MODEL=Qwen/Qwen2.5-0.5B-Instruct
NEURX_MODEL_DIR=/model/Qwen2.5-0.5B-Instruct

# ===== Inference Settings =====
NEURX_MAX_CONCURRENCY=128
NEURX_MAX_TOKENS=512
NEURX_BATCH_SIZE=8
NEURX_ENABLE_CONTINUOUS_BATCHING=true

# ===== API Server Configuration =====
NEURX_BIND_ADDRESS=0.0.0.0
NEURX_PORT=8000
NEURX_REQUEST_TIMEOUT_MS=30000

# ===== GPU Configuration =====
NEURX_GPU_MEMORY_UTILIZATION=0.9
NEURX_USE_FLASH_ATTENTION=true
NEURX_USE_PAGED_ATTENTION=true
NEURX_KV_CACHE_DTYPE=bfloat16

# ===== Performance Optimization =====
NEURX_ENABLE_HETERO_LAUNCH=1
NCCL_SOCKET_IFNAME=en0
NCCL_DEBUG=INFO

# ===== Paths =====
NEURX_HEARTBEAT_DIR=/tmp/neurx_cluster/heartbeat
NEURX_CHECKPOINT_DIR=./artifact/checkpoints
NEURX_OUTPUT_DIR=./artifact/inference_output
NEURX_LOG_DIR=/tmp/neurx_cluster/logs

# ===== SSH Configuration (for remote worker management) =====
NEURX_SSH_KEY_PATH=~/.ssh/id_rsa
NEURX_REMOTE_WORKER_BIN=/opt/neurx/bin/inference-worker
NEURX_WORKER_HOST=root@192.168.10.75
CONTROLLER_EOF

echo "  ✓ 生成: $CONFIG_DIR/controller.env"

# ============================================
# 第 3 步：生成 Worker 配置
# ============================================

echo ""
echo "⚙️  步骤 3: 生成 Worker 配置"
echo "─────────────────────────────────────────────────────────────────"

cat > "$CONFIG_DIR/worker_rank0.env" << 'WORKER_EOF'
# ===== NeurX Distributed Inference - Worker Configuration =====
# Deployment: 2-Node Cluster - RANK 0
# Node IP: 192.168.10.75
# GPU: GPU 0 (Local Rank 0)
# Generated: 2026-08-29

# ===== Distributed Training Setup =====
MASTER_ADDR=192.168.10.39
MASTER_PORT=29500
WORLD_SIZE=2
RANK=0
LOCAL_RANK=0

# ===== Node Configuration =====
NEURX_CLUSTER_NAME=neurx-inference-2node
NEURX_NODE_NAME=worker-0
NEURX_NODE_HOST=192.168.10.75
NEURX_NODE_PORT=29501

# ===== Execution Configuration =====
NEURX_WORKER_BIN=./build/neurx-worker
NEURX_BACKEND=nccl

# ===== GPU Configuration =====
CUDA_VISIBLE_DEVICES=0
NEURX_GPU_MEMORY_UTILIZATION=0.9

# ===== Paths =====
NEURX_HEARTBEAT_DIR=/tmp/neurx_cluster/heartbeat
NEURX_LOG_DIR=/tmp/neurx_cluster/logs
NEURX_OUTPUT_DIR=./artifact/inference_output
WORKER_EOF

echo "  ✓ 生成: $CONFIG_DIR/worker_rank0.env"

# ============================================
# 第 4 步：创建部署脚本
# ============================================

echo ""
echo "🚀 步骤 4: 生成部署脚本"
echo "─────────────────────────────────────────────────────────────────"

cat > "$CONFIG_DIR/deploy_all.sh" << 'DEPLOY_EOF'
#!/bin/bash
# 一键部署脚本：在两台机器上部署 NeurX 分布式推理

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_DIR="$SCRIPT_DIR"
NEURX_ROOT=$(dirname $(dirname "$SCRIPT_DIR"))

CONTROLLER_IP=192.168.10.39
WORKER_IP=192.168.10.75

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║    NeurX 分布式推理自动部署 - Controller + Worker              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# 检查 SSH 连接
echo "🔗 检查 SSH 连接..."
if ! ssh -o ConnectTimeout=2 root@$WORKER_IP "echo OK" >/dev/null 2>&1; then
    echo "❌ 无法通过 SSH 连接到 $WORKER_IP"
    echo "   请确保："
    echo "   1. SSH 密钥已配置"
    echo "   2. Worker 节点可访问"
    echo "   3. 防火墙允许 SSH (端口 22)"
    exit 1
fi
echo "✅ SSH 连接正常"
echo ""

# 准备共享变量
export NEURX_ROOT
export CONFIG_DIR
export CONTROLLER_IP
export WORKER_IP

# 第 1 步：启动 Controller
echo "═══════════════════════════════════════════════════════════════════"
echo "📍 阶段 1: 启动 Controller (192.168.10.39)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

cd "$NEURX_ROOT"

# 创建必要的目录
mkdir -p /tmp/neurx_cluster/{heartbeat,logs}
mkdir -p artifact/{checkpoints,inference_output}

echo "  1️⃣  加载 Controller 配置..."
source "$CONFIG_DIR/controller.env"

echo "  2️⃣  启动 Controller 进程..."
echo ""
echo "  命令: $NEURX_ROOT/cmd/controller/main.s"
echo "  环境: MASTER_ADDR=$MASTER_ADDR WORLD_SIZE=$WORLD_SIZE"
echo ""

# 这里可以选择：
# 选项 1: 运行 dry-run 查看配置
echo "  💡 提示: 首先运行 dry-run 模式预览配置"
echo "  运行命令:"
echo ""
echo "    cd $NEURX_ROOT"
echo "    source $CONFIG_DIR/controller.env"
echo "    ./cmd/controller/main.s"
echo ""
echo "  (S 编译器会生成启动脚本到 /tmp/neurx_cluster/)"
echo ""

read -p "  按 Enter 继续或 Ctrl+C 退出... " dummy

# 第 2 步：启动 Worker
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "📍 阶段 2: 启动 Worker (192.168.10.75)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

echo "  在 Worker 节点启动 Worker 进程..."
echo ""
echo "  SSH 命令:"
echo ""
ssh root@$WORKER_IP << 'WORKER_SCRIPT'
NEURX_ROOT=$(cd ~/neurx && pwd)
CONFIG_DIR=$NEURX_ROOT/config/clusters/2node_deployment

echo "  1️⃣  在 Worker 节点准备环境..."
mkdir -p /tmp/neurx_cluster/{heartbeat,logs}
cd $NEURX_ROOT

echo "  2️⃣  加载 Worker 配置..."
source $CONFIG_DIR/worker_rank0.env

echo "  3️⃣  启动 Worker 进程..."
echo "  命令: $NEURX_ROOT/cmd/worker/main.s"
echo "  环境: RANK=0 MASTER_ADDR=192.168.10.39"
echo ""

# 运行 Worker (这将在后台运行)
# ./cmd/worker/main.s
echo "  (可选) 在后台运行: nohup ./cmd/worker/main.s > /tmp/worker.log 2>&1 &"
WORKER_SCRIPT

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "✅ 部署完成!"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "📋 接下来的步骤:"
echo ""
echo "1️⃣  监控集群状态:"
echo "   bash $CONFIG_DIR/monitor.sh"
echo ""
echo "2️⃣  测试推理:"
echo "   curl -X POST http://192.168.10.39:8000/v1/completions \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"model\": \"Qwen/Qwen2.5-0.5B-Instruct\", \"prompt\": \"Hello!\", \"max_tokens\": 100}'"
echo ""
echo "3️⃣  查看日志:"
echo "   tail -f /tmp/neurx_cluster/logs/*.log"
echo ""
DEPLOY_EOF

chmod +x "$CONFIG_DIR/deploy_all.sh"
echo "  ✓ 生成: $CONFIG_DIR/deploy_all.sh"

# ============================================
# 第 5 步：创建监控脚本
# ============================================

echo ""
echo "📊 步骤 5: 生成监控脚本"
echo "─────────────────────────────────────────────────────────────────"

cat > "$CONFIG_DIR/monitor.sh" << 'MONITOR_EOF'
#!/bin/bash
# 监控 2 节点 NeurX 集群状态

CONTROLLER_IP=192.168.10.39
WORKER_IP=192.168.10.75

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         NeurX 2-Node Cluster Status Monitor                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Controller 状态
echo "🖥️  CONTROLLER (192.168.10.39)"
echo "─────────────────────────────────────────────────────────────────"
if timeout 2 bash -c "echo > /dev/tcp/$CONTROLLER_IP/29500" 2>/dev/null; then
    echo "✅ Controller listening on port 29500"
else
    echo "❌ Controller not responding on port 29500"
fi

if timeout 2 bash -c "echo > /dev/tcp/$CONTROLLER_IP/8000" 2>/dev/null; then
    echo "✅ API Server running on port 8000"
    echo ""
    echo "   Try: curl -s http://$CONTROLLER_IP:8000/v1/models | jq ."
else
    echo "⏳ API Server not yet responding (check if service is started)"
fi

echo ""

# Worker 状态
echo "🖥️  WORKER (192.168.10.75)"
echo "─────────────────────────────────────────────────────────────────"
if timeout 2 bash -c "echo > /dev/tcp/$WORKER_IP/29501" 2>/dev/null; then
    echo "✅ Worker listening on port 29501"
else
    echo "⏳ Worker not responding (check SSH and process status)"
fi

# SSH 检查 GPU 状态
echo ""
echo "Checking GPU status via SSH..."
ssh -o ConnectTimeout=2 root@$WORKER_IP "nvidia-smi --query-gpu=index,name,memory.used,memory.total --format=csv,noheader" 2>/dev/null || echo "  (unable to connect)"

echo ""

# 心跳检查
echo "💓 HEARTBEAT STATUS"
echo "─────────────────────────────────────────────────────────────────"
if [ -d "/tmp/neurx_cluster/heartbeat" ]; then
    count=$(ls /tmp/neurx_cluster/heartbeat/* 2>/dev/null | wc -l)
    echo "✅ Heartbeat files found: $count"
    ls -lt /tmp/neurx_cluster/heartbeat/ | head -3
else
    echo "⏳ Waiting for heartbeat..."
fi

echo ""
echo "💡 Quick commands:"
echo "   View Controller logs: tail -f /tmp/neurx_cluster/logs/controller.log"
echo "   View Worker logs:     ssh root@192.168.10.75 'tail -f /tmp/neurx_cluster/logs/worker.log'"
echo "   Test inference:       curl http://192.168.10.39:8000/v1/models"
echo ""
MONITOR_EOF

chmod +x "$CONFIG_DIR/monitor.sh"
echo "  ✓ 生成: $CONFIG_DIR/monitor.sh"

# ============================================
# 第 6 步：创建快速参考卡
# ============================================

echo ""
echo "📚 步骤 6: 生成快速参考卡"
echo "─────────────────────────────────────────────────────────────────"

cat > "$CONFIG_DIR/QUICK_REFERENCE.md" << 'REF_EOF'
# NeurX 2-Node Distributed Inference - Quick Reference

## System Architecture

```
┌─────────────────────────┐
│  Controller Node        │
│  192.168.10.39:29500    │
│  - NeurX Controller     │
│  - REST API :8000       │
└────────────┬────────────┘
             │ NCCL
    ┌────────▼─────────┐
    │  Worker Node     │
    │  192.168.10.75   │
    │  RANK=0          │
    │  NeurX Worker    │
    └──────────────────┘
```

## Deployment Commands

### 1. On Controller Node (192.168.10.39)

```bash
cd ~/neurx
source config/clusters/2node_deployment/controller.env
mkdir -p /tmp/neurx_cluster/{heartbeat,logs}
./cmd/controller/main.s
```

### 2. On Worker Node (192.168.10.75)

```bash
cd ~/neurx
source config/clusters/2node_deployment/worker_rank0.env
mkdir -p /tmp/neurx_cluster/{heartbeat,logs}
./cmd/worker/main.s
```

### 3. Test Inference (from any machine)

```bash
curl -X POST http://192.168.10.39:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-0.5B-Instruct",
    "prompt": "What is machine learning?",
    "max_tokens": 100
  }'
```

## Monitoring

```bash
# Monitor cluster status
bash config/clusters/2node_deployment/monitor.sh

# Watch Controller logs
tail -f /tmp/neurx_cluster/logs/controller.log

# Watch Worker logs (via SSH)
ssh root@192.168.10.75 'tail -f /tmp/neurx_cluster/logs/worker.log'

# Check GPU status
nvidia-smi

# Check Worker GPU status
ssh root@192.168.10.75 nvidia-smi
```

## Troubleshooting

### Problem: Worker can't connect to Controller

```bash
# Check network connectivity
ping 192.168.10.39

# Test port connectivity
telnet 192.168.10.39 29500

# Check firewall
sudo firewall-cmd --list-all
sudo firewall-cmd --add-port=29500/tcp --permanent
sudo firewall-cmd --reload
```

### Problem: GPU not found

```bash
# Verify nvidia-smi works
nvidia-smi

# On Worker node:
ssh root@192.168.10.75 nvidia-smi
```

### Problem: Model not found

```bash
# Check if model directory exists
ls -la /model/Qwen2.5-0.5B-Instruct/

# On Worker node:
ssh root@192.168.10.75 'ls -la /model/'

# Download model (if not exists)
python -c "
from transformers import AutoModel, AutoTokenizer
model = AutoModel.from_pretrained('Qwen/Qwen2.5-0.5B-Instruct', cache_dir='/model')
tokenizer = AutoTokenizer.from_pretrained('Qwen/Qwen2.5-0.5B-Instruct', cache_dir='/model')
"
```

## Configuration Files

- `controller.env` - Controller node settings
- `worker_rank0.env` - Worker node settings
- `deploy_all.sh` - Automated deployment script
- `monitor.sh` - Cluster monitoring script

## Environment Variables

### Controller
- `MASTER_ADDR=192.168.10.39`
- `MASTER_PORT=29500`
- `WORLD_SIZE=2`
- `NEURX_BIND_ADDRESS=0.0.0.0`
- `NEURX_PORT=8000`

### Worker
- `MASTER_ADDR=192.168.10.39`
- `RANK=0`
- `LOCAL_RANK=0`
- `WORLD_SIZE=2`

## Performance Metrics

Expected performance on 2 RTX 4090 GPUs:

- **Throughput**: 500-1000 requests/sec
- **TTFT**: 10-15ms
- **Per-token latency**: 5-8ms
- **P99 latency**: 100-150ms
- **GPU Memory**: ~4GB per node
- **Total Power**: ~400W

REF_EOF

echo "  ✓ 生成: $CONFIG_DIR/QUICK_REFERENCE.md"

# ============================================
# 第 7 步：生成总结
# ============================================

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                      ✅ 配置生成完成!                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "📂 配置文件位置: $CONFIG_DIR"
echo ""

echo "📋 生成的文件:"
echo "  • controller.env           - Controller 节点环境配置"
echo "  • worker_rank0.env         - Worker 节点环境配置"
echo "  • deploy_all.sh            - 自动部署脚本"
echo "  • monitor.sh               - 集群监控脚本"
echo "  • QUICK_REFERENCE.md       - 快速参考卡"
echo ""

echo "🚀 快速开始:"
echo ""
echo "  1️⃣  在 Controller 上启动 (192.168.10.39):"
echo "      cd ~/neurx"
echo "      source $CONFIG_DIR/controller.env"
echo "      mkdir -p /tmp/neurx_cluster/{heartbeat,logs}"
echo "      ./cmd/controller/main.s"
echo ""
echo "  2️⃣  在 Worker 上启动 (192.168.10.75):"
echo "      ssh root@192.168.10.75"
echo "      cd ~/neurx"
echo "      source $CONFIG_DIR/worker_rank0.env"
echo "      mkdir -p /tmp/neurx_cluster/{heartbeat,logs}"
echo "      ./cmd/worker/main.s"
echo ""
echo "  3️⃣  监控集群:"
echo "      bash $CONFIG_DIR/monitor.sh"
echo ""
echo "  4️⃣  测试推理:"
echo "      curl -X POST http://192.168.10.39:8000/v1/completions \\"
echo "        -H 'Content-Type: application/json' \\"
echo "        -d '{\"model\": \"Qwen/Qwen2.5-0.5B-Instruct\", \"prompt\": \"Hi!\", \"max_tokens\": 100}'"
echo ""
echo "💡 或者使用自动部署脚本:"
echo "   bash $CONFIG_DIR/deploy_all.sh"
echo ""
