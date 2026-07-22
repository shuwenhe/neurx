#!/bin/bash




set -e

NEURX_ROOT="${NEURX_ROOT:-.}"
LOG_DIR="${LOG_DIR:-$NEURX_ROOT/checkpoint/NeurX-1.3/logs}"
ARTIFACT_LOG_DIR="${ARTIFACT_LOG_DIR:-$NEURX_ROOT/artifacts/logs}"


find_latest_log() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        return 1
    fi
    ls -t "$dir"/pretrain_gpu_*.log 2>/dev/null | head -1
}

LOG_FILE=$(find_latest_log "$ARTIFACT_LOG_DIR")
if [ -z "$LOG_FILE" ]; then
    LOG_FILE=$(find_latest_log "$LOG_DIR")
fi

if [ -z "$LOG_FILE" ]; then
    echo "❌ No training log file found in:"
    echo "   - $ARTIFACT_LOG_DIR"
    echo "   - $LOG_DIR"
    echo ""
    echo "✓ Start training with: make pretrain-gpu"
    exit 1
fi

echo "📊 Monitoring training progress..."
echo "📄 Log file: $LOG_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""


tail -f "$LOG_FILE" | while IFS= read -r line; do

    if echo "$line" | grep -q "trainer-v2"; then

        echo "$line" | sed -E 's/.*step=([0-9]+)\/([0-9]+).*loss=([0-9.]+).*/✓ Step \1\/\2, Loss: \3/'
    elif echo "$line" | grep -q "checkpoint"; then
        echo "💾 $line"
    elif echo "$line" | grep -q "error\|Error\|ERROR"; then
        echo "❌ $line"
    elif echo "$line" | grep -q "rank\|CUDA\|NCCL\|tokenizer"; then
        echo "ℹ  $line"
    elif echo "$line" | grep -q "complete"; then
        echo "✅ $line"
    fi
done
