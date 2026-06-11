#!/usr/bin/env bash

is_runnable_s_candidate() {
  local candidate="${1:-}"
  if [[ -z "$candidate" ]]; then
    return 1
  fi

  case "$candidate" in
    *.cmd|*.bat|*.exe)
      [[ -f "$candidate" ]]
      ;;
    *)
      [[ -x "$candidate" ]]
      ;;
  esac
}

resolve_s_bin() {
  local root_dir="${1:-}"
  local candidate=""

  if is_runnable_s_candidate "${S_BIN:-}"; then
    printf '%s\n' "${S_BIN}"
    return 0
  fi

  if command -v s >/dev/null 2>&1; then
    command -v s
    return 0
  fi

  for candidate in \
    "${S_ROOT:-}/bin/s.cmd" \
    "${S_ROOT:-}/bin/s.exe" \
    "${S_ROOT:-}/bin/s" \
    "${S_ROOT:-}/bin/s_x86_64" \
    "${HOME:-}/s/bin/s.cmd" \
    "${HOME:-}/s/bin/s.exe" \
    "${HOME:-}/s/bin/s" \
    "${HOME:-}/s/bin/s_x86_64" \
    "${root_dir}/../s/bin/s.cmd" \
    "${root_dir}/../s/bin/s.exe" \
    "${root_dir}/../s/bin/s" \
    "${root_dir}/../s/bin/s_x86_64"
  do
    if is_runnable_s_candidate "${candidate}"; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}
