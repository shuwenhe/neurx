#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export NEURX_ROOT="$NEURX_ROOT"

export S_SOURCE_ROOT="${S_SOURCE_ROOT:-$(cd "$NEURX_ROOT/.." && pwd)}"
if [ -z "${S_COMPILER:-}" ]; then
    if [ -x "$NEURX_ROOT/../s/bin/s" ]; then
        export S_COMPILER="$NEURX_ROOT/../s/bin/s"
    elif [ -x "$NEURX_ROOT/../s/.local/bin/s" ]; then
        export S_COMPILER="$NEURX_ROOT/../s/.local/bin/s"
    elif [ -x "/home/shuwen/s/bin/s" ]; then
        export S_COMPILER="/home/shuwen/s/bin/s"
    else
        export S_COMPILER="$(command -v s 2>/dev/null || true)"
    fi
fi
export S_RUNNER_BIN="${S_RUNNER_BIN:-$NEURX_ROOT/artifacts/build/s_runner/s_ir_runner}"

# Bridge the `make train` entry point to the real launcher. Keep the existing
# Makefile contract, but translate legacy variable names to the ones the
# pretraining backend actually reads.
export MODEL_SIZE="${MODEL_SIZE:-llm}"
export NEURX_PRETRAIN_MANIFEST="${NEURX_PRETRAIN_MANIFEST:-$NEURX_ROOT/dataset/pretrain/manifest.json}"
export NEURX_PRETRAIN_OUTPUT_DIR="${NEURX_PRETRAIN_OUTPUT_DIR:-${NEURX_PRETRAIN_OUTPUT:-$NEURX_ROOT/artifacts/checkpoints/llm_training}}"
export NEURX_PRETRAIN_MICRO_BATCH="${NEURX_PRETRAIN_MICRO_BATCH:-${NEURX_PRETRAIN_BATCH_SIZE:-${NEURX_BATCH_SIZE:-32}}}"
export NEURX_PRETRAIN_SEQ_LEN="${NEURX_PRETRAIN_SEQ_LEN:-${NEURX_SEQ_LENGTH:-2048}}"
export NEURX_NUM_EPOCHS="${NEURX_NUM_EPOCHS:-1}"
export NEURX_TRAINING_RATIO="${NEURX_TRAINING_RATIO:-1.0}"

# Calculate total steps based on data volume if not explicitly set
if [ -z "${NEURX_PRETRAIN_STEPS:-}" ] && [ -z "${NEURX_TOTAL_STEPS:-}" ]; then
    if [ -f "$NEURX_PRETRAIN_MANIFEST" ]; then
        TOTAL_DOCS=$(grep -o '"num_documents": [0-9]*' "$NEURX_PRETRAIN_MANIFEST" | grep -o '[0-9]*' | awk '{sum+=$1} END {print sum}')
        if [ -n "$TOTAL_DOCS" ] && [ "$TOTAL_DOCS" -gt 0 ]; then
            # Apply training ratio to total docs
            EFFECTIVE_DOCS=$(awk "BEGIN {print int($TOTAL_DOCS * $NEURX_TRAINING_RATIO)}")
            # steps = effective_docs / batch_size * epochs
            STEPS_PER_EPOCH=$((($EFFECTIVE_DOCS + $NEURX_PRETRAIN_MICRO_BATCH - 1) / $NEURX_PRETRAIN_MICRO_BATCH))
            NEURX_PRETRAIN_STEPS=$((STEPS_PER_EPOCH * NEURX_NUM_EPOCHS))
        else
            NEURX_PRETRAIN_STEPS=10000
        fi
    else
        NEURX_PRETRAIN_STEPS=10000
    fi
else
    NEURX_PRETRAIN_STEPS="${NEURX_PRETRAIN_STEPS:-${NEURX_TOTAL_STEPS:-10000}}"
fi
export NEURX_PRETRAIN_STEPS
export NEURX_NUM_EPOCHS
export NEURX_TRAINING_RATIO
export NEURX_PRETRAIN_WARMUP_STEPS="${NEURX_PRETRAIN_WARMUP_STEPS:-${NEURX_WARMUP_STEPS:-100}}"
export NEURX_PRETRAIN_MIN_LR="${NEURX_PRETRAIN_MIN_LR:-${NEURX_MIN_LR:-0.00002}}"
export NEURX_PRETRAIN_LR="${NEURX_PRETRAIN_LR:-${NEURX_LR:-0.0002}}"
export NEURX_PRETRAIN_WEIGHT_DECAY="${NEURX_PRETRAIN_WEIGHT_DECAY:-${NEURX_WEIGHT_DECAY:-0.1}}"
export NEURX_PRETRAIN_LOG_INTERVAL="${NEURX_PRETRAIN_LOG_INTERVAL:-${NEURX_LOG_INTERVAL:-10}}"
export NEURX_PRETRAIN_EVAL_INTERVAL="${NEURX_PRETRAIN_EVAL_INTERVAL:-${NEURX_EVAL_INTERVAL:-50}}"
export NEURX_PRETRAIN_SAVE_INTERVAL="${NEURX_PRETRAIN_SAVE_INTERVAL:-${NEURX_SAVE_INTERVAL:-100}}"
export NEURX_PRETRAIN_RESUME="${NEURX_PRETRAIN_RESUME:-1}"
export NEURX_ALLOW_FULL_1T_LOCAL="${NEURX_ALLOW_FULL_1T_LOCAL:-1}"
export NEURX_PRETRAIN_FAST_PREFIX="${NEURX_PRETRAIN_FAST_PREFIX:-0}"
export NEURX_PRETRAIN_FAST_PREFIX_LINES="${NEURX_PRETRAIN_FAST_PREFIX_LINES:-1}"
export NEURX_PRETRAIN_FAST_PREFIX_BYTES="${NEURX_PRETRAIN_FAST_PREFIX_BYTES:-1024}"
export WORLD_SIZE="${WORLD_SIZE:-${NEURX_PRETRAIN_WORLD_SIZE:-${NEURX_WORLD_SIZE:-1}}}"
export RANK="${RANK:-${NEURX_PRETRAIN_RANK:-0}}"
export DDP_BACKEND="${DDP_BACKEND:-${NEURX_PRETRAIN_BACKEND:-gloo}}"

echo "Launching NeurX large-model pretraining..."
echo "  manifest : $NEURX_PRETRAIN_MANIFEST"
echo "  output    : $NEURX_PRETRAIN_OUTPUT_DIR"
echo "  world size: $WORLD_SIZE"
echo "  backend   : $DDP_BACKEND"
echo "  epochs    : $NEURX_NUM_EPOCHS"
echo "  data ratio: $NEURX_TRAINING_RATIO"
echo "  batch     : $NEURX_PRETRAIN_MICRO_BATCH"
echo "  steps     : $NEURX_PRETRAIN_STEPS"
echo "    (calculation: docs / batch * epochs)"
echo ""
echo ""

if [ -n "${NEURX_PRETRAIN_SHARDS:-}" ]; then
    echo "Shard filter: ${NEURX_PRETRAIN_SHARDS}"
else
    echo "Shard filter: <none>"
fi

if [ -f "$NEURX_PRETRAIN_MANIFEST" ]; then
    echo "Resolved shard manifest preview:"
    sed -n '1,12p' "$NEURX_PRETRAIN_MANIFEST" | sed 's/^/  - /'
    echo ""
else
    echo "Warning: manifest not found at $NEURX_PRETRAIN_MANIFEST"
fi

# Compile S script to IR
BUILD_DIR="$NEURX_ROOT/artifacts/build/run_large_pretrain"
LOG_DIR="$NEURX_ROOT/artifacts/logs"
mkdir -p "$BUILD_DIR"
mkdir -p "$LOG_DIR"

SHARD_LIST_FILE="$BUILD_DIR/shard_list.sample.txt"
ALL_SHARDS_FILE="$BUILD_DIR/shard_list.all.txt"
find "$NEURX_ROOT/dataset/pretrain/shard" -maxdepth 1 -name 'shard_*.jsonl' -print | sort > "$ALL_SHARDS_FILE"
if [ -n "${NEURX_PRETRAIN_SHARD_LIMIT:-}" ] && [ "${NEURX_PRETRAIN_SHARD_LIMIT:-0}" -gt 0 ] 2>/dev/null; then
    sed -n "1,${NEURX_PRETRAIN_SHARD_LIMIT}p" "$ALL_SHARDS_FILE" > "$SHARD_LIST_FILE"
else
    cp "$ALL_SHARDS_FILE" "$SHARD_LIST_FILE"
fi
rm -f "$ALL_SHARDS_FILE"
export NEURX_PRETRAIN_SHARD_LIST_FILE="$SHARD_LIST_FILE"
export NEURX_PRETRAIN_MAX_DOCS="${NEURX_PRETRAIN_MAX_DOCS:-100000000}"

if [ "${NEURX_PRETRAIN_FAST_PREFIX:-0}" -gt 0 ] 2>/dev/null; then
    FIRST_SHARD_PATH="$(sed -n '1p' "$SHARD_LIST_FILE")"
    FAST_PREFIX_SHARD_FILE="$BUILD_DIR/shard_fast_prefix.jsonl"
    if [ -n "$FIRST_SHARD_PATH" ] && [ -f "$FIRST_SHARD_PATH" ]; then
        head -n "${NEURX_PRETRAIN_FAST_PREFIX_LINES:-1}" "$FIRST_SHARD_PATH" | cut -c1-"${NEURX_PRETRAIN_FAST_PREFIX_BYTES:-1024}" > "$FAST_PREFIX_SHARD_FILE"
        printf '%s\n' "$FAST_PREFIX_SHARD_FILE" > "$SHARD_LIST_FILE"
        export NEURX_PRETRAIN_FAST_PREFIX=0
        echo "Fast prefix sample shard created:"
        echo "  source : $FIRST_SHARD_PATH"
        echo "  sample  : $FAST_PREFIX_SHARD_FILE"
        echo "  lines   : $NEURX_PRETRAIN_FAST_PREFIX_LINES"
        echo "  bytes   : $NEURX_PRETRAIN_FAST_PREFIX_BYTES"
    fi
fi

echo "Compiling S training pipeline..."
cd "$NEURX_ROOT"
if [ -z "$S_COMPILER" ]; then
    echo "Error: S compiler not found"
    exit 1
fi

echo "Resolved command:"
echo "  S compilation: $NEURX_ROOT/script/minimal_train.s -> $BUILD_DIR/run_large_pretrain.ir"

"$S_COMPILER" ir "$NEURX_ROOT/script/minimal_train.s" -o "$BUILD_DIR/run_large_pretrain.ir"
if [ ! -f "$BUILD_DIR/run_large_pretrain.ir" ]; then
    echo "Error: S compilation failed"
    exit 1
fi

echo "Running training pipeline..."
# Use S IR runner to execute compiled IR
if [ ! -f "$S_RUNNER_BIN" ]; then
    echo "S IR runner not found at $S_RUNNER_BIN; building it now..."
    make -C "$NEURX_ROOT" build-s-ir-runner
fi
if [ ! -f "$S_RUNNER_BIN" ]; then
    echo "Error: S IR runner not found at $S_RUNNER_BIN"
    exit 1
fi
RUN_LOG="$LOG_DIR/run_large_pretrain_$(date +%Y%m%d_%H%M%S).log"
echo "Real training log: $RUN_LOG"
if command -v stdbuf >/dev/null 2>&1; then
    stdbuf -oL -eL "$S_RUNNER_BIN" "$BUILD_DIR/run_large_pretrain.ir" 2>&1 | tee -a "$RUN_LOG"
else
    "$S_RUNNER_BIN" "$BUILD_DIR/run_large_pretrain.ir" 2>&1 | tee -a "$RUN_LOG"
fi
