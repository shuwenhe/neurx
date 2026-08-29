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

