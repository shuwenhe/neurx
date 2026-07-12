#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

S_COMPILER="${S_COMPILER:-$ROOT_DIR/../s/.local/bin/s}"
ENTRY_SOURCE="${NEURX_PRETRAIN_ENTRY_SOURCE:-$ROOT_DIR/pretrain/llm/large_pretrain.s}"
BUILD_DIR="${NEURX_PRETRAIN_BUILD_DIR:-$ROOT_DIR/artifacts/build/pretrain_cuda}"
IR_FILE="$BUILD_DIR/pretrain_cuda_runner.ir"
ENTRY_IR_FILE="$BUILD_DIR/pretrain_cuda_entry.ir"
BPE_IR_FILE="$BUILD_DIR/pretrain_bpe.ir"
BIN_FILE="$BUILD_DIR/pretrain_cuda_runner"

NEURX_PRETRAIN_MANIFEST="${NEURX_PRETRAIN_MANIFEST:-$ROOT_DIR/dataset/pretrain/manifest.json}"
NEURX_PRETRAIN_SHARD_DIR="${NEURX_PRETRAIN_SHARD_DIR:-${NEURX_PRETRAIN_DATA_DIR:-$ROOT_DIR/dataset/pretrain/shard}}"
NEURX_PRETRAIN_DATA_DIR="${NEURX_PRETRAIN_DATA_DIR:-$ROOT_DIR/dataset/pretrain}"
NEURX_PRETRAIN_OUTPUT_DIR="${NEURX_PRETRAIN_OUTPUT_DIR:-$ROOT_DIR/artifacts/checkpoints/gpt_large_pretrain}"
NEURX_PRETRAIN_BACKEND="${NEURX_PRETRAIN_BACKEND:-nccl}"
DDP_BACKEND="${DDP_BACKEND:-$NEURX_PRETRAIN_BACKEND}"
MODEL_SIZE="${MODEL_SIZE:-llm}"
NEURX_ALLOW_FULL_1T_LOCAL="${NEURX_ALLOW_FULL_1T_LOCAL:-1}"

mkdir -p "$BUILD_DIR"

if [[ ! -d "$NEURX_PRETRAIN_SHARD_DIR" ]]; then
  echo "Missing shard directory: $NEURX_PRETRAIN_SHARD_DIR" >&2
  exit 1
fi

if [[ ! -f "$ENTRY_SOURCE" ]]; then
  echo "Missing entry source: $ENTRY_SOURCE" >&2
  exit 1
fi

if [[ ! -x "$S_COMPILER" && ! -f "$S_COMPILER" ]]; then
  echo "S compiler not found: $S_COMPILER" >&2
  exit 1
fi

cd "$ROOT_DIR"

echo "Preparing shard manifest..."
echo "  shard dir: $NEURX_PRETRAIN_SHARD_DIR"
echo "  manifest : $NEURX_PRETRAIN_MANIFEST"
bash "$SCRIPT_DIR/build_pretrain_manifest.sh" "$NEURX_PRETRAIN_SHARD_DIR" "$NEURX_PRETRAIN_MANIFEST"

if [[ ! -f "$NEURX_PRETRAIN_MANIFEST" ]]; then
  echo "Failed to build manifest: $NEURX_PRETRAIN_MANIFEST" >&2
  exit 1
fi

python3 - "$NEURX_PRETRAIN_MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
shards = manifest.get("shards", [])
existing = [item for item in shards if Path(str(item.get("file_path", ""))).is_file()]
if not existing:
    raise SystemExit(f"Manifest contains no readable shard files: {manifest_path}")
print(f"[pretrain-manifest] validated readable shards: {len(existing)}", file=sys.stderr)
PY

echo "Building CUDA pretrain launcher..."
echo "  source : $ENTRY_SOURCE"
echo "  ir     : $IR_FILE"
echo "  binary : $BIN_FILE"
echo "  backend: $NEURX_PRETRAIN_BACKEND"

S_SOURCE_ROOT="${S_SOURCE_ROOT:-$ROOT_DIR/../s}" S_COMPILER="$S_COMPILER" "$S_COMPILER" "$ENTRY_SOURCE" "$ENTRY_IR_FILE"
S_SOURCE_ROOT="${S_SOURCE_ROOT:-$ROOT_DIR/../s}" S_COMPILER="$S_COMPILER" "$S_COMPILER" "$ROOT_DIR/pretrain/tokenizer/bpe.s" "$BPE_IR_FILE"
bash "$SCRIPT_DIR/link_s_ir_module.sh" \
  "$BPE_IR_FILE" \
  "$ENTRY_IR_FILE" \
  "bpe" \
  "$IR_FILE"
S_SOURCE_ROOT="${S_SOURCE_ROOT:-$ROOT_DIR/../s}" S_COMPILER="$S_COMPILER" "$S_COMPILER" --emit-bin "$IR_FILE" "$BIN_FILE"
if [[ ! -f "$BIN_FILE" ]]; then
  echo "Failed to build CUDA pretrain launcher: $BIN_FILE" >&2
  exit 1
fi
chmod +x "$BIN_FILE"

if [[ "${NEURX_PRETRAIN_COMPILE_ONLY:-0}" = "1" ]]; then
  echo "Compile-only mode enabled; skipping execution."
  exit 0
fi

echo "Launching CUDA pretrain..."
env \
  NEURX_ROOT="$ROOT_DIR" \
  S_SOURCE_ROOT="${S_SOURCE_ROOT:-$ROOT_DIR/..}" \
  NEURX_PRETRAIN_MANIFEST="$NEURX_PRETRAIN_MANIFEST" \
  NEURX_PRETRAIN_DATA_DIR="$NEURX_PRETRAIN_DATA_DIR" \
  NEURX_PRETRAIN_SHARD_DIR="$NEURX_PRETRAIN_SHARD_DIR" \
  NEURX_PRETRAIN_OUTPUT_DIR="$NEURX_PRETRAIN_OUTPUT_DIR" \
  NEURX_PRETRAIN_BACKEND="$NEURX_PRETRAIN_BACKEND" \
  DDP_BACKEND="$DDP_BACKEND" \
  MODEL_SIZE="$MODEL_SIZE" \
  NEURX_ALLOW_FULL_1T_LOCAL="$NEURX_ALLOW_FULL_1T_LOCAL" \
  S_SOURCE_ROOT="${S_SOURCE_ROOT:-$ROOT_DIR/../s}" \
  WORLD_SIZE="${WORLD_SIZE:-1}" \
  RANK="${RANK:-0}" \
  MASTER_ADDR="${MASTER_ADDR:-localhost}" \
  MASTER_PORT="${MASTER_PORT:-29500}" \
  NEURX_PRETRAIN_STEPS="${NEURX_PRETRAIN_STEPS:-64}" \
  NEURX_PRETRAIN_MICRO_BATCH="${NEURX_PRETRAIN_MICRO_BATCH:-8}" \
  NEURX_PRETRAIN_SEQ_LEN="${NEURX_PRETRAIN_SEQ_LEN:-16}" \
  NEURX_PRETRAIN_LR="${NEURX_PRETRAIN_LR:-0.00015}" \
  NEURX_PRETRAIN_WARMUP_STEPS="${NEURX_PRETRAIN_WARMUP_STEPS:-128}" \
  NEURX_PRETRAIN_MIN_LR="${NEURX_PRETRAIN_MIN_LR:-0.00003}" \
  NEURX_PRETRAIN_WEIGHT_DECAY="${NEURX_PRETRAIN_WEIGHT_DECAY:-0.1}" \
  NEURX_PRETRAIN_LOG_INTERVAL="${NEURX_PRETRAIN_LOG_INTERVAL:-8}" \
  NEURX_PRETRAIN_EVAL_INTERVAL="${NEURX_PRETRAIN_EVAL_INTERVAL:-16}" \
  NEURX_PRETRAIN_SAVE_INTERVAL="${NEURX_PRETRAIN_SAVE_INTERVAL:-32}" \
  stdbuf -oL -eL "$BIN_FILE" &

pretrain_pid=$!
pretrain_started_at=$SECONDS
next_status_at=10

forward_signal() {
  kill -TERM "$pretrain_pid" 2>/dev/null || true
}
trap forward_signal INT TERM

while kill -0 "$pretrain_pid" 2>/dev/null; do
  sleep 1
  elapsed=$((SECONDS - pretrain_started_at))
  if [[ "$elapsed" -ge "$next_status_at" ]] && kill -0 "$pretrain_pid" 2>/dev/null; then
    echo "[monitor] pretrain process active: elapsed=${elapsed}s"
    next_status_at=$((next_status_at + 10))
  fi
done

set +e
wait "$pretrain_pid"
pretrain_status=$?
set -e
trap - INT TERM
exit "$pretrain_status"
