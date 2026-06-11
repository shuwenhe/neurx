#!/usr/bin/env bash

set -euo pipefail

ASCEND_HOME_PATH="${ASCEND_HOME_PATH:-/usr/local/Ascend/ascend-toolkit/latest}"
export ASCEND_HOME_PATH

if [[ ! -d "${ASCEND_HOME_PATH}" ]]; then
  echo "Ascend toolkit not found: ${ASCEND_HOME_PATH}" >&2
  echo "Set ASCEND_HOME_PATH before sourcing cann/env.sh" >&2
  if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    return 1
  fi
  exit 1
fi

prepend_path() {
  local value="$1"
  local current="$2"
  if [[ -z "${current}" ]]; then
    printf '%s' "${value}"
    return
  fi
  printf '%s:%s' "${value}" "${current}"
}

export PATH="$(prepend_path "${ASCEND_HOME_PATH}/bin" "${PATH}")"
export PATH="$(prepend_path "${ASCEND_HOME_PATH}/compiler/ccec_compiler/bin" "${PATH}")"
export LD_LIBRARY_PATH="$(prepend_path "${ASCEND_HOME_PATH}/lib64" "${LD_LIBRARY_PATH:-}")"
export LD_LIBRARY_PATH="$(prepend_path "${ASCEND_HOME_PATH}/runtime/lib64" "${LD_LIBRARY_PATH}")"
export LD_LIBRARY_PATH="$(prepend_path "${ASCEND_HOME_PATH}/compiler/lib64" "${LD_LIBRARY_PATH}")"
export ASCEND_OPP_PATH="${ASCEND_OPP_PATH:-${ASCEND_HOME_PATH}/opp}"
export ASCEND_AICPU_PATH="${ASCEND_AICPU_PATH:-${ASCEND_HOME_PATH}}"
export ASCEND_SLOG_PRINT_TO_STDOUT="${ASCEND_SLOG_PRINT_TO_STDOUT:-0}"
