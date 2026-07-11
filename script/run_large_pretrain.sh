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
echo ""
echo "=========================================="
echo "📂 Stage 1: Scanning Shard Data Directory"
echo "=========================================="
echo "Preparing shard list..."
echo "  source dir: $NEURX_ROOT/dataset/pretrain/shard"
echo "  output    : $SHARD_LIST_FILE"
echo ""
echo "[STARTUP][shard-scan] scanning shard directory for training slices"
find "$NEURX_ROOT/dataset/pretrain/shard" -maxdepth 1 -name 'shard_*.jsonl' -print | sort > "$ALL_SHARDS_FILE"
TOTAL_SHARDS=$(wc -l < "$ALL_SHARDS_FILE" 2>/dev/null || echo 0)
echo "[STARTUP][shard-scan] found $TOTAL_SHARDS total shards"

if [ "$TOTAL_SHARDS" -eq 0 ]; then
    echo "[ERROR] No shard files found in $NEURX_ROOT/dataset/pretrain/shard"
    exit 1
fi

if [ -n "${NEURX_PRETRAIN_SHARD_LIMIT:-}" ] && [ "${NEURX_PRETRAIN_SHARD_LIMIT:-0}" -gt 0 ] 2>/dev/null; then
    echo "[STARTUP][shard-scan] limiting to ${NEURX_PRETRAIN_SHARD_LIMIT} shards"
    sed -n "1,${NEURX_PRETRAIN_SHARD_LIMIT}p" "$ALL_SHARDS_FILE" > "$SHARD_LIST_FILE"
    ACTIVE_SHARDS=$NEURX_PRETRAIN_SHARD_LIMIT
else
    cp "$ALL_SHARDS_FILE" "$SHARD_LIST_FILE"
    ACTIVE_SHARDS=$TOTAL_SHARDS
fi
rm -f "$ALL_SHARDS_FILE"
export NEURX_PRETRAIN_SHARD_LIST_FILE="$SHARD_LIST_FILE"
export NEURX_PRETRAIN_MAX_DOCS="${NEURX_PRETRAIN_MAX_DOCS:-100000000}"
echo "[STARTUP][shard-scan] using $ACTIVE_SHARDS shards for training"
echo ""
echo "  📋 First 3 shards in training set:"
sed -n '1,3p' "$SHARD_LIST_FILE" | while read shard; do
    if [ -f "$shard" ]; then
        size=$(du -h "$shard" 2>/dev/null | cut -f1)
        lines=$(wc -l < "$shard" 2>/dev/null || echo "?")
        printf "     • %s (%s, ~%s docs)\n" "$(basename "$shard")" "$size" "$lines"
    fi
done
echo ""

if [ "${NEURX_PRETRAIN_FAST_PREFIX:-0}" -gt 0 ] 2>/dev/null; then
    echo "[STARTUP][shard-scan] fast prefix mode enabled"
    FIRST_SHARD_PATH="$(sed -n '1p' "$SHARD_LIST_FILE")"
    FAST_PREFIX_SHARD_FILE="$BUILD_DIR/shard_fast_prefix.jsonl"
    if [ -n "$FIRST_SHARD_PATH" ] && [ -f "$FIRST_SHARD_PATH" ]; then
        echo "[STARTUP][shard-scan] creating fast prefix sample from first shard"
        head -n "${NEURX_PRETRAIN_FAST_PREFIX_LINES:-1}" "$FIRST_SHARD_PATH" | cut -c1-"${NEURX_PRETRAIN_FAST_PREFIX_BYTES:-1024}" > "$FAST_PREFIX_SHARD_FILE"
        printf '%s\n' "$FAST_PREFIX_SHARD_FILE" > "$SHARD_LIST_FILE"
        export NEURX_PRETRAIN_FAST_PREFIX=0
        echo "[STARTUP][shard-scan] fast prefix sample created:"
        echo "          source : $FIRST_SHARD_PATH"
        echo "          sample : $FAST_PREFIX_SHARD_FILE"
        echo "          lines  : $NEURX_PRETRAIN_FAST_PREFIX_LINES"
        echo "          bytes  : $NEURX_PRETRAIN_FAST_PREFIX_BYTES"
    fi
    echo ""
fi
echo "=========================================="
echo "Checkpoint & Resume Configuration"
echo "=========================================="

# 创建输出目录
mkdir -p "$NEURX_PRETRAIN_OUTPUT_DIR"

# 检查是否存在最新检查点
LATEST_CHECKPOINT_FILE="$NEURX_PRETRAIN_OUTPUT_DIR/latest_checkpoint.txt"
CHECKPOINT_INFO_FILE="$NEURX_PRETRAIN_OUTPUT_DIR/checkpoint_info.json"
RESUME_STATE_FILE="$NEURX_PRETRAIN_OUTPUT_DIR/resume_state.json"

# 检查点续训支持
if [ "${NEURX_PRETRAIN_RESUME:-1}" = "1" ] && [ -f "$LATEST_CHECKPOINT_FILE" ]; then
    echo "[STARTUP][checkpoint] latest pointer file exists"
    LATEST_CHECKPOINT=$(cat "$LATEST_CHECKPOINT_FILE" 2>/dev/null)
    if [ -n "$LATEST_CHECKPOINT" ] && [ -f "$LATEST_CHECKPOINT" ]; then
        echo "✓ Found latest checkpoint: $LATEST_CHECKPOINT"
        echo "  latest pointer : $LATEST_CHECKPOINT_FILE"
        echo "  checkpoint file: $LATEST_CHECKPOINT"
        export NEURX_PRETRAIN_CHECKPOINT_PATH="$LATEST_CHECKPOINT"
        
        # 如果存在恢复状态文件，提取之前的训练状态
        if [ -f "$RESUME_STATE_FILE" ]; then
            echo "✓ Found resume state file"
            echo "  resume state   : $RESUME_STATE_FILE"
            export NEURX_PRETRAIN_RESUME_STATE_FILE="$RESUME_STATE_FILE"
        fi
    else
        echo "[STARTUP][checkpoint] latest pointer is stale; starting fresh training"
        unset NEURX_PRETRAIN_CHECKPOINT_PATH
        unset NEURX_PRETRAIN_RESUME_STATE_FILE
    fi
else
    echo "[STARTUP][checkpoint] no usable latest pointer found"
    echo "ℹ Resume disabled or no checkpoint found, starting fresh training"
    unset NEURX_PRETRAIN_CHECKPOINT_PATH
    unset NEURX_PRETRAIN_RESUME_STATE_FILE
fi

echo "Output directory: $NEURX_PRETRAIN_OUTPUT_DIR"
echo ""

echo "Compiling S training pipeline..."
cd "$NEURX_ROOT"
if [ -z "$S_COMPILER" ]; then
    echo "Error: S compiler not found"
    exit 1
fi

# Check if incremental compilation is needed
SOURCE_FILE="$NEURX_ROOT/script/minimal_train.s"
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
    echo "Resolved command:"
    echo "  S compilation: $NEURX_ROOT/script/minimal_train.s -> $BUILD_DIR/run_large_pretrain.ir"
    echo "Compiling S source to IR (this may take 30-60 seconds on first run)..."
    
    START_TIME=$(date +%s)
    "$S_COMPILER" "$NEURX_ROOT/script/minimal_train.s" "$BUILD_DIR/run_large_pretrain.ir"
    COMPILE_EXIT=$?
    END_TIME=$(date +%s)
    COMPILE_TIME=$((END_TIME - START_TIME))
    
    if [ $COMPILE_EXIT -ne 0 ] || [ ! -f "$BUILD_DIR/run_large_pretrain.ir" ]; then
        echo "Error: S compilation failed"
        exit 1
    fi
    
    echo "✓ S source compiled successfully (took ${COMPILE_TIME}s)"
    # Reset runner binary timestamp so it gets recompiled too
    REBUILD_RUNNER=1
else
    echo "✓ Using cached S IR: $IR_OUTPUT"
    echo "  (source unchanged since last compilation)"
    REBUILD_RUNNER=0
fi

if [ "${NEURX_PRETRAIN_COMPILE_ONLY:-0}" = "1" ]; then
    echo "Compile-only mode enabled; skipping execution."
    exit 0
fi

echo ""
echo "Running training pipeline..."
echo "[STARTUP][runner] entering training runner launch"
# Use S IR runner to execute compiled IR
if [ ! -f "$S_RUNNER_BIN" ]; then
    echo "S IR runner not found at $S_RUNNER_BIN; building it now..."
    make -C "$NEURX_ROOT" build-s-ir-runner
fi
if [ ! -f "$S_RUNNER_BIN" ]; then
    echo "Error: S IR runner not found at $S_RUNNER_BIN"
    exit 1
fi

# Check if runner binary needs to be regenerated from IR
if [ -n "${REBUILD_RUNNER:-}" ] && [ "$REBUILD_RUNNER" = "1" ]; then
    echo "[STARTUP][runner] building runner executable from IR"
    echo "  source : $IR_OUTPUT"
    echo "  output : $RUNNER_BIN_OUTPUT"
    # The runner binary will be regenerated during execution
    rm -f "$RUNNER_BIN_OUTPUT" 2>/dev/null || true
    echo "[STARTUP][runner] runner binary cleared; it will be regenerated on first execution"
else
    if [ -f "$RUNNER_BIN_OUTPUT" ]; then
        echo "[STARTUP][runner] using cached S IR runner binary"
    fi
fi

RUN_TS="$(date +%Y%m%d_%H%M%S)"
RUN_LOG="$LOG_DIR/run_large_pretrain_${RUN_TS}.log"
STARTUP_LOG="$LOG_DIR/run_large_pretrain_${RUN_TS}.startup.log"
STARTUP_MARKER_FILE="$BUILD_DIR/runner_startup.marker"
rm -f "$STARTUP_MARKER_FILE" 2>/dev/null || true
printf '' > "$STARTUP_LOG"
startup_log() {
    printf '%s\n' "$1" | tee -a "$STARTUP_LOG"
}
echo ""
echo "=========================================="
echo "📊 Stage 3: Launching S IR Runner"
echo "=========================================="
echo ""
echo "Real training log: $RUN_LOG"
echo "Training started. Monitor progress with: tail -f $RUN_LOG"
echo ""
startup_log "[STARTUP][runner] S IR runner launching now"
startup_log "[STARTUP][runner] executing training pipeline from $BUILD_DIR/run_large_pretrain.ir"
startup_log "[STARTUP][runner] waiting for the first training heartbeat"
echo ""

# Stream output to both terminal and log file so shard/progress lines stay visible.
# Capture both stdout and stderr, redirect to both log and terminal
# Export all environment variables to the runner
export NEURX_ROOT NEURX_PRETRAIN_MANIFEST NEURX_PRETRAIN_DATA_DIR NEURX_PRETRAIN_OUTPUT_DIR \
       NEURX_PRETRAIN_MICRO_BATCH NEURX_PRETRAIN_SEQ_LEN NEURX_PRETRAIN_STEPS NEURX_NUM_EPOCHS \
       NEURX_TRAINING_RATIO NEURX_PRETRAIN_WARMUP_STEPS NEURX_PRETRAIN_MIN_LR NEURX_PRETRAIN_LR \
       NEURX_PRETRAIN_WEIGHT_DECAY NEURX_PRETRAIN_LOG_INTERVAL NEURX_PRETRAIN_EVAL_INTERVAL \
       NEURX_PRETRAIN_SAVE_INTERVAL NEURX_PRETRAIN_RESUME NEURX_ALLOW_FULL_1T_LOCAL \
       NEURX_PRETRAIN_FAST_PREFIX NEURX_PRETRAIN_FAST_PREFIX_LINES NEURX_PRETRAIN_FAST_PREFIX_BYTES \
       WORLD_SIZE RANK DDP_BACKEND MODEL_SIZE NEURX_PRETRAIN_SHARD_LIST_FILE NEURX_PRETRAIN_MAX_DOCS \
       NEURX_STARTUP_MARKER_FILE="$STARTUP_MARKER_FILE" \
       NEURX_STARTUP_LOG_FILE="$STARTUP_LOG"

# Monitor startup progress with spinner and compilation detection
(
    spinner_frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    spinner_idx=0
    wait_count=0
    max_wait=60  # 60 * 0.5 seconds = 30 seconds max wait
    runner_bin_size_prev=0
    
    while [ ! -f "$STARTUP_MARKER_FILE" ]; do
        # Check if S IR runner binary is being generated (size increasing)
        if [ -f "$RUNNER_BIN_OUTPUT" ]; then
            runner_bin_size=$(stat -f%z "$RUNNER_BIN_OUTPUT" 2>/dev/null || echo 0)
            if [ "$runner_bin_size" -gt "$runner_bin_size_prev" ]; then
                startup_log "[STARTUP][compiler] ⚙️  JIT compiling: $(printf "%0.1f" "$(echo "scale=1; $runner_bin_size / 1048576" | bc)") MB generated"
                runner_bin_size_prev=$runner_bin_size
            fi
        fi
        
        # Shorter sleep for more responsive feedback
        sleep 0.5
        wait_count=$((wait_count + 1))
        
        # Show spinner every second (2 iterations of 0.5s)
        if [ $((wait_count % 2)) -eq 0 ]; then
            spinner_char="${spinner_frames[$((spinner_idx % 10))]}"
            echo "[STARTUP][runner] $spinner_char JIT compiling S IR runner binary (waiting for heartbeat)..." >&2
            spinner_idx=$((spinner_idx + 1))
        fi
        
        # Timeout warning at 15 seconds
        if [ $wait_count -eq 30 ]; then
            startup_log "[STARTUP][compiler] ⚠️  JIT compilation taking longer than expected (~15s)"
            startup_log "[STARTUP][compiler] This is normal for the first run; subsequent runs will use cached binary"
        fi
        
        # Hard timeout at 60 seconds
        if [ $wait_count -ge $max_wait ]; then
            startup_log "[ERROR] ❌ Startup timeout: S IR runner did not start within 30 seconds"
            startup_log "[ERROR] Check if S compiler is properly configured"
            startup_log "[ERROR] Log file: $RUN_LOG"
            exit 1
        fi
    done
) &
STARTUP_WATCHER_PID=$!
trap 'kill $STARTUP_WATCHER_PID >/dev/null 2>&1 || true' EXIT

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
    echo "✓ Training completed successfully!"
else
    echo "✗ Training failed with exit code $TRAIN_EXIT_CODE"
    echo "Check log for details: cat $RUN_LOG"
    exit $TRAIN_EXIT_CODE
fi

echo ""
echo "Checkpoint fragments on disk:"
for fragment in final_model.neurx best_model.neurx latest_checkpoint.txt resume_state.json; do
    fragment_path="$NEURX_PRETRAIN_OUTPUT_DIR/$fragment"
    if [ -e "$fragment_path" ]; then
        echo "  - $fragment_path"
    fi
done
