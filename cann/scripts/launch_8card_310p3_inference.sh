#!/usr/bin/env bash
set -euo pipefail

devices="${ASCEND_RT_VISIBLE_DEVICES:-0,1,2,3,4,5,6,7}"
worker_bin="${NEURX_ASCEND_WORKER_BIN:-}"
checkpoint="${NEURX_CHECKPOINT:-}"
operator_library="${NEURX_CANN_OPERATOR_LIBRARY:-}"
base_port="${NEURX_ASCEND_BASE_PORT:-8080}"

if [[ -z "${worker_bin}" || ! -x "${worker_bin}" ]]; then
  echo "error: NEURX_ASCEND_WORKER_BIN must name an executable Ascend worker" >&2
  exit 2
fi
if [[ -z "${checkpoint}" || ! -f "${checkpoint}" ]]; then
  echo "error: NEURX_CHECKPOINT does not exist: ${checkpoint:-<unset>}" >&2
  exit 2
fi
if [[ -z "${operator_library}" || ! -f "${operator_library}" ]]; then
  echo "error: NEURX_CANN_OPERATOR_LIBRARY does not exist: ${operator_library:-<unset>}" >&2
  exit 2
fi

IFS=',' read -r -a device_list <<<"${devices}"
if [[ "${#device_list[@]}" -ne 8 ]]; then
  echo "error: 310P3 eight-card launcher requires exactly 8 visible devices" >&2
  exit 2
fi

pids=()
shutdown() {
  if [[ "${#pids[@]}" -gt 0 ]]; then
    kill -TERM "${pids[@]}" 2>/dev/null || true
    wait "${pids[@]}" 2>/dev/null || true
  fi
}
trap shutdown INT TERM EXIT

for index in "${!device_list[@]}"; do
  device="${device_list[$index]}"
  port="$((base_port + index))"
  ASCEND_RT_VISIBLE_DEVICES="${device}" \
  NEURX_ASCEND_DEVICE_ID=0 \
  NEURX_HTTP_PORT="${port}" \
  NEURX_CHECKPOINT="${checkpoint}" \
  NEURX_CANN_OPERATOR_LIBRARY="${operator_library}" \
    "${worker_bin}" &
  pids+=("$!")
done

wait -n "${pids[@]}"
echo "error: an Ascend worker exited; stopping the remaining workers" >&2
exit 1
