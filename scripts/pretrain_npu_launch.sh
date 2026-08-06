set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
config_file="${NEURX_NPU_CLUSTER_CONFIG:-$root_dir/configs/pretrain.yaml}"
yaml_value() {
  local file="$1"
  local key="$2"
  awk -F':' -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      sub(/^[[:space:]]*/, "", $2)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
      gsub(/^["'"'"']|["'"'"']$/, "", $2)
      print $2
      exit
    }
  ' "$file"
}
yaml_list_entries() {
  local file="$1"
  local section="$2"
  awk -v section="$section" '
    $0 ~ "^[[:space:]]*" section "[[:space:]]*:[[:space:]]*$" { in_section=1; next }
    in_section && $0 ~ "^[[:space:]]*[A-Za-z0-9_]+[[:space:]]*:" { exit }
    in_section && $0 ~ "^[[:space:]]*-[[:space:]]*" {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      print line
    }
  ' "$file"
}
yaml_list_value() {
  local item="$1"
  local key="$2"
  awk -F':' -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      sub(/^[[:space:]]*/, "", $2)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
      gsub(/^["'"'"']|["'"'"']$/, "", $2)
      print $2
      exit
    }
  ' <<<"$item"
}
log_step() {
  echo "[pretrain-npu] $1"
}
if [[ "${PLATFORM:-linux}" != "linux" ]]; then
  echo "error: Ascend CANN pretraining is supported on Linux hosts only."
  echo "       Current platform: ${PLATFORM:-unknown}"
  exit 1
fi
log_step "step 1/8: locating Ascend toolkit"
ascend_home="${ASCEND_HOME_PATH:-/usr/local/Ascend/ascend-toolkit/latest}"
if [[ ! -d "$ascend_home" ]]; then
  echo "error: Ascend Toolkit not found: $ascend_home"
  echo "       Set ASCEND_HOME_PATH, then run: make pretrain-npu"
  exit 1
fi
log_step "step 2/8: locating Ascend runtime libraries"
acl_lib=""
for candidate in "$ascend_home/lib64/libascendcl.so" "$ascend_home/runtime/lib64/libascendcl.so"; do
  if [[ -f "$candidate" ]]; then
    acl_lib="$candidate"
    break
  fi
done
if [[ -z "$acl_lib" ]]; then
  echo "error: libascendcl.so was not found under $ascend_home."
  echo "       Install the CANN runtime package or correct ASCEND_HOME_PATH."
  exit 1
fi
log_step "step 3/8: checking NPU availability"
npu_smi_bin="${NPU_SMI:-$(command -v npu-smi 2>/dev/null || true)}"
if [[ -z "$npu_smi_bin" && -x /usr/local/ascend/driver/tools/npu-smi ]]; then
  npu_smi_bin=/usr/local/ascend/driver/tools/npu-smi
fi
if [[ -z "$npu_smi_bin" ]] || ! "$npu_smi_bin" info >/dev/null 2>&1; then
  echo "error: no usable Ascend NPU was detected with npu-smi."
  echo "       Check the Ascend driver and device permissions."
  exit 1
fi
log_step "step 4/8: loading cluster config"
visible_devices="${ASCEND_RT_VISIBLE_DEVICES:-${NEURX_NPU_VISIBLE_DEVICES:-0}}"
if [[ -f "$config_file" ]]; then
  visible_devices="${visible_devices:-$(yaml_value "$config_file" visible_devices)}"
fi
if [[ ! "$visible_devices" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
  echo "error: ASCEND_RT_VISIBLE_DEVICES must be a comma-separated device list."
  echo "       Received: $visible_devices"
  exit 1
fi
device_count="$(printf '%s' "$visible_devices" | awk -F, '{print NF}')"
requested_world_size="${NEURX_NPU_WORLD_SIZE:-${WORLD_SIZE:-$device_count}}"
worker_host="${NEURX_NPU_WORKER_HOST:-$(yaml_value "$config_file" worker_host)}"
worker_host="${worker_host:-root@112.29.145.15}"
worker_visible="${NEURX_NPU_WORKER_VISIBLE_DEVICES:-$(yaml_value "$config_file" worker_visible_devices)}"
worker_visible="${worker_visible:-0}"
master_addr="${NEURX_NPU_MASTER_ADDR:-$(yaml_value "$config_file" master_addr)}"
master_addr="${master_addr:-112.29.145.3}"
master_port="${NEURX_NPU_MASTER_PORT:-$(yaml_value "$config_file" master_port)}"
master_port="${master_port:-29500}"
worker_hosts=()
worker_visibles=()
if [[ -f "$config_file" ]]; then
  while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    host="$(yaml_list_value "$item" host)"
    vis="$(yaml_list_value "$item" visible_devices)"
    [[ -z "$host" ]] && continue
    worker_hosts+=("$host")
    worker_visibles+=("${vis:-0}")
  done < <(yaml_list_entries "$config_file" workers)
fi
if [[ "${#worker_hosts[@]}" -eq 0 ]]; then
  worker_hosts=("$worker_host")
  worker_visibles=("$worker_visible")
fi
if [[ -f "$config_file" ]]; then
  yaml_world_size="$(yaml_value "$config_file" world_size)"
  if [[ -n "$yaml_world_size" ]]; then
    requested_world_size="$yaml_world_size"
  else
    requested_world_size="$((1 + ${#worker_hosts[@]}))"
  fi
fi
log_step "step 5/8: validating world size and HCCL runtime"
if [[ ! "$requested_world_size" =~ ^[0-9]+$ ]] || [[ "$requested_world_size" -lt 1 ]]; then
  echo "error: WORLD_SIZE must be a positive integer."
  echo "       Received: $requested_world_size"
  exit 1
fi
log_step "step 6/8: preparing pretrain manifest and runtime environment"
if [[ "$requested_world_size" -gt 1 && "${#worker_hosts[@]}" -lt 1 ]]; then
  echo "error: world size > 1 but no workers were configured."
  exit 1
fi
configured_world_size=$((1 + ${#worker_hosts[@]}))
if [[ "$requested_world_size" -ne "$configured_world_size" ]]; then
  echo "[pretrain-npu] note: configured workers imply WORLD_SIZE=$configured_world_size; using requested WORLD_SIZE=$requested_world_size"
fi
config="${NEURX_NPU_PRETRAIN_CONFIG:-$(yaml_value "$config_file" npu_pretrain_config)}"
config="${config:-cann/configs/ascend_910b_train.json}"
if [[ ! -f "$config" ]]; then
  echo "error: NPU pretrain config not found: $config"
  exit 1
fi
if [[ "$requested_world_size" -gt 1 ]]; then
  hccl_lib=""
  for candidate in \
    "$ascend_home/lib64/libhccl.so" \
    "$ascend_home/runtime/lib64/libhccl.so" \
    "$ascend_home/hccl/lib64/libhccl.so" \
    "$ascend_home/aarch64-linux/lib64/libhccl.so" \
    "$ascend_home/lib64/libhccl_v2.so" \
    "$ascend_home/lib64/libhccl_fwk.so" \
    "$ascend_home/lib64/libhccl_legacy.so" \
    "$ascend_home/lib64/libhccl_plf.so"; do
    if [[ -f "$candidate" ]]; then
      hccl_lib="$candidate"
      break
    fi
  done
  if [[ -z "$hccl_lib" ]]; then
    echo "error: multi-NPU pretraining requested but no HCCL runtime library was found."
    exit 1
  fi
fi
mkdir -p "${NEURX_PRETRAIN_OUTPUT_DIR:-$root_dir/checkpoint/NeurX-1.3}/logs"
echo "=== NeurX Ascend NPU Pretraining ==="
echo "[pretrain-npu] toolkit: $ascend_home"
echo "[pretrain-npu] runtime: $acl_lib"
echo "[pretrain-npu] visible devices: $visible_devices ($device_count)"
echo "[pretrain-npu] requested world size: $requested_world_size"
echo "[pretrain-npu] config: $config"
export ASCEND_HOME_PATH="$ascend_home"
export PATH="$ascend_home/bin:$ascend_home/compiler/ccec_compiler/bin:$PATH"
export LD_LIBRARY_PATH="$ascend_home/lib64:$ascend_home/runtime/lib64:$ascend_home/compiler/lib64:${LD_LIBRARY_PATH:-}"
export ASCEND_OPP_PATH="${ASCEND_OPP_PATH:-$ascend_home/opp}"
export ASCEND_AICPU_PATH="${ASCEND_AICPU_PATH:-$ascend_home}"
log_step "step 7/8: building pretrain manifest"
make build-pretrain-manifest-s
common_env=(
  "NEURX_ROOT=$root_dir"
  "NEURX_COMPUTE_BACKEND=cann"
  "NEURX_DDP_BACKEND=hccl"
  "NEURX_PRETRAIN_BACKEND=hccl"
  "DDP_BACKEND=hccl"
  "NEURX_NPU_PRETRAIN_CONFIG=$config"
  "NEURX_ASCEND_SOC_VERSION=${NEURX_ASCEND_SOC_VERSION:-Ascend910B1}"
  "NEURX_NPU_DEVICE_COUNT=$device_count"
  "NEURX_NPU_WORLD_SIZE=$requested_world_size"
  "ASCEND_RT_VISIBLE_DEVICES=$visible_devices"
  "WORLD_SIZE=$requested_world_size"
  "NEURX_PRETRAIN_MANIFEST=$root_dir/dataset/pretrain/manifest.json"
  "NEURX_PRETRAIN_MODEL_NAME=${NEURX_PRETRAIN_MODEL_NAME:-NeurX-1.3}"
  "NEURX_PRETRAIN_OUTPUT_DIR=${NEURX_PRETRAIN_OUTPUT_DIR:-$root_dir/checkpoint/NeurX-1.3}"
  "NEURX_PRETRAIN_STEPS=${NEURX_PRETRAIN_STEPS:-1000000000}"
  "NEURX_PRETRAIN_MICRO_BATCH=${NEURX_PRETRAIN_MICRO_BATCH:-4}"
  "NEURX_PRETRAIN_SEQ_LEN=${NEURX_PRETRAIN_SEQ_LEN:-256}"
  "NEURX_PRETRAIN_LR=${NEURX_PRETRAIN_LR:-0.0002}"
  "NEURX_PRETRAIN_SAVE_INTERVAL=${NEURX_PRETRAIN_SAVE_INTERVAL:-10000}"
)
if [[ "$requested_world_size" -gt 1 ]]; then
  log_step "step 8/8: checking workers and synchronizing code"
  for idx in "${!worker_hosts[@]}"; do
    host="${worker_hosts[$idx]}"
    vis="${worker_visibles[$idx]}"
    log_step "worker $((idx + 1))/$(( ${#worker_hosts[@]} )): probing $host"
    if ! ssh -o batch_mode=yes -o connect_timeout=10 -o strict_host_key_checking=no "$host" "$npu_smi_bin info >/dev/null 2>&1"; then
      echo "error: worker host is not reachable or npu-smi failed on $host."
      echo "       Check SSH access, NPU driver state, and worker host permissions."
      exit 1
    fi
    log_step "worker $((idx + 1))/$(( ${#worker_hosts[@]} )): syncing code to $host"
    if ! ssh -o strict_host_key_checking=no "$host" "mkdir -p '$root_dir'"; then
      echo "error: failed to create remote code directory on $host."
      exit 1
    fi
    if ! rsync -az --delete \
      --exclude '.git' \
      --exclude 'artifacts' \
      --exclude 'checkpoint' \
      --exclude '.agents' \
      --exclude '.codex' \
      "$root_dir/" "$host:$root_dir/"; then
      echo "error: failed to sync code to worker $host."
      exit 1
    fi
    log_step "worker $((idx + 1))/$(( ${#worker_hosts[@]} )): building s_ir_runner on $host"
    if ! ssh -o strict_host_key_checking=no "$host" "cd '$root_dir' && make build-s-ir-runner"; then
      echo "error: failed to build s_ir_runner on $host."
      exit 1
    fi
    rank=$((idx + 1))
    log_step "worker $((idx + 1))/$(( ${#worker_hosts[@]} )): starting rank=$rank on $host"
    remote_cmd="cd '$root_dir' && env ${common_env[*]} NEURX_NPU_ROLE=worker RANK=$rank LOCAL_RANK=0 MASTER_ADDR='$master_addr' MASTER_PORT='$master_port' NEURX_NPU_MASTER_ADDR='$master_addr' NEURX_NPU_MASTER_PORT='$master_port' ASCEND_RT_VISIBLE_DEVICES='$vis' NEURX_NPU_VISIBLE_DEVICES='$vis' WORLD_SIZE='$requested_world_size' make run-large-pretrain-s"
    ssh -o strict_host_key_checking=no "$host" "bash -lc $(printf '%q' "$remote_cmd")" &
  done
fi
log_step "starting master locally (rank=0)"
log_step "building s_ir_runner locally"
make build-s-ir-runner
env "${common_env[@]}" NEURX_NPU_ROLE=master RANK=0 LOCAL_RANK=0 MASTER_ADDR="$master_addr" MASTER_PORT="$master_port" NEURX_NPU_MASTER_ADDR="$master_addr" NEURX_NPU_MASTER_PORT="$master_port" make run-large-pretrain-s
