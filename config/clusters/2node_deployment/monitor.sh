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
