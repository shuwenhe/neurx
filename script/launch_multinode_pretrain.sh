#!/usr/bin/env bash
set -Eeuo pipefail

# Hostfile format: one node per line, "host gpus". The project directory and
# NEURX_SHARED_NCCL_ID_FILE must be visible at the same path on every node.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOSTFILE="${NEURX_HOSTFILE:-${ROOT}/configs/pretrain.hosts}"
GPUS_PER_NODE="${NEURX_GPUS_PER_NODE:-}"
MASTER_ADDR="${MASTER_ADDR:-$(awk 'NF && $1 !~ /^#/ {print $1; exit}' "$HOSTFILE")}"
MASTER_PORT="${MASTER_PORT:-29500}"
SHARED_ID="${NEURX_SHARED_NCCL_ID_FILE:-${ROOT}/artifacts/nccl/unique_id}"
OUT="${NEURX_PRETRAIN_OUTPUT_DIR:-${ROOT}/checkpoint/NeurX-1.3}"

[[ -r "$HOSTFILE" ]] || { echo "hostfile not found: $HOSTFILE" >&2; exit 2; }
mapfile -t HOSTS < <(awk 'NF && $1 !~ /^#/ {print $1 " " $2}' "$HOSTFILE")
(( ${#HOSTS[@]} > 0 )) || { echo "hostfile has no nodes: $HOSTFILE" >&2; exit 2; }

declare -a PIDS=()
cleanup() {
  trap - EXIT INT TERM
  for pid in "${PIDS[@]:-}"; do kill "$pid" 2>/dev/null || true; done
  for node in "${HOSTS[@]}"; do
    host="${node%% *}"
    ssh "$host" "pkill -TERM -f 'neurx_cuda_train_bridge'" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

world=0
for node in "${HOSTS[@]}"; do
  gpus="${node#* }"
  [[ "$gpus" != "$node" && "$gpus" =~ ^[0-9]+$ ]] || gpus="${GPUS_PER_NODE:?set GPU count in hostfile or NEURX_GPUS_PER_NODE}"
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
  "NEURX_PRETRAIN_SHARD_LIST_FILE=${ROOT}/artifacts/build/run_large_pretrain/shard_list.txt"
  "MASTER_ADDR=$MASTER_ADDR" "MASTER_PORT=$MASTER_PORT" "WORLD_SIZE=$world"
)
rank=0
for node in "${HOSTS[@]}"; do
  host="${node%% *}"; gpus="${node#* }"
  for ((local=0; local<gpus; local++)); do
    cmd=("env" "${base_env[@]}" "RANK=$rank" "LOCAL_RANK=$local"
      "CUDA_VISIBLE_DEVICES=$local"
      "NEURX_PRETRAIN_RESUME_FROM=$OUT/rank_${rank}/transformer_v2.ckpt"
      "${ROOT}/artifacts/build/cuda_train/neurx_cuda_train_bridge")
    echo "[multinode] rank=$rank host=$host local_rank=$local"
    if [[ "$host" == "localhost" || "$host" == "127.0.0.1" || "$host" == "$(hostname)" ]]; then
      "${cmd[@]}" >"${OUT}/rank_${rank}.log" 2>&1 &
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
