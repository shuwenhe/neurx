#!/usr/bin/env bash
set -euo pipefail

usage(){
  cat <<EOF
Usage: $0 [--config path] [--steps N]

--config: YAML config path (default: workflows/robotics/train/config/sample.yaml)
--steps: override max_steps from config

Workflow-only standard keys also recognized:
- eval_every
- save_every
EOF
}

CONFIG="$(pwd)/workflows/robotics/train/config/sample.yaml"
STEPS_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG="$2"; shift 2;;
    --steps)
      STEPS_OVERRIDE="$2"; shift 2;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

if [[ ! -f "$CONFIG" ]]; then
  echo "Config not found: $CONFIG"
  exit 1
fi

OBS_DIM="$(awk -F":" '/^obs_dim[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
LATENT_DIM="$(awk -F":" '/^latent_dim[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
ACT_DIM="$(awk -F":" '/^act_dim[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
MAX_STEPS="$(awk -F":" '/^max_steps[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
SAMPLE_COUNT="$(awk -F":" '/^sample_count[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
EVAL_EVERY="$(awk -F":" '/^eval_every[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
SAVE_EVERY="$(awk -F":" '/^save_every[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
LEARNING_RATE="$(awk -F":" '/^learning_rate[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
TASK_NAME="$(awk -F":" '/^task_name[[:space:]]*:/ {sub(/^[[:space:]]*/, "", $2); gsub(/^"|"$/, "", $2); print $2; exit}' "$CONFIG" || true)"

# Backward-compatible fallbacks from old MVP keys.
if [[ -z "$OBS_DIM" ]]; then
  OBS_DIM="$(awk -F":" '/^batch_size[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
fi
if [[ -z "$LATENT_DIM" ]]; then
  LATENT_DIM="$(awk -F":" '/^seq_len[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
fi

if [[ -n "$STEPS_OVERRIDE" ]]; then
  MAX_STEPS="$STEPS_OVERRIDE"
fi

if [[ -z "$OBS_DIM" ]]; then OBS_DIM=8; fi
if [[ -z "$LATENT_DIM" ]]; then LATENT_DIM=16; fi
if [[ -z "$ACT_DIM" ]]; then ACT_DIM=4; fi
if [[ -z "$MAX_STEPS" ]]; then MAX_STEPS=16; fi
if [[ -z "$SAMPLE_COUNT" ]]; then SAMPLE_COUNT=64; fi
if [[ -z "$EVAL_EVERY" ]]; then EVAL_EVERY=8; fi
if [[ -z "$SAVE_EVERY" ]]; then SAVE_EVERY=16; fi
if [[ -z "$LEARNING_RATE" ]]; then LEARNING_RATE=0.001; fi
if [[ -z "$TASK_NAME" ]]; then TASK_NAME="robotics_workflow_default"; fi

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$ROOT_DIR" ]]; then
  ROOT_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
fi
cd "$ROOT_DIR"

TMP_S="$(mktemp /tmp/neurx_robotics_workflow_run.XXXXXX.s)"
TMP_IR="$(mktemp /tmp/neurx_robotics_workflow_run.XXXXXX.ir)"
cleanup(){
  rm -f "$TMP_S" "$TMP_IR"
}
trap cleanup EXIT

cat > "$TMP_S" <<SFILE
package neurx.workflows.robotics.train.run_tmp

use neurx.workflows.robotics.train.pipeline_runner.{run_robotics_training_with_params}

func main() int {
    run_robotics_training_with_params(${OBS_DIM}, ${LATENT_DIM}, ${ACT_DIM}, ${MAX_STEPS}, ${SAMPLE_COUNT}, ${LEARNING_RATE}, "${TASK_NAME}")
    0
}
SFILE

make s-compile-runtime
s "$TMP_S" "$TMP_IR"

echo "Ran robotics workflow with obs=${OBS_DIM}, latent=${LATENT_DIM}, act=${ACT_DIM}, steps=${MAX_STEPS}, samples=${SAMPLE_COUNT}, eval_every=${EVAL_EVERY}, save_every=${SAVE_EVERY}, lr=${LEARNING_RATE}, task=${TASK_NAME}"
