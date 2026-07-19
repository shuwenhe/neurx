#!/bin/bash
# NeurX CUDA Training Diagnostic
# English textCUDAtrainingEnglish textconfiguration

set -e

CURDIR="/home/shuwen/shuwen/train/neurx"
CUDA_TRAIN_BIN="$CURDIR/artifacts/build/cuda_train/neurx_cuda_train_bridge"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 NeurX CUDA Training Environment Diagnostic"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. English textNVIDIA GPU
echo "📌 Step 1: Checking NVIDIA GPU..."
if command -v nvidia-smi &> /dev/null; then
    GPU_COUNT=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU ' || echo 0)
    echo "   ✓ nvidia-smi found: $GPU_COUNT GPU(s)"
    nvidia-smi --query-gpu=name --format=csv,noheader | head -1 | sed 's/^/   - /'
else
    echo "   ❌ nvidia-smi not found"
    exit 1
fi
echo ""

# 2. English textCUDAtrainingEnglish textfile
echo "📌 Step 2: Checking CUDA training binary..."
if [ ! -f "$CUDA_TRAIN_BIN" ]; then
    echo "   ❌ Binary not found: $CUDA_TRAIN_BIN"
    exit 1
fi
echo "   ✓ Binary exists: $CUDA_TRAIN_BIN"
ls -lh "$CUDA_TRAIN_BIN" | sed 's/^/   /'
echo ""

# 3. English textRequiredEnglish textfile
echo "📌 Step 3: Checking required files..."
REQUIRED_FILES=(
    "$CURDIR/data/corpus/vocab.json"
    "$CURDIR/data/corpus/merges.txt"
    "$CURDIR/artifacts/build/run_large_pretrain/shard_list.txt"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✓ $file"
    else
        echo "   ⚠  Missing: $file"
    fi
done
echo ""

# 4. runCUDAtrainingEnglish text(English text1step)
echo "📌 Step 4: Testing CUDA binary (timeout 30s)..."
echo "   Running: timeout 30s $CUDA_TRAIN_BIN"
echo ""

mkdir -p "/tmp/neurx_diagnostic"
TEST_OUTPUT="/tmp/neurx_diagnostic/test_output.txt"

# English textconfigurationEnglish texttest
export NEURX_ROOT="$CURDIR"
export NEURX_PRETRAIN_OUTPUT_DIR="/tmp/neurx_diagnostic/checkpoint"
export NEURX_PRETRAIN_STEPS=1
export NEURX_PRETRAIN_MICRO_BATCH=1
export NEURX_PRETRAIN_SEQ_LEN=128
export NEURX_TRANSFORMER_DIM=256
export NEURX_TRANSFORMER_HEADS=8
export NEURX_TRANSFORMER_NUM_LAYERS=2
export NEURX_TOKENIZER_VOCAB="$CURDIR/data/corpus/vocab.json"
export NEURX_TOKENIZER_MERGES="$CURDIR/data/corpus/merges.txt"
export NEURX_VALIDATE_CHECKPOINT=0
export RANK=0
export LOCAL_RANK=0
export WORLD_SIZE=1
export CUDA_VISIBLE_DEVICES=0
export NEURX_NCCL_ID_FILE="/tmp/neurx_diagnostic/nccl_id"

# English textNCCLfileEnglish text
mkdir -p "$(dirname "$NEURX_NCCL_ID_FILE")"
touch "$NEURX_NCCL_ID_FILE"

# runEnglish textfileEnglish textoutput
timeout 30s "$CUDA_TRAIN_BIN" > "$TEST_OUTPUT" 2>&1 || EXIT_CODE=$?

if [ -z "$EXIT_CODE" ]; then
    EXIT_CODE=0
fi

# English textoutput
if [ -s "$TEST_OUTPUT" ]; then
    echo "   Output:"
    head -20 "$TEST_OUTPUT" | sed 's/^/   /'
else
    echo "   (No output received)"
fi
echo ""

# 5. English text
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary:"
if [ "$EXIT_CODE" -eq 0 ]; then
    echo "   ✅ CUDA binary exited successfully (code: 0)"
elif [ "$EXIT_CODE" -eq 124 ]; then
    echo "   ⏱  CUDA binary timed out after 30s (timeout)"
    echo "   ℹ  This is normal if GPU initialization is slow"
else
    echo "   ❌ CUDA binary failed with exit code: $EXIT_CODE"
fi
echo ""
echo "✓ To start full training, run: cd $CURDIR && make pretrain-gpu"
echo ""
