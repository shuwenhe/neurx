#!/usr/bin/env bash
set -Eeuo pipefail



ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOSTFILE="${NEURX_HOSTFILE:-${ROOT}/configs/pretrain.hosts}"
GPUS_PER_NODE="${NEURX_GPUS_PER_NODE:-}"
MASTER_ADDR="${MASTER_ADDR:-$(awk 'NF && $1 !~ /^#/ {print $1; exit}' "$HOSTFILE")}"
MASTER_PORT="${MASTER_PORT:-29500}"
SHARED_ID="${NEURX_SHARED_NCCL_ID_FILE:-${ROOT}/artifacts/nccl/unique_id}"
OUT="${NEURX_PRETRAIN_OUTPUT_DIR:-${ROOT}/checkpoint/NeurX-1.3}"
case "${NEURX_PRETRAIN_RESUME:-auto}" in
  0|no|false|off) RESUME_ENABLED=0 ;;
  *) RESUME_ENABLED=1 ;;
esac

[[ -r "$HOSTFILE" ]] || { echo "hostfile not found: $HOSTFILE" >&2; exit 2; }
mapfile -t HOSTS < <(awk 'NF && $1 !~ /^#/ {print $1 " " $2}' "$HOSTFILE")
(( ${#HOSTS[@]} > 0 )) || { echo "hostfile has no nodes: $HOSTFILE" >&2; exit 2; }

declare -a PIDS=()
cleanup() {
  trap - EXIT INT TERM
  for pid in "${PIDS[@]:-}"; do kill "$pid" 2>/dev/null || true; done
  for node in "${HOSTS[@]}"; do
    host="${node%% *}"
    if [[ "$host" != "localhost" && "$host" != "127.0.0.1" && "$host" != "$(hostname)" ]]; then
      ssh "$host" "pkill -TERM -f 'neurx_cuda_train_bridge'" 2>/dev/null || true
    fi
  done
}
trap cleanup EXIT INT TERM

world=0
for node in "${HOSTS[@]}"; do
  gpus="${node#* }"
  if [[ "$gpus" == "$node" || ! "$gpus" =~ ^[0-9]+$ ]]; then
    gpus="${GPUS_PER_NODE:-$(nvidia-smi -L 2>/dev/null | wc -l)}"
  fi
  [[ "$gpus" =~ ^[1-9][0-9]*$ ]] || { echo "cannot determine GPU count for $node" >&2; exit 2; }
  world=$((world + gpus))
done
mkdir -p "$(dirname "$SHARED_ID")" "$OUT"
rm -f "$SHARED_ID" "$SHARED_ID.tmp"
echo "[multinode] nodes=${#HOSTS[@]} world_size=$world master=${MASTER_ADDR}:${MASTER_PORT}"
echo "[multinode] shared NCCL id: $SHARED_ID"

base_env=(
  "NEURX_ROOT=$ROOT"
  "NEURX_PRETRAIN_OUTPUT_DIR=$OUT"
  "NEURX_NCCL_ID_FILE=$SHARED_ID"
  "NEURX_PRETRAIN_MANIFEST=${NEURX_PRETRAIN_MANIFEST:-${ROOT}/dataset/pretrain/manifest.json}"
  "NEURX_PRETRAIN_STEPS=${NEURX_PRETRAIN_STEPS:-1000000000}"
  "NEURX_PRETRAIN_MICRO_BATCH=${NEURX_PRETRAIN_MICRO_BATCH:-1}"
  "NEURX_PRETRAIN_SEQ_LEN=${NEURX_PRETRAIN_SEQ_LEN:-256}"
  "NEURX_PRETRAIN_LR=${NEURX_PRETRAIN_LR:-0.0002}"
  "NEURX_PRETRAIN_LOG_INTERVAL=${NEURX_PRETRAIN_LOG_INTERVAL:-10}"
  "NEURX_PRETRAIN_SAVE_INTERVAL=${NEURX_PRETRAIN_SAVE_INTERVAL:-100}"
  "NEURX_TRANSFORMER_DIM=${NEURX_TRANSFORMER_DIM:-1024}"
  "NEURX_TRANSFORMER_HEADS=${NEURX_TRANSFORMER_HEADS:-16}"
  "NEURX_TRANSFORMER_FFN=${NEURX_TRANSFORMER_FFN:-4096}"
  "NEURX_TRANSFORMER_NUM_LAYERS=${NEURX_TRANSFORMER_NUM_LAYERS:-24}"
  "NEURX_GRADIENT_ACCUMULATION_STEPS=${NEURX_GRADIENT_ACCUMULATION_STEPS:-8}"
  "NEURX_PRETRAIN_RESUME=$RESUME_ENABLED"
  "NEURX_TOKENIZER_VOCAB=${NEURX_TOKENIZER_VOCAB:-${ROOT}/data/corpus/vocab.json}"
  "NEURX_TOKENIZER_MERGES=${NEURX_TOKENIZER_MERGES:-${ROOT}/data/corpus/merges.txt}"
  "NEURX_PRETRAIN_SHARD_LIST_FILE=${NEURX_PRETRAIN_SHARD_LIST_FILE:-${ROOT}/artifacts/build/run_large_pretrain/shard_list.txt}"
  "MASTER_ADDR=$MASTER_ADDR" "MASTER_PORT=$MASTER_PORT" "WORLD_SIZE=$world"
)
rank=0
for node in "${HOSTS[@]}"; do
  host="${node%% *}"; gpus="${node#* }"
  if [[ "$gpus" == "$node" || ! "$gpus" =~ ^[0-9]+$ ]]; then
    gpus="${GPUS_PER_NODE:-$(nvidia-smi -L 2>/dev/null | wc -l)}"
  fi
  for ((local=0; local<gpus; local++)); do

    if (( world == 1 )); then
      ckpt_path="$OUT/transformer_v2.ckpt"
    else
      ckpt_path="$OUT/rank_${rank}/transformer_v2.ckpt"
    fi
    cmd=("env" "${base_env[@]}" "RANK=$rank" "LOCAL_RANK=$local"
      "CUDA_VISIBLE_DEVICES=$local"
      "NEURX_PRETRAIN_RESUME_FROM=$ckpt_path"
      "${ROOT}/artifacts/build/cuda_train/neurx_cuda_train_bridge")
    echo "[multinode] rank=$rank host=$host local_rank=$local checkpoint=$ckpt_path"
    if [[ "$host" == "localhost" || "$host" == "127.0.0.1" || "$host" == "$(hostname)" ]]; then
      if (( RESUME_ENABLED )) && [[ -f "$ckpt_path" ]]; then
        echo "[multinode] rank=$rank transformer-v2 checkpoint found; automatic resume enabled"
      else
        echo "[multinode] rank=$rank no usable transformer-v2 checkpoint; starting fresh"
      fi

      if (( ${#HOSTS[@]} == 1 )); then

        "${cmd[@]}" 2>&1 | tee -a "${OUT}/rank_${rank}.log" &
      else

        "${cmd[@]}" >"${OUT}/rank_${rank}.log" 2>&1 &
      fi
    else
      printf -v remote_cmd '%q ' "${cmd[@]}"
      ssh "$host" "cd $(printf '%q' "$ROOT") && $remote_cmd" >"${OUT}/rank_${rank}.log" 2>&1 &
    fi
    PIDS+=("$!")
    rank=$((rank + 1))
  done
done

status=0
for pid in "${PIDS[@]}"; do wait "$pid" || status=$?; done
exit "$status"
