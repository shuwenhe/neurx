#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="${SCRIPT_DIR}"
CONFIG_FILE="${NEURX_ROOT}/configs/70b_training.json"
SCALE="${NEURX_70B_SCALE:-xl}"
NUM_GPUS="${NEURX_70B_NUM_GPUS:-8}"
WORK_DIR="${NEURX_ROOT}/build/70b_training"
LOG_DIR="${WORK_DIR}/logs"
mkdir -p "${WORK_DIR}" "${LOG_DIR}"

echo "🚀 NeurX 70B training launcher"
echo "════════════════════════════════════════════════════════"
echo "Config: ${CONFIG_FILE}"
echo "Scale: ${SCALE}"
echo "GPUs: ${NUM_GPUS}"
echo "Work dir: ${WORK_DIR}"
echo ""

if [ ! -f "${CONFIG_FILE}" ]; then
  echo "✗ Missing config: ${CONFIG_FILE}" >&2
  exit 1
fi

if [ ! -f "${NEURX_ROOT}/train/neurx_foundation_model.s" ]; then
  echo "✗ Missing foundation model source: ${NEURX_ROOT}/train/neurx_foundation_model.s" >&2
  exit 1
fi

if [ ! -f "${NEURX_ROOT}/model/llm/gpt.s" ]; then
  echo "✗ Missing GPT model source: ${NEURX_ROOT}/model/llm/gpt.s" >&2
  exit 1
fi

if command -v nvidia-smi >/dev/null 2>&1; then
  GPU_COUNT="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | wc -l | tr -d ' ')"
  echo "Detected GPUs: ${GPU_COUNT}"
  if [ "${GPU_COUNT}" -lt "${NUM_GPUS}" ]; then
    echo "Warning: requested ${NUM_GPUS} GPUs, but only ${GPU_COUNT} detected"
    NUM_GPUS="${GPU_COUNT}"
  fi
fi

python3 - "${CONFIG_FILE}" "${WORK_DIR}/launch_summary.txt" <<'PY'
import json
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
summary_path = pathlib.Path(sys.argv[2])
cfg = json.loads(config_path.read_text())
lines = [
    "NeurX 70B launch summary",
    f"model_name={cfg.get('model_name')}",
    f"hidden_size={cfg.get('hidden_size')}",
    f"num_hidden_layers={cfg.get('num_hidden_layers')}",
    f"num_attention_heads={cfg.get('num_attention_heads')}",
    f"world_size={cfg.get('distributed', {}).get('world_size')}",
    f"tensor_parallel_size={cfg.get('distributed', {}).get('tensor_parallel_size')}",
    f"pipeline_parallel_stages={cfg.get('distributed', {}).get('pipeline_parallel_stages')}",
]
summary_path.write_text("\n".join(lines) + "\n")
print("\n".join(lines))
PY

cat > "${WORK_DIR}/launch_command.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cd '${NEURX_ROOT}'
export NEURX_70B_SCALE='${SCALE}'
export NEURX_70B_NUM_GPUS='${NUM_GPUS}'
bash script/train_foundation_model.sh '${SCALE}' '${NUM_GPUS}'
EOF
chmod +x "${WORK_DIR}/launch_command.sh"

if [ "${NEURX_70B_PREPARE_ONLY:-0}" = "1" ]; then
  echo ""
  echo "Prepare-only mode enabled."
  echo "Launch command written to: ${WORK_DIR}/launch_command.sh"
  exit 0
fi

echo ""
echo "Starting 70B training through foundation model pipeline..."
exec bash "${NEURX_ROOT}/script/train_foundation_model.sh" "${SCALE}" "${NUM_GPUS}"
