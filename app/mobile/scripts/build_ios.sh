#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${NEURX_MOBILE_BUILD_DIR:-${MOBILE_DIR}/build/ios-arm64}"
QT6_IOS_DIR="${Qt6_IOS_DIR:-${Qt6_DIR:-}}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS builds require macOS."
  exit 1
fi

if [[ -z "${QT6_IOS_DIR}" || ! -f "${QT6_IOS_DIR}/Qt6Config.cmake" ]]; then
  echo "Set Qt6_IOS_DIR to your Qt for iOS cmake directory."
  exit 1
fi

mkdir -p "${BUILD_DIR}"

cmake -S "${MOBILE_DIR}" -B "${BUILD_DIR}" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_BUILD_TYPE=Release \
  -DQt6_DIR="${QT6_IOS_DIR}"

cmake --build "${BUILD_DIR}" --config Release
