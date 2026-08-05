#!/usr/bin/env bash
set -euo pipefail

neurx_root="${NEURX_ROOT:-/home/shuwen/shuwen/neurx}"
configured_model="${NEURX_CHAT_MODEL_PATH:-/home/shuwen/shuwen/posttrain}"
python_bin="${NEURX_CHAT_PYTHON:-/home/shuwen/.venv/bin/python}"
inference_script="${NEURX_POSTTRAIN_INFERENCE_SCRIPT:-/home/shuwen/shuwen/posttrain/neurx_inference.py}"
max_new_tokens="${NEURX_CHAT_MAX_NEW_TOKENS:-128}"

if [[ -f "$configured_model" ]]; then
    model_dir="$(dirname -- "$configured_model")"
else
    model_dir="$configured_model"
fi

args=(
    "$inference_script"
    --model-dir "$model_dir"
    --neurx-root "$neurx_root"
    --max-new-tokens "$max_new_tokens"
)

if [[ -n "${NEURX_CHAT_PROMPT_PATH:-}" && -f "${NEURX_CHAT_PROMPT_PATH}" ]]; then
    args+=(--history-file "$NEURX_CHAT_PROMPT_PATH")
fi

exec "$python_bin" "${args[@]}"
