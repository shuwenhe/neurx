#!/bin/bash
# NeurX 小模型训练 + checkpoint 落盘
# Compile the S training source to IR, execute it via the IR runner,
# and materialize the emitted checkpoint files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="${SCRIPT_DIR}"
S_ROOT="${S_ROOT:-$(cd "$NEURX_ROOT/../s" && pwd)}"
S_COMPILER="${S_COMPILER:-${S_ROOT}/bin/s}"
SOURCE_FILE="${SOURCE_FILE:-${NEURX_ROOT}/train/train_llm.s}"
BUILD_DIR="${NEURX_ROOT}/build/small_model_training"
CHECKPOINT_DIR="${NEURX_ROOT}/artifacts/checkpoints/llm_s_pretrain"
LOG_DIR="${NEURX_ROOT}/artifacts/logs"
IR_FILE="${BUILD_DIR}/train_llm.ir"
RUNNER_BIN="${BUILD_DIR}/s_ir_runner_small_model"
RUNNER_BIN_FALLBACK="${NEURX_ROOT}/build/s_ir_runner_train_model_large"
LOG_FILE="${LOG_DIR}/small_model_training_$(date +%Y%m%d_%H%M%S).log"
STDOUT_LOG="${LOG_DIR}/small_model_training_stdout_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$BUILD_DIR" "$CHECKPOINT_DIR" "$LOG_DIR"

cd "$S_ROOT"
LATEST_COMPILER="$("./bin/build_s_arm64.sh")"
"$LATEST_COMPILER" "$SOURCE_FILE" "$IR_FILE" >"$LOG_FILE" 2>&1

if [ ! -x "$RUNNER_BIN" ]; then
    if [ -x "$RUNNER_BIN_FALLBACK" ]; then
        RUNNER_BIN="$RUNNER_BIN_FALLBACK"
    else
        cd "$NEURX_ROOT"
        cc -std=c11 -O2 -Wall -Wextra -Werror -DSEED_COMPILE_ONLY \
          -I "$S_ROOT/src/cmd/compile/seed" \
          -o "$RUNNER_BIN" \
          "$NEURX_ROOT/tools/s_ir_runner.c" \
          "$S_ROOT/src/cmd/compile/seed/runtime/runtime.c" \
          "$S_ROOT/src/cmd/compile/seed/error/error.c" \
          "$S_ROOT/src/cmd/compile/seed/code/native_backend.c" \
          "$S_ROOT/src/cmd/compile/seed/lexical/lexer.c" \
          "$S_ROOT/src/cmd/compile/seed/syntax/parser.c" \
          "$S_ROOT/src/cmd/compile/seed/semantic/analyzer.c" \
          "$S_ROOT/src/cmd/compile/seed/intermediate/ir.c" \
          "$S_ROOT/src/cmd/compile/seed/code/generator.c" \
          "$S_ROOT/src/cmd/compile/seed/bootstrap/bootstrap.c" \
          "$S_ROOT/src/cmd/compile/seed/s_seed.c" >>"$LOG_FILE" 2>&1
    fi
fi

echo "Running small model training..."
set +e
NEURX_S_PRETRAIN_OUTPUT_DIR="$CHECKPOINT_DIR" \
NEURX_S_PRETRAIN_STEPS="${NEURX_S_PRETRAIN_STEPS:-50}" \
NEURX_S_PRETRAIN_WARMUP_STEPS="${NEURX_S_PRETRAIN_WARMUP_STEPS:-10}" \
"$RUNNER_BIN" "$IR_FILE" >"$STDOUT_LOG" 2>>"$LOG_FILE"
STATUS=$?
set -e
if [ "$STATUS" -ne 0 ]; then
    cat "$STDOUT_LOG" >>"$LOG_FILE"
    tail -n 40 "$LOG_FILE" >&2
    exit "$STATUS"
fi

while IFS= read -r checkpoint_path; do
    [ -n "$checkpoint_path" ] || continue
    mkdir -p "$(dirname "$checkpoint_path")"
done < <(grep '^CHECKPOINT_BEGIN ' "$STDOUT_LOG" | sed 's/^CHECKPOINT_BEGIN //')

awk '
    /^CHECKPOINT_BEGIN / {
        path = substr($0, 18)
        current = path
        first_line_in_block = 1
        next
    }
    /^CHECKPOINT_END / {
        if (current != "") {
            close(current)
        }
        current = ""
        next
    }
    /^CHECKPOINT_MANIFEST / {
        line = substr($0, 20)
        split(line, parts, " ")
        if (length(parts[1]) > 0 && length(parts[2]) > 0) {
            print parts[2] > parts[1]
            close(parts[1])
        }
        next
    }
    current != "" {
        if (first_line_in_block) {
            print $0 > current
            first_line_in_block = 0
        } else {
            print $0 >> current
        }
    }
' "$STDOUT_LOG"

if [ ! -f "$CHECKPOINT_DIR/latest_checkpoint.txt" ] && [ -f "$CHECKPOINT_DIR/final_model.neurx" ]; then
    printf '%s\n' "$CHECKPOINT_DIR/final_model.neurx" > "$CHECKPOINT_DIR/latest_checkpoint.txt"
fi

if [ ! -f "$CHECKPOINT_DIR/latest_checkpoint.txt" ]; then
    echo "Training completed, but no latest checkpoint was materialized." >&2
    exit 1
fi

echo "Small model training complete."
echo "Checkpoint directory: $CHECKPOINT_DIR"
echo "Latest checkpoint: $(cat "$CHECKPOINT_DIR/latest_checkpoint.txt")"
