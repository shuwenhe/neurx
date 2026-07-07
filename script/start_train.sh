#!/bin/bash
# 快速启动脚本 - 启动make train并监控
cd "$(dirname "$0")"
cd ..

echo "════════════════════════════════════════════════════════════════"
echo "🚀 启动 NeurX 训练"
echo "════════════════════════════════════════════════════════════════"
echo ""

# 启动训练（后台）
echo "▶ 启动make train..."
make train > /dev/null 2>&1 &
MAKE_PID=$!
echo "✓ 训练已启动 (PID: $MAKE_PID)"
echo ""

# 等待日志文件出现
echo "▶ 等待日志文件生成..."
sleep 2

# 启动监控
echo "▶ 启动实时监控..."
echo "  按 Ctrl+C 停止日志查看（训练会继续进行）"
echo ""
echo "════════════════════════════════════════════════════════════════"

# 寻找最新日志
LATEST_LOG=$(ls -t artifacts/logs/train_*.log 2>/dev/null | head -1)

if [ -n "$LATEST_LOG" ]; then
    tail -f "$LATEST_LOG"
else
    echo "✗ 未找到日志文件，训练可能失败或尚未启动"
    echo ""
    echo "诊断信息："
    make train 2>&1 | head -50
fi
