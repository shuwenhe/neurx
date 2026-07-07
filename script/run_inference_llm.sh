#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEURX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

remap_checkpoint_path() {
  local target="$1"

  case "$target" in
    /Users/feifei/shuwen/neurx/*)
      printf '%s\n' "$NEURX_ROOT/${target#/Users/feifei/shuwen/neurx/}"
      ;;
    /Users/shuwen/shuwen/train/neurx/*)
      printf '%s\n' "$target"
      ;;
    *)
      printf '%s\n' "$target"
      ;;
  esac
}

resolve_checkpoint() {
  local candidate="$1"

  if [[ -z "$candidate" ]]; then
    return 1
  fi

  if [[ -f "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

    if [[ -d "$candidate" ]]; then
      local latest_file="$candidate/latest_checkpoint.txt"
      if [[ -f "$latest_file" ]]; then
        local latest_target
        latest_target="$(tr -d '\r\n' < "$latest_file")"
        latest_target="$(remap_checkpoint_path "$latest_target")"
        if [[ -n "$latest_target" && -e "$latest_target" ]]; then
          printf '%s\n' "$latest_target"
          return 0
        fi
      fi

    for fallback in \
      "$candidate/final_model.neurx" \
      "$candidate/model.neurx" \
      "$candidate/checkpoint.neurx"; do
      if [[ -f "$fallback" ]]; then
        printf '%s\n' "$fallback"
        return 0
      fi
    done
  fi

  return 1
}

DEFAULT_CHECKPOINT_CANDIDATES=(
  "${NEURX_INFER_CHECKPOINT_PATH:-}"
  "${NEURX_INFER_CHECKPOINT:-}"
  "$NEURX_ROOT/artifacts/checkpoints/llm_training_validation2"
  "$NEURX_ROOT/artifacts/checkpoints/llm_training"
  "$NEURX_ROOT/artifacts/checkpoints/industrial_gpt_local"
  "$NEURX_ROOT/artifacts/checkpoints/llm_s_pretrain"
)

checkpoint_path=""
checkpoint_source=""
for candidate in "${DEFAULT_CHECKPOINT_CANDIDATES[@]}"; do
  if checkpoint_path="$(resolve_checkpoint "$candidate")"; then
    checkpoint_source="$candidate"
    break
  fi
done

if [[ -z "$checkpoint_path" ]]; then
  echo "No usable checkpoint found."
  echo "Set NEURX_INFER_CHECKPOINT_PATH or create artifacts/checkpoints/llm_training/latest_checkpoint.txt"
  exit 1
fi

echo "Running NeurX inference from checkpoint"
echo "Project root : $NEURX_ROOT"
echo "Checkpoint source : ${checkpoint_source:-<unknown>}"
echo "Checkpoint path   : $checkpoint_path"
echo "Runner script     : $NEURX_ROOT/tools/run_infer_local_s.sh"
echo "Resolved command  : $NEURX_ROOT/tools/run_infer_local_s.sh \"$checkpoint_path\" \"${NEURX_INFER_SEED:-neurx }\" \"${NEURX_INFER_MAX_NEW_CHARS:-120}\""

exec "$NEURX_ROOT/tools/run_infer_local_s.sh" "$checkpoint_path" "${NEURX_INFER_SEED:-neurx }" "${NEURX_INFER_MAX_NEW_CHARS:-120}"
