#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${NEURX_MOBILE_BUILD_DIR:-${MOBILE_DIR}/build/android-arm64-v8a}"
PACKAGE_NAME="${NEURX_ANDROID_PACKAGE_NAME:-com.neurx.mobile}"
ACTIVITY_NAME="${NEURX_ANDROID_ACTIVITY_NAME:-org.qtproject.qt.android.bindings.QtActivity}"
SKIP_LAUNCH="${NEURX_ANDROID_SKIP_LAUNCH:-0}"

resolve_adb() {
  if command -v adb >/dev/null 2>&1; then
    command -v adb
    return 0
  fi

  local android_home="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [ -n "${android_home}" ] && [ -x "${android_home}/platform-tools/adb" ]; then
    printf '%s' "${android_home}/platform-tools/adb"
    return 0
  fi
  if [ -n "${android_home}" ] && [ -x "${android_home}/platform-tools/adb.exe" ]; then
    printf '%s' "${android_home}/platform-tools/adb.exe"
    return 0
  fi

  return 1
}

find_apk() {
  local candidate
  for candidate in \
    "$(find "${BUILD_DIR}" -type f -name '*release-signed*.apk' | sort | tail -n 1)" \
    "$(find "${BUILD_DIR}" -type f -name '*release*.apk' | sort | tail -n 1)" \
    "$(find "${BUILD_DIR}" -type f -name '*debug*.apk' | sort | tail -n 1)" \
    "$(find "${BUILD_DIR}" -type f -name '*.apk' | sort | tail -n 1)"
  do
    if [ -n "${candidate}" ] && [ -f "${candidate}" ] && [[ "${candidate}" != *"unsigned.apk" ]]; then
      printf '%s' "${candidate}"
      return 0
    fi
  done
  return 1
}

ADB="$(resolve_adb)"

if [ ! -d "${BUILD_DIR}" ]; then
  echo "Android build directory not found: ${BUILD_DIR}" >&2
  echo "Run scripts/build_android.sh first." >&2
  exit 1
fi

APK_PATH="$(find_apk)"

if [ -z "${APK_PATH}" ]; then
  echo "No APK found under: ${BUILD_DIR}" >&2
  echo "Build the mobile target first, then retry." >&2
  exit 1
fi

if [ -z "${ANDROID_SERIAL:-}" ]; then
  DEVICE_SERIAL="$("${ADB}" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
else
  DEVICE_SERIAL="${ANDROID_SERIAL}"
fi

if [ -z "${DEVICE_SERIAL}" ]; then
  echo "No connected Android device found. Enable USB debugging on your Xiaomi phone and reconnect it." >&2
  exit 1
fi

"${ADB}" -s "${DEVICE_SERIAL}" install -r -d "${APK_PATH}"

if [[ "${SKIP_LAUNCH}" != "1" ]]; then
  "${ADB}" -s "${DEVICE_SERIAL}" shell am start -n "${PACKAGE_NAME}/${ACTIVITY_NAME}" -a android.intent.action.MAIN -c android.intent.category.LAUNCHER
fi
