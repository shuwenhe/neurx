#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export NEURX_ROOT="$NEURX_ROOT"

export S_SOURCE_ROOT="${S_SOURCE_ROOT:-$NEURX_ROOT}"
export S_COMPILER_EMIT_CWD="${S_COMPILER_EMIT_CWD:-$NEURX_ROOT/../s}"
if [ -z "${S_COMPILER:-}" ]; then
    if [ -x "$NEURX_ROOT/../s/bin/s" ]; then
        export S_COMPILER="$NEURX_ROOT/../s/bin/s"
    elif [ -x "$NEURX_ROOT/../s/.local/bin/s" ]; then
        export S_COMPILER="$NEURX_ROOT/../s/.local/bin/s"
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
export NEURX_PRETRAIN_SHARD_DIR="${NEURX_PRETRAIN_SHARD_DIR:-${NEURX_PRETRAIN_DATA_DIR:-$NEURX_ROOT/dataset/pretrain/shard}}"
export NEURX_PRETRAIN_OUTPUT_DIR="${NEURX_PRETRAIN_OUTPUT_DIR:-${NEURX_PRETRAIN_OUTPUT:-$NEURX_ROOT/checkpoint/NeurX-1.3}}"
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

# Compile S script to IR
BUILD_DIR="$NEURX_ROOT/artifacts/build/run_large_pretrain"
LOG_DIR="$NEURX_ROOT/artifacts/logs"
mkdir -p "$BUILD_DIR"
mkdir -p "$LOG_DIR"

SHARD_LIST_FILE="$BUILD_DIR/shard_list.sample.txt"
ALL_SHARDS_FILE="$BUILD_DIR/shard_list.all.txt"
find "$NEURX_PRETRAIN_SHARD_DIR" -maxdepth 1 -name 'shard_*.jsonl' -print | sort > "$ALL_SHARDS_FILE"
TOTAL_SHARDS=$(wc -l < "$ALL_SHARDS_FILE" 2>/dev/null || echo 0)

if [ "$TOTAL_SHARDS" -eq 0 ]; then
    echo "[ERROR] No shard files found in $NEURX_PRETRAIN_SHARD_DIR"
    exit 1
fi

if [ -n "${NEURX_PRETRAIN_SHARD_LIMIT:-}" ] && [ "${NEURX_PRETRAIN_SHARD_LIMIT:-0}" -gt 0 ] 2>/dev/null; then
    sed -n "1,${NEURX_PRETRAIN_SHARD_LIMIT}p" "$ALL_SHARDS_FILE" > "$SHARD_LIST_FILE"
    ACTIVE_SHARDS=$NEURX_PRETRAIN_SHARD_LIMIT
else
    cp "$ALL_SHARDS_FILE" "$SHARD_LIST_FILE"
    ACTIVE_SHARDS=$TOTAL_SHARDS
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
    fi
fi

mkdir -p "$NEURX_PRETRAIN_OUTPUT_DIR"

LATEST_CHECKPOINT_FILE="$NEURX_PRETRAIN_OUTPUT_DIR/latest_checkpoint.txt"
CHECKPOINT_INFO_FILE="$NEURX_PRETRAIN_OUTPUT_DIR/checkpoint_info.json"
RESUME_STATE_FILE="$NEURX_PRETRAIN_OUTPUT_DIR/resume_state.json"

if [ "${NEURX_PRETRAIN_RESUME:-1}" = "1" ] && [ -f "$LATEST_CHECKPOINT_FILE" ]; then
    LATEST_CHECKPOINT=$(cat "$LATEST_CHECKPOINT_FILE" 2>/dev/null)
    if [ -n "$LATEST_CHECKPOINT" ] && [ -f "$LATEST_CHECKPOINT" ]; then
        export NEURX_PRETRAIN_CHECKPOINT_PATH="$LATEST_CHECKPOINT"
        if [ -f "$RESUME_STATE_FILE" ]; then
            export NEURX_PRETRAIN_RESUME_STATE_FILE="$RESUME_STATE_FILE"
        fi
    else
        unset NEURX_PRETRAIN_CHECKPOINT_PATH
        unset NEURX_PRETRAIN_RESUME_STATE_FILE
    fi
else
    unset NEURX_PRETRAIN_CHECKPOINT_PATH
    unset NEURX_PRETRAIN_RESUME_STATE_FILE
fi

cd "$NEURX_ROOT"
if [ -z "$S_COMPILER" ]; then
    echo "Error: S compiler not found"
    exit 1
fi

# Check if incremental compilation is needed
SOURCE_FILE="$NEURX_ROOT/script/tiny_transformer_train.s"
IR_OUTPUT="$BUILD_DIR/run_large_pretrain.ir"
RUNNER_BIN_OUTPUT="$BUILD_DIR/run_large_pretrain.ir.runner.bin"

# Function to check if recompilation is needed
needs_recompile() {
    local src="$1"
    local output="$2"
    
    if [ ! -f "$output" ]; then
        return 0  # Output doesn't exist, needs compilation
    fi
    
    # Check if source is newer than output
    if [ "$src" -nt "$output" ]; then
        return 0  # Source is newer, needs recompilation
    fi
    
    return 1  # Output is up to date
}

# Check if IR compilation is needed
if needs_recompile "$SOURCE_FILE" "$IR_OUTPUT"; then
    START_TIME=$(date +%s)
    "$S_COMPILER" "$NEURX_ROOT/script/tiny_transformer_train.s" "$BUILD_DIR/run_large_pretrain.ir" >/dev/null 2>&1
    COMPILE_EXIT=$?
    END_TIME=$(date +%s)
    COMPILE_TIME=$((END_TIME - START_TIME))
    
    if [ $COMPILE_EXIT -ne 0 ] || [ ! -f "$BUILD_DIR/run_large_pretrain.ir" ]; then
        echo "Error: S compilation failed"
        exit 1
    fi
    
    # Reset runner binary timestamp so it gets recompiled too
    REBUILD_RUNNER=1
else
    REBUILD_RUNNER=0
fi

if [ "${NEURX_PRETRAIN_COMPILE_ONLY:-0}" = "1" ]; then
    exit 0
fi
# Use S IR runner to execute compiled IR
if [ ! -f "$S_RUNNER_BIN" ]; then
    make -C "$NEURX_ROOT" build-s-ir-runner >/dev/null 2>&1
fi
if [ ! -f "$S_RUNNER_BIN" ]; then
    echo "Error: S IR runner not found at $S_RUNNER_BIN"
    exit 1
fi

# Check if runner binary needs to be regenerated from IR
if [ -n "${REBUILD_RUNNER:-}" ] && [ "$REBUILD_RUNNER" = "1" ]; then
    # The runner binary will be regenerated during execution
    rm -f "$RUNNER_BIN_OUTPUT" 2>/dev/null || true
fi

RUN_TS="$(date +%Y%m%d_%H%M%S)"
RUN_LOG="$LOG_DIR/run_large_pretrain_${RUN_TS}.log"
export NEURX_ROOT NEURX_PRETRAIN_MANIFEST NEURX_PRETRAIN_DATA_DIR NEURX_PRETRAIN_OUTPUT_DIR \
       NEURX_PRETRAIN_MICRO_BATCH NEURX_PRETRAIN_SEQ_LEN NEURX_PRETRAIN_STEPS NEURX_NUM_EPOCHS \
       NEURX_TRAINING_RATIO NEURX_PRETRAIN_WARMUP_STEPS NEURX_PRETRAIN_MIN_LR NEURX_PRETRAIN_LR \
       NEURX_PRETRAIN_WEIGHT_DECAY NEURX_PRETRAIN_LOG_INTERVAL NEURX_PRETRAIN_EVAL_INTERVAL \
       NEURX_PRETRAIN_SAVE_INTERVAL NEURX_PRETRAIN_RESUME NEURX_ALLOW_FULL_1T_LOCAL \
       NEURX_PRETRAIN_FAST_PREFIX NEURX_PRETRAIN_FAST_PREFIX_LINES NEURX_PRETRAIN_FAST_PREFIX_BYTES \
       WORLD_SIZE RANK DDP_BACKEND MODEL_SIZE NEURX_PRETRAIN_SHARD_LIST_FILE NEURX_PRETRAIN_MAX_DOCS

# Run the S IR runner with unbuffered output
{
    S_IR_RUNNER_INPUT="$BUILD_DIR/run_large_pretrain.ir" \
    S_IR_RUNNER_ENTRY="main" \
    S_COMPILER="$S_COMPILER" \
    S_COMPILER_EMIT_CWD="$S_COMPILER_EMIT_CWD" \
    NEURX_ROOT="$NEURX_ROOT" \
    stdbuf -oL -eL "$S_RUNNER_BIN" 2>&1
} | tee -a "$RUN_LOG"
TRAIN_EXIT_CODE=${PIPESTATUS[0]}
if [ $TRAIN_EXIT_CODE -eq 0 ]; then
    :
else
    exit $TRAIN_EXIT_CODE
fi
