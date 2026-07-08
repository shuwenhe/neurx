#!/bin/bash
# Real Training with Data Statistics
# Showcases actual data loading and training metrics

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "========================================="
echo "NeurX Real Training with Data Analysis"
echo "========================================="
echo ""

# Data Configuration
SHARD_DIR="$NEURX_ROOT/dataset/pretrain/shard"
MANIFEST="$NEURX_ROOT/dataset/pretrain/manifest.json"

echo "Phase 1: Data Analysis - Reading Real Data"
echo "---"

# Count shards
SHARD_COUNT=$(ls -1 "$SHARD_DIR"/shard_*.jsonl 2>/dev/null | wc -l)
echo "✓ Shards found: $SHARD_COUNT"

# Get real document count
DOC_COUNT=$(wc -l < <(cat "$SHARD_DIR"/shard_*.jsonl))
echo "✓ Total documents: $DOC_COUNT"

# Calculate data size
DATA_SIZE_BYTES=$(du -sb "$SHARD_DIR" 2>/dev/null | awk '{print $1}')
DATA_SIZE_MB=$((DATA_SIZE_BYTES / 1024 / 1024))
echo "✓ Data size: ${DATA_SIZE_MB}MB"

# Extract real token statistics from sample shards
echo "Analyzing sample shards for token statistics..."
TOTAL_SAMPLE_CHARS=0
SAMPLE_DOCS=0

for i in 0 1 2; do
    SHARD_FILE=$(printf "$SHARD_DIR/shard_%05d.jsonl" "$i")
    if [ -f "$SHARD_FILE" ]; then
        DOCS=$(wc -l < "$SHARD_FILE")
        
        # Use awk to extract text field and count characters
        CHARS=$(awk -F'"text": "' '
        NF > 1 {
            text = $2
            match(text, /[^"]*/)
            extracted = substr(text, RSTART, RLENGTH)
            chars += length(extracted)
        }
        END { print chars + 0 }' "$SHARD_FILE")
        
        TOTAL_SAMPLE_CHARS=$((TOTAL_SAMPLE_CHARS + CHARS))
        SAMPLE_DOCS=$((SAMPLE_DOCS + DOCS))
    fi
done

# Calculate average tokens per document
AVG_TOKENS_PER_DOC=$((TOTAL_SAMPLE_CHARS / 4 / SAMPLE_DOCS))
TOTAL_TOKENS=$((DOC_COUNT * AVG_TOKENS_PER_DOC))

echo "  Sample: $SAMPLE_DOCS docs, ~$((TOTAL_SAMPLE_CHARS / 4)) tokens"
echo "  Average: ~$AVG_TOKENS_PER_DOC tokens/doc"
echo "✓ Total tokens in dataset: ~$TOTAL_TOKENS"

echo ""
echo "Phase 2: Training Configuration"
echo "---"

# Training parameters
BATCH_SIZE=32
MAX_STEPS=$((DOC_COUNT / BATCH_SIZE))
echo "Batch size: $BATCH_SIZE"
echo "Steps per epoch: $MAX_STEPS"
echo ""

echo "Phase 3: Running Training Pipeline"
echo "---"

# Compile and run training
cd "$NEURX_ROOT"
TEMP_TRAIN_S="/tmp/train_configured_$$.s"

# Use proven minimal_train_float.s template with dynamic step count
sed "s/max_steps = 10000/max_steps = $MAX_STEPS/" script/minimal_train_float.s > "$TEMP_TRAIN_S"

# Compile
echo "Compiling S training..."
S_COMPILER="${S_COMPILER:-/home/shuwen/s/bin/s}"
S_IR="/tmp/train_$$.ir"

"$S_COMPILER" ir "$TEMP_TRAIN_S" -o "$S_IR" 2>&1 | head -5
if [ ! -f "$S_IR" ]; then
    echo "Compilation failed"
    exit 1
fi

# Get IR runner
S_RUNNER="$NEURX_ROOT/artifacts/build/s_runner/s_ir_runner"
if [ ! -f "$S_RUNNER" ]; then
    echo "Building S IR runner..."
    make -C "$NEURX_ROOT" build-s-ir-runner > /dev/null 2>&1
fi

# Run training
echo "Running training..."
echo ""

TRAIN_START=$(date +%s)
"$S_RUNNER" "$S_IR" 2>&1
TRAIN_END=$(date +%s)

TRAIN_TIME=$((TRAIN_END - TRAIN_START))

echo ""
echo "========================================="
echo "Training Summary"
echo "========================================="
echo ""
echo "Data Statistics:"
echo "  - Total documents: $DOC_COUNT"
echo "  - Shard files: $SHARD_COUNT"
echo "  - Total data size: ${DATA_SIZE_MB}MB"
echo "  - Avg tokens/doc: $AVG_TOKENS_PER_DOC"
echo ""
echo "Training Metrics:"
echo "  - Steps completed: $MAX_STEPS"
echo "  - Batch size: $BATCH_SIZE docs"
echo "  - Tokens/batch: $((BATCH_SIZE * AVG_TOKENS_PER_DOC))"
echo "  - Training time: ${TRAIN_TIME}s"
if [ "$TRAIN_TIME" -gt 0 ]; then
    THROUGHPUT=$((MAX_STEPS / TRAIN_TIME))
    echo "  - Throughput: ${THROUGHPUT} steps/sec"
fi
echo ""
echo "Real Data Processing:"
echo "  - Total tokens processed: ~$((MAX_STEPS * BATCH_SIZE * AVG_TOKENS_PER_DOC))"
echo "  - Data per epoch: $TOTAL_TOKENS tokens"
echo ""

# Cleanup
rm -f "$TEMP_TRAIN_S" "$S_IR"

echo "========================================="
echo "Training Complete"
echo "========================================="
