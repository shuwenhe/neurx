#!/bin/bash
# Quick start guide for improved shard processing logging
# 快速开始 - 改进的 shard 处理实时日志

echo "═══════════════════════════════════════════════════════════════"
echo "NeurX Shard Processing - Real-time Logging Quick Start Guide"
echo "═══════════════════════════════════════════════════════════════"
echo ""

NEURX_ROOT="/home/shuwen/shuwen/train/neurx"
S_COMPILER="/home/shuwen/s/bin/s"

echo "📋 Configuration:"
echo "  Project Root: $NEURX_ROOT"
echo "  S Compiler: $S_COMPILER"
echo "  Training Script: $NEURX_ROOT/script/minimal_train.s"
echo ""

# 检查前置条件
echo "🔍 Checking prerequisites..."

if [ ! -f "$S_COMPILER" ]; then
    echo "❌ S compiler not found: $S_COMPILER"
    exit 1
fi
echo "✓ S compiler found"

if [ ! -f "$NEURX_ROOT/script/minimal_train.s" ]; then
    echo "❌ Training script not found"
    exit 1
fi
echo "✓ Training script found"

if [ ! -f "$NEURX_ROOT/tools/run-with-shard-monitor.sh" ]; then
    echo "❌ Monitor script not found"
    exit 1
fi
echo "✓ Monitor script found"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📖 Usage Methods:"
echo ""

echo "【Method 1】 Auto-Compile & Monitor (Recommended)"
echo "────────────────────────────────────────────────"
echo "  cd $NEURX_ROOT"
echo "  bash tools/run-with-shard-monitor.sh $S_COMPILER"
echo ""

echo "【Method 2】 Manual Compilation & Run"
echo "────────────────────────────────────────────────"
echo "  cd $NEURX_ROOT"
echo ""
echo "  # Step 1: Syntax check"
echo "  $S_COMPILER check script/minimal_train.s"
echo ""
echo "  # Step 2: Compile to IR"
echo "  mkdir -p artifacts/build/run_large_pretrain"
echo "  $S_COMPILER ir script/minimal_train.s -o artifacts/build/run_large_pretrain/minimal_train.ir"
echo ""
echo "  # Step 3: Run with real-time logging"
echo "  export NEURX_ROOT=$NEURX_ROOT"
echo "  $S_COMPILER artifacts/build/run_large_pretrain/minimal_train.ir 2>&1"
echo ""

echo "【Method 3】 Run with Custom Parameters"
echo "────────────────────────────────────────────────"
echo "  export NEURX_PRETRAIN_BATCH_SIZE=64"
echo "  export NEURX_PRETRAIN_SEQ_LEN=2048"
echo "  export NEURX_PRETRAIN_STEPS=1000"
echo "  export NEURX_PRETRAIN_LR=0.0002"
echo "  $S_COMPILER artifacts/build/run_large_pretrain/minimal_train.ir 2>&1"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📊 Real-time Log Output Format:"
echo ""
echo "  Expected output will show:"
echo "  ✓ [STATUS] Starting shard processing..."
echo "  ✓ [DEBUG] Found 100 shards"
echo "  ✓ ▶ Processing Shard 1/100"
echo "  ✓ 📊 Step: 1  Loss: 2.5432  LR: 0.00012345"
echo "  ✓ [TRAIN] Step 10: loss=1.8765 lr=0.000234"
echo "  ✓ ✓ Shard complete: docs=1000 tokens=2048000"
echo "  ✓ [COMPLETE] Training finished"
echo ""

echo "🔍 Key Improvements:"
echo "  ✅ Real-time shard processing display"
echo "  ✅ Color-coded log output"
echo "  ✅ Step-by-step progress tracking"
echo "  ✅ No buffering delays"
echo "  ✅ Error and debug information"
echo "  ✅ Total training time calculation"
echo ""

echo "📚 Documentation:"
echo "  See: $NEURX_ROOT/docs/SHARD_PROCESSING_REALTIME_LOGGING.md"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 提供启动选项
echo "🚀 Ready to start training?"
echo ""
echo "Choose your option:"
echo "  1) Auto-compile and monitor (recommended)"
echo "  2) View documentation"
echo "  3) Exit"
echo ""

read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        echo ""
        echo "Starting training with real-time monitoring..."
        echo ""
        cd "$NEURX_ROOT"
        bash tools/run-with-shard-monitor.sh "$S_COMPILER"
        ;;
    2)
        if command -v less >/dev/null 2>&1; then
            less "$NEURX_ROOT/docs/SHARD_PROCESSING_REALTIME_LOGGING.md"
        else
            cat "$NEURX_ROOT/docs/SHARD_PROCESSING_REALTIME_LOGGING.md"
        fi
        ;;
    3)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac
