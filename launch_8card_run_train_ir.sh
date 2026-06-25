#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEURX_DIR="${NEURX_DIR:-$ROOT_DIR}"
S_ROOT="${S_ROOT:-/app/train/s}"
RUN_SCRIPT="$NEURX_DIR/run_train_model_ir.sh"
IR_FILE="${IR_FILE:-$NEURX_DIR/build/train_model.ir}"
LOG_DIR="${LOG_DIR:-/tmp/neurx_train_logs}"
mkdir -p "$LOG_DIR" "$ROOT_DIR/.run" "$NEURX_DIR/build"
PIDS_FILE="$ROOT_DIR/.run/8card_pids.txt"
: >"$PIDS_FILE"

# source Ascend env if present
for env_file in /usr/local/Ascend/ascend-toolkit/set_env.sh /usr/local/Ascend/cann-8.5.0/set_env.sh; do
  if [[ -f "$env_file" ]]; then
    # shellcheck disable=SC1090
    source "$env_file"
    break
  fi
done

RANK_TABLE_FILE="${RANK_TABLE_FILE:-/app/train/neurx-code/rank_table.json}"

echo "Preparing IR: $IR_FILE"
if [ ! -f "$IR_FILE" ]; then
  if [ "$(uname -m)" = "aarch64" ]; then
    S_COMPILER=$(ls "$S_ROOT/bin"/s_arm64* 2>/dev/null | head -n1 || true)
  else
    S_COMPILER=$(ls "$S_ROOT/bin"/s_x86_64* 2>/dev/null | head -n1 || true)
  fi
  if [ -z "$S_COMPILER" ]; then
    S_COMPILER="$S_ROOT/bin/s"
  fi
  echo "Using s compiler: $S_COMPILER"
  "$S_COMPILER" "$NEURX_DIR/train_model.s" "$IR_FILE"
fi

DEVICE_IDS=()
if [ -f "$RANK_TABLE_FILE" ]; then
  echo "Found rank table: $RANK_TABLE_FILE"
    # parse JSON to extract (rank,device_id) pairs robustly using a temp file
    TMP_OUT=$(mktemp)
    python3 - "$RANK_TABLE_FILE" > "$TMP_OUT" <<'PY'
  import json,sys
  path = sys.argv[1]
  obj = json.load(open(path))
  pairs = []
  def collect(o):
    if isinstance(o, dict):
      if 'rank' in o and ('device' in o or 'device_id' in o or 'deviceId' in o or 'id' in o):
        try:
          rank = int(o.get('rank'))
        except:
          rank = None
        for k in ('device','device_id','deviceId','id'):
          if k in o:
            try:
              dev = int(o[k])
            except:
              dev = None
            if rank is not None and dev is not None:
              pairs.append((rank,dev))
      for v in o.values():
        collect(v)
    elif isinstance(o, list):
      for v in o:
        collect(v)
  collect(obj)
  if not pairs:
    # fallback: find top-level list of device ids
    def find_ids(o):
      if isinstance(o, list):
        if all(isinstance(x,int) for x in o):
          return o
        for v in o:
          r=find_ids(v)
          if r: return r
      elif isinstance(o, dict):
        for v in o.values():
          r=find_ids(v)
          if r: return r
      return None
    ids = find_ids(obj) or []
    for i,d in enumerate(ids): pairs.append((i,int(d)))
  pairs.sort()
    for r,d in pairs:
        print(d)
PY
    mapfile -t LINES < "$TMP_OUT"
    rm -f "$TMP_OUT"
  WORLD_SIZE=${#DEVICE_IDS[@]}
  if [ "$WORLD_SIZE" -eq 0 ]; then
    echo "Failed to extract device ids from rank table" >&2
    exit 1
  fi
else
  WORLD_SIZE="${WORLD_SIZE:-8}"
fi

echo "Starting $WORLD_SIZE workers, logs -> $LOG_DIR"

for ((R=0; R<WORLD_SIZE; R++)); do
  if [ ${#DEVICE_IDS[@]} -gt 0 ]; then
    ASCEND_DEVICE_ID="${DEVICE_IDS[$R]}"
  else
    ASCEND_DEVICE_ID="$R"
  fi
  LOG_FILE="$LOG_DIR/rank_${R}.log"
  # Use a per-rank runner binary to avoid build race
  RUNNER_BIN="$NEURX_DIR/build/s_ir_runner_rank_${R}"
  env NEURX_DIR="$NEURX_DIR" S_ROOT="$S_ROOT" WORLD_SIZE="$WORLD_SIZE" RANK="$R" ASCEND_DEVICE_ID="$ASCEND_DEVICE_ID" RUNNER_BIN="$RUNNER_BIN" \
    bash "$RUN_SCRIPT" >"$LOG_FILE" 2>&1 &
  PID=$!
  echo "$PID $R $LOG_FILE" >> "$PIDS_FILE"
  echo "Launched rank $R pid $PID -> $LOG_FILE"
  sleep 0.5
done

echo "All launched. PIDs written to $PIDS_FILE"
echo "To monitor logs: tail -F $LOG_DIR/*.log"

exit 0
