#!/bin/bash
# Launch minimal training with real-time shard processing monitor

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="${SCRIPT_DIR}/.."
TRAIN_SCRIPT="${NEURX_ROOT}/script/minimal_train.s"
S_COMPILER="${1:-/home/shuwen/s/bin/s}"
S_RUNNER="${S_COMPILER}"

# 确保编译器存在
if [ ! -f "$S_COMPILER" ]; then
    echo "Error: S compiler not found at $S_COMPILER" >&2
    echo "Set S_COMPILER environment variable to specify the compiler path" >&2
    exit 1
fi

# 编译检查
echo "🔍 Checking S language source..."
"$S_COMPILER" check "$TRAIN_SCRIPT" || {
    echo "❌ Syntax check failed" >&2
    exit 1
}
echo "✓ Syntax check passed"
echo ""

# 生成 IR
echo "📦 Compiling to IR..."
IR_FILE="${NEURX_ROOT}/artifacts/build/run_large_pretrain/minimal_train.ir"
mkdir -p "$(dirname "$IR_FILE")"

"$S_COMPILER" ir "$TRAIN_SCRIPT" -o "$IR_FILE" || {
    echo "❌ Compilation failed" >&2
    exit 1
}
echo "✓ Compiled to $IR_FILE"
echo ""

# 启动监控器（后台）
LOG_PIPE="${NEURX_ROOT}/.neurx-shard-log-pipe"
mkdir -p "$(dirname "$LOG_PIPE")"

# 清理旧的管道
rm -f "$LOG_PIPE" 2>/dev/null || true

echo "🎬 Starting real-time monitor..."
echo ""

# 创建日志管道
mkfifo "$LOG_PIPE" 2>/dev/null || true

# 启动监控器
bash "${SCRIPT_DIR}/monitor-shard-processing.sh" "$LOG_PIPE" &
MONITOR_PID=$!

# 给监控器一点时间启动
sleep 1

echo "🚀 Starting training with shard processing..."
echo ""

# 启动训练，将 stderr 重定向到日志管道
export NEURX_ROOT="$NEURX_ROOT"
export S_RUNNER_BIN="$S_RUNNER"

{
    "$S_RUNNER" "$IR_FILE" 2>&1
} | tee -a >(while read line; do
    # 在这里处理并转发日志到监控器
    echo "$line" >> "$LOG_PIPE" 2>/dev/null || true
done)

# 等待监控器完成
wait $MONITOR_PID 2>/dev/null || true

# 清理
rm -f "$LOG_PIPE"

echo ""
echo "✅ Training session complete"
