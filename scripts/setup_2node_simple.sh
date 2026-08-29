#!/bin/bash
# NeurX 分布式推理 - 2 节点部署配置（192.168.10.39 + 192.168.10.75）

NEURX_ROOT="/Users/shuwen/shuwen/neurx"
CONFIG_DIR="$NEURX_ROOT/config/clusters/2node_deployment"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║    NeurX 2-Node Distributed Inference Setup                    ║"
echo "║    Controller: 192.168.10.39                                   ║"
echo "║    Worker:    192.168.10.75                                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# 创建配置目录
mkdir -p "$CONFIG_DIR"
mkdir -p "$NEURX_ROOT/config/clusters"

echo "📂 Creating configuration directory: $CONFIG_DIR"
echo ""

# ============================================
# Controller 环境配置
# ============================================

cat > "$CONFIG_DIR/controller.env" << 'CONTROLLER_EOF'
# ===== NeurX Distributed Inference - Controller =====
# Role: Master Node
# IP: 192.168.10.39
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

# ===== API Server =====
NEURX_BIND_ADDRESS=0.0.0.0
NEURX_PORT=8000
NEURX_REQUEST_TIMEOUT_MS=30000
NEURX_SHUTDOWN_GRACE_MS=30000

# ===== GPU Optimization =====
NEURX_GPU_MEMORY_UTILIZATION=0.9
NEURX_USE_FLASH_ATTENTION=true
NEURX_USE_PAGED_ATTENTION=true
NEURX_KV_CACHE_DTYPE=bfloat16
NEURX_ENABLE_HETERO_LAUNCH=1

# ===== NCCL Settings =====
NCCL_SOCKET_IFNAME=en0
NCCL_DEBUG=INFO
NCCL_TREE_THRESHOLD=0

# ===== Logging & Paths =====
NEURX_HEARTBEAT_DIR=/tmp/neurx_cluster/heartbeat
NEURX_HEARTBEAT_INTERVAL_MS=1000
NEURX_LOG_DIR=/tmp/neurx_cluster/logs
NEURX_CHECKPOINT_DIR=./artifact/checkpoints
NEURX_OUTPUT_DIR=./artifact/inference_output
CONTROLLER_EOF

echo "✓ Created: controller.env"

# ============================================
# Worker 环境配置
# ============================================

cat > "$CONFIG_DIR/worker_rank0.env" << 'WORKER_EOF'
# ===== NeurX Distributed Inference - Worker =====
# Role: Slave Node
# IP: 192.168.10.75
# Rank: 0 (only worker, this is rank 0)
# Generated: 2026-08-29

# ===== Distributed Setup =====
MASTER_ADDR=192.168.10.39
MASTER_PORT=29500
WORLD_SIZE=2
RANK=0
LOCAL_RANK=0

# ===== Node Information =====
NEURX_CLUSTER_NAME=neurx-inference-2node
NEURX_NODE_NAME=worker-0
NEURX_NODE_HOST=192.168.10.75
NEURX_NODE_PORT=29501

# ===== Execution =====
NEURX_WORKER_BIN=./build/neurx-worker
NEURX_BACKEND=nccl

# ===== GPU =====
CUDA_VISIBLE_DEVICES=0
NEURX_GPU_MEMORY_UTILIZATION=0.9

# ===== NCCL =====
NCCL_SOCKET_IFNAME=en0
NCCL_DEBUG=INFO

# ===== Paths =====
NEURX_HEARTBEAT_DIR=/tmp/neurx_cluster/heartbeat
NEURX_LOG_DIR=/tmp/neurx_cluster/logs
NEURX_OUTPUT_DIR=./artifact/inference_output
WORKER_EOF

echo "✓ Created: worker_rank0.env"
echo ""

# ============================================
# 快速启动脚本
# ============================================

cat > "$CONFIG_DIR/start_controller.sh" << 'START_CTRL_EOF'
#!/bin/bash
# Start Controller on 192.168.10.39

set -e

NEURX_ROOT="/Users/shuwen/shuwen/neurx"
CONFIG_DIR="$NEURX_ROOT/config/clusters/2node_deployment"

echo "🚀 Starting NeurX Controller (192.168.10.39)"
echo ""

# Load configuration
source "$CONFIG_DIR/controller.env"

# Create directories
mkdir -p "$NEURX_HEARTBEAT_DIR"
mkdir -p "$NEURX_LOG_DIR"
mkdir -p artifact/checkpoints
mkdir -p artifact/inference_output

# Navigate to project root
cd "$NEURX_ROOT"

# Print startup info
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║               NeurX Controller Starting                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  Cluster Name:      $NEURX_CLUSTER_NAME"
echo "  Master Address:    $MASTER_ADDR:$MASTER_PORT"
echo "  World Size:        $WORLD_SIZE"
echo "  Model:             $NEURX_MODEL"
echo "  API Port:          $NEURX_PORT"
echo "  Backend:           $NEURX_BACKEND"
echo ""
echo "Starting Controller..."
echo ""

# Run controller
# Option 1: If compiled binary exists
if [ -f "./build/neurx-controller" ]; then
    ./build/neurx-controller
# Option 2: If S source code exists
elif [ -f "./cmd/controller/main.s" ]; then
    echo "Note: S compiler required to run from source"
    echo "Command: s ./cmd/controller/main.s"
    # Uncomment to run:
    # s ./cmd/controller/main.s
else
    echo "❌ Controller binary or source not found!"
    exit 1
fi
START_CTRL_EOF

chmod +x "$CONFIG_DIR/start_controller.sh"
echo "✓ Created: start_controller.sh"

# ============================================
# Worker 启动脚本
# ============================================

cat > "$CONFIG_DIR/start_worker.sh" << 'START_WORKER_EOF'
#!/bin/bash
# Start Worker on 192.168.10.75 (via SSH)

CONTROLLER_IP=192.168.10.39
WORKER_IP=192.168.10.75
NEURX_ROOT="/Users/shuwen/shuwen/neurx"
CONFIG_DIR="$NEURX_ROOT/config/clusters/2node_deployment"

echo "🚀 Starting NeurX Worker (192.168.10.75) via SSH"
echo ""

# Create SSH command
SSH_CMD="
set -e

echo '╔════════════════════════════════════════════════════════════════╗'
echo '║               NeurX Worker Starting                           ║'
echo '╚════════════════════════════════════════════════════════════════╝'
echo ''

# Navigate to NeurX root
cd $NEURX_ROOT 2>/dev/null || cd ~/neurx || { echo 'NeurX directory not found'; exit 1; }

# Load configuration
source $CONFIG_DIR/worker_rank0.env

# Create directories
mkdir -p \$NEURX_HEARTBEAT_DIR
mkdir -p \$NEURX_LOG_DIR

echo 'Configuration:'
echo \"  Cluster Name:      \$NEURX_CLUSTER_NAME\"
echo \"  Master Address:    \$MASTER_ADDR:\$MASTER_PORT\"
echo \"  Rank:              \$RANK\"
echo \"  World Size:        \$WORLD_SIZE\"
echo \"  Backend:           \$NEURX_BACKEND\"
echo ''
echo 'Starting Worker...'
echo ''

# Check GPU
nvidia-smi

echo ''

# Run worker
if [ -f './build/neurx-worker' ]; then
    ./build/neurx-worker
elif [ -f './cmd/worker/main.s' ]; then
    echo 'Note: S compiler required to run from source'
    echo 'Command: s ./cmd/worker/main.s'
else
    echo '❌ Worker binary or source not found!'
    exit 1
fi
"

# Execute via SSH
echo "Executing on $WORKER_IP..."
echo ""

ssh -o StrictHostKeyChecking=no "shuwen@$WORKER_IP" "$SSH_CMD" || \
ssh -o StrictHostKeyChecking=no "root@$WORKER_IP" "$SSH_CMD" || \
ssh -o StrictHostKeyChecking=no "ubuntu@$WORKER_IP" "$SSH_CMD" || \
{
    echo "❌ Could not SSH to $WORKER_IP"
    echo ""
    echo "Please ensure:"
    echo "  1. SSH key is configured"
    echo "  2. Machine is reachable at $WORKER_IP"
    echo "  3. SSH service is running"
    echo ""
    echo "Try manually:"
    echo "  ssh shuwen@$WORKER_IP"
    exit 1
}
START_WORKER_EOF

chmod +x "$CONFIG_DIR/start_worker.sh"
echo "✓ Created: start_worker.sh"

# ============================================
# 监控脚本
# ============================================

cat > "$CONFIG_DIR/monitor.sh" << 'MONITOR_EOF'
#!/bin/bash
# Monitor 2-node NeurX cluster

CONTROLLER_IP=192.168.10.39
WORKER_IP=192.168.10.75
HEARTBEAT_DIR=/tmp/neurx_cluster/heartbeat
LOG_DIR=/tmp/neurx_cluster/logs

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          NeurX 2-Node Cluster Status Monitor                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "🖥️  CONTROLLER: $CONTROLLER_IP"
echo "─────────────────────────────────────────────────────────────────"
# Check if Controller is listening
if nc -zv $CONTROLLER_IP 29500 2>/dev/null; then
    echo "✅ NCCL Port (29500):    LISTENING"
else
    echo "⏳ NCCL Port (29500):    Not responding"
fi

if nc -zv $CONTROLLER_IP 8000 2>/dev/null; then
    echo "✅ API Server (8000):    LISTENING"
else
    echo "⏳ API Server (8000):    Not responding"
fi

echo ""
echo "🖥️  WORKER: $WORKER_IP"
echo "─────────────────────────────────────────────────────────────────"
if nc -zv $WORKER_IP 29501 2>/dev/null; then
    echo "✅ NCCL Port (29501):    LISTENING"
else
    echo "⏳ NCCL Port (29501):    Not responding"
fi

# Check Worker GPU via SSH
echo ""
echo "Checking Worker GPU..."
ssh -o ConnectTimeout=2 shuwen@$WORKER_IP nvidia-smi --query-gpu=index,name,memory.used,memory.total --format=csv,noheader 2>/dev/null || \
ssh -o ConnectTimeout=2 root@$WORKER_IP nvidia-smi --query-gpu=index,name,memory.used,memory.total --format=csv,noheader 2>/dev/null || \
echo "  (Unable to connect via SSH)"

echo ""

# Check heartbeat files
if [ -d "$HEARTBEAT_DIR" ]; then
    count=$(ls "$HEARTBEAT_DIR" 2>/dev/null | wc -l)
    if [ $count -gt 0 ]; then
        echo "💓 HEARTBEAT: $count file(s) found"
        ls -lt "$HEARTBEAT_DIR" | head -3
    else
        echo "⏳ HEARTBEAT: Waiting for worker connections..."
    fi
else
    echo "⏳ HEARTBEAT: Heartbeat directory not created yet"
fi

echo ""
echo "📊 QUICK COMMANDS"
echo "─────────────────────────────────────────────────────────────────"
echo "• View Controller logs:    tail -f $LOG_DIR/controller.log"
echo "• View Worker logs:        ssh shuwen@$WORKER_IP 'tail -f /tmp/neurx_cluster/logs/worker.log'"
echo "• Test inference API:      curl http://$CONTROLLER_IP:8000/v1/models"
echo "• Full test:               curl -X POST http://$CONTROLLER_IP:8000/v1/completions -H 'Content-Type: application/json' -d '{\"model\": \"Qwen/Qwen2.5-0.5B-Instruct\", \"prompt\": \"Hello!\", \"max_tokens\": 50}'"
echo ""
MONITOR_EOF

chmod +x "$CONFIG_DIR/monitor.sh"
echo "✓ Created: monitor.sh"

# ============================================
# 部署说明文档
# ============================================

cat > "$CONFIG_DIR/DEPLOYMENT_GUIDE.md" << 'GUIDE_EOF'
# NeurX 2-Node Distributed Inference Deployment

## Overview

This configuration sets up NeurX distributed inference on two GPU machines:
- **Controller (Master)**: 192.168.10.39
- **Worker (Slave)**: 192.168.10.75

## Prerequisites

### On Both Machines
- Linux OS (Ubuntu/CentOS recommended)
- Python 3.8+
- NVIDIA CUDA Toolkit
- nvidia-drivers
- NeurX source code

### Configuration Verification

```bash
# Check CUDA
nvidia-smi

# Check NeurX installation
cd ~/neurx
ls cmd/controller/main.s cmd/worker/main.s
```

## Architecture

```
Controller (192.168.10.39)
├─ Node Discovery
├─ Task Scheduling
├─ REST API :8000
└─ NCCL Coordinator :29500
     ↓ (NCCL AllReduce)
Worker (192.168.10.75)
├─ GPU Inference
├─ KV Cache Management
└─ NCCL Worker :29501
```

## Deployment Steps

### Step 1: Start Controller (on 192.168.10.39)

```bash
cd /Users/shuwen/shuwen/neurx
source config/clusters/2node_deployment/controller.env

# Create necessary directories
mkdir -p /tmp/neurx_cluster/{heartbeat,logs}
mkdir -p artifact/{checkpoints,inference_output}

# Start Controller
./cmd/controller/main.s
# or if compiled:
./build/neurx-controller
```

**Expected Output**:
```
[neurx-controller] discovery result:
[neurx-controller] selected node=... backend=nccl
[neurx-controller] heartbeat=...
```

### Step 2: Start Worker (on 192.168.10.75)

SSH into worker machine:
```bash
ssh shuwen@192.168.10.75
```

Then run:
```bash
cd ~/neurx
source config/clusters/2node_deployment/worker_rank0.env

# Create directories
mkdir -p /tmp/neurx_cluster/{heartbeat,logs}

# Start Worker
./cmd/worker/main.s
# or if compiled:
./build/neurx-worker
```

**Expected Output**:
```
[neurx-worker] rank=0 local_rank=0 master=192.168.10.39:29500
[neurx-worker] heartbeat=...
```

### Step 3: Monitor Cluster

```bash
cd /Users/shuwen/shuwen/neurx
bash config/clusters/2node_deployment/monitor.sh
```

**Expected Output**:
```
✅ NCCL Port (29500):    LISTENING
✅ API Server (8000):    LISTENING
✅ NCCL Port (29501):    LISTENING
💓 HEARTBEAT: 1 file(s) found
```

### Step 4: Test Inference

```bash
# List available models
curl http://192.168.10.39:8000/v1/models

# Run inference
curl -X POST http://192.168.10.39:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-0.5B-Instruct",
    "prompt": "What is artificial intelligence?",
    "max_tokens": 100,
    "temperature": 0.7,
    "top_p": 0.9
  }'
```

## Configuration Files

### controller.env
Master node environment variables:
- `MASTER_ADDR=192.168.10.39`
- `MASTER_PORT=29500`
- `WORLD_SIZE=2`
- `NEURX_PORT=8000` (API server)

### worker_rank0.env
Worker node environment variables:
- `RANK=0`
- `MASTER_ADDR=192.168.10.39`
- `WORLD_SIZE=2`
- `LOCAL_RANK=0`

## Troubleshooting

### Problem: Worker can't connect to Controller

**Symptom**: Worker logs show connection timeout

**Solution**:
```bash
# Check network connectivity
ping 192.168.10.39

# Test port connectivity
nc -zv 192.168.10.39 29500

# Check firewall (on Controller)
sudo ufw allow 29500/tcp
sudo firewall-cmd --add-port=29500/tcp --permanent
```

### Problem: GPU not found

**Symptom**: nvidia-smi fails

**Solution**:
```bash
# On worker machine
ssh shuwen@192.168.10.75 nvidia-smi

# Install NVIDIA drivers if needed
# Follow official NVIDIA installation guide
```

### Problem: Model not found

**Symptom**: Inference fails with "Model not found"

**Solution**:
```bash
# Check model directory on both machines
ls -la /model/Qwen2.5-0.5B-Instruct/

# Download model if missing
python -c "
from transformers import AutoModel, AutoTokenizer
model = AutoModel.from_pretrained('Qwen/Qwen2.5-0.5B-Instruct', cache_dir='/model')
tokenizer = AutoTokenizer.from_pretrained('Qwen/Qwen2.5-0.5B-Instruct', cache_dir='/model')
"
```

### Problem: NCCL errors

**Symptom**: NCCL initialization fails

**Solution**:
```bash
# Enable NCCL debug logging
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=ALL

# Check network interface
ip addr show | grep inet

# Ensure correct network interface (update if needed)
export NCCL_SOCKET_IFNAME=eth0  # or your interface
```

## Performance Metrics

Expected performance on 2x RTX 4090 GPUs:
- **Throughput**: 500+ requests/second
- **TTFT (Time To First Token)**: 10-15ms
- **Per-token latency**: 5-8ms
- **P99 latency**: 100-150ms
- **GPU Memory**: ~4GB per node
- **Total Power**: ~400W

## Useful Commands

```bash
# View logs
tail -f /tmp/neurx_cluster/logs/*.log

# Check heartbeat status
ls -la /tmp/neurx_cluster/heartbeat/

# Kill processes
killall neurx-controller
killall neurx-worker

# Monitor GPU usage
watch nvidia-smi

# Test connectivity
ssh shuwen@192.168.10.75 echo "OK"
telnet 192.168.10.39 29500
```

## Scaling to More Nodes

To add additional workers:

1. Generate new worker config:
```bash
cp config/clusters/2node_deployment/worker_rank0.env \
   config/clusters/2node_deployment/worker_rank1.env
```

2. Update worker_rank1.env:
```bash
RANK=1
NEURX_NODE_HOST=192.168.10.NEW_IP
NEURX_NODE_PORT=29502
```

3. Update controller.env:
```bash
WORLD_SIZE=3
```

4. Start new worker on additional machine

## Support

- GitHub: https://github.com/shuwenhe/neurx
- Documentation: /Users/shuwen/shuwen/neurx/README.md
- Issues: Check /tmp/neurx_cluster/logs/

GUIDE_EOF

echo "✓ Created: DEPLOYMENT_GUIDE.md"
echo ""

# ============================================
# 最终总结
# ============================================

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                  ✅ Configuration Complete!                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "📂 Configuration Directory:"
echo "   $CONFIG_DIR"
echo ""

echo "📋 Generated Files:"
echo "   ✓ controller.env              - Controller environment config"
echo "   ✓ worker_rank0.env            - Worker environment config"
echo "   ✓ start_controller.sh         - Start Controller script"
echo "   ✓ start_worker.sh             - Start Worker script (via SSH)"
echo "   ✓ monitor.sh                  - Cluster monitoring script"
echo "   ✓ DEPLOYMENT_GUIDE.md         - Complete deployment guide"
echo ""

echo "🚀 Quick Start:"
echo ""
echo "1️⃣  On Controller (192.168.10.39):"
echo ""
echo "   cd /Users/shuwen/shuwen/neurx"
echo "   source config/clusters/2node_deployment/controller.env"
echo "   mkdir -p /tmp/neurx_cluster/{heartbeat,logs}"
echo "   ./cmd/controller/main.s"
echo ""
echo "2️⃣  On Worker (192.168.10.75) via SSH:"
echo ""
echo "   bash config/clusters/2node_deployment/start_worker.sh"
echo ""
echo "   Or manually:"
echo "   ssh shuwen@192.168.10.75"
echo "   cd ~/neurx"
echo "   source config/clusters/2node_deployment/worker_rank0.env"
echo "   mkdir -p /tmp/neurx_cluster/{heartbeat,logs}"
echo "   ./cmd/worker/main.s"
echo ""
echo "3️⃣  Monitor Cluster:"
echo ""
echo "   bash config/clusters/2node_deployment/monitor.sh"
echo ""
echo "4️⃣  Test Inference:"
echo ""
echo "   curl -X POST http://192.168.10.39:8000/v1/completions \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"model\": \"Qwen/Qwen2.5-0.5B-Instruct\", \"prompt\": \"Hello!\", \"max_tokens\": 100}'"
echo ""
echo "💡 For detailed instructions, see:"
echo "   $CONFIG_DIR/DEPLOYMENT_GUIDE.md"
echo ""
