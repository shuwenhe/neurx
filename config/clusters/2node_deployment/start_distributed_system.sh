#!/bin/bash
# NeurX 分布式推理系统启动脚本
# 启动 Controller 和 Worker 推理服务

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(dirname $(dirname $(dirname "$SCRIPT_DIR")))"

echo "════════════════════════════════════════════════════════════════"
echo "🚀 NeurX 分布式推理系统启动"
echo "════════════════════════════════════════════════════════════════"
echo ""

echo "📊 系统状态检查："
echo ""

# 检查 Controller
echo "1️⃣  Controller (192.168.10.39:8000)"
if sshpass -p "shuwen" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 \
   shuwen@192.168.10.39 "ps aux | grep 'python3.*neurx_inference' | grep -v grep >/dev/null" 2>&1; then
    echo "   ✅ 推理服务运行中"
else
    echo "   ❌ 推理服务未运行 - 正在启动..."
    sshpass -p "shuwen" ssh -o StrictHostKeyChecking=no shuwen@192.168.10.39 \
        "cd /neurx/config/clusters/2node_deployment && nohup bash start_inference_prod.sh > controller_inference.log 2>&1 &" 2>&1
    sleep 3
    echo "   ✓ 启动命令已执行"
fi

echo ""
echo "2️⃣  Worker (192.168.10.75:8000)"
if sshpass -p "shuwen" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 \
   shuwen@192.168.10.75 "ps aux | grep 'python3.*neurx_inference' | grep -v grep >/dev/null" 2>&1; then
    echo "   ✅ 推理服务运行中"
else
    echo "   ❌ 推理服务未运行 - 请按照以下步骤手动启动："
    echo ""
    echo "   📋 手动启动步骤："
    echo "      1. ssh shuwen@192.168.10.75"
    echo "      2. cd /neurx/config/clusters/2node_deployment"
    echo "      3. export NEURX_ROLE=worker NEURX_PORT=8000 WORLD_SIZE=2 RANK=1"
    echo "      4. nohup python3 neurx_inference_gpu_ready.py > worker_inference.log 2>&1 &"
    echo "      5. ps aux | grep neurx_inference"
    echo ""
    echo "   或者，请在 Worker 节点上执行："
    echo "      bash $SCRIPT_DIR/start_worker_inference.sh"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ 启动脚本执行完成"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "📡 Web UI 访问: http://127.0.0.1:8081"
echo "🔌 推理 API:   http://127.0.0.1:8000"
echo "📊 更多信息:   cat WORKER_STARTUP_INSTRUCTIONS.md"
echo ""

