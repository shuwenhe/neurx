#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ANDROID_ABI="${NEURX_ANDROID_ABI:-arm64-v8a}"
ANDROID_API="${NEURX_ANDROID_API:-26}"
BUILD_DIR="${NEURX_MOBILE_BUILD_DIR:-${MOBILE_DIR}/build/android-${ANDROID_ABI}}"

resolve_android_ndk() {
  for dir in \
    "${ANDROID_NDK_ROOT:-}" \
    "${NDK_ROOT:-}" \
    "${ANDROID_HOME:-}/ndk-bundle" \
    "${HOME}/Android/Sdk/ndk-bundle" \
    "/opt/android-ndk"
  do
    [ -n "${dir}" ] && [ -f "${dir}/build/cmake/android.toolchain.cmake" ] && printf '%s' "${dir}" && return 0
  done
  return 1
}

resolve_qt6_android_dir() {
  local abi_tag="android_arm64_v8a"
  [[ "${ANDROID_ABI}" == "x86_64" ]] && abi_tag="android_x86_64"
  [[ "${ANDROID_ABI}" == "x86" ]] && abi_tag="android_x86"
  [[ "${ANDROID_ABI}" == "armeabi-v7a" ]] && abi_tag="android_armv7"
  for dir in \
    "${Qt6_ANDROID_DIR:-}" \
    "${Qt6_DIR:-}" \
    "${HOME}/Qt/6.11.0/${abi_tag}/lib/cmake/Qt6" \
    "${HOME}/Qt/6.10.0/${abi_tag}/lib/cmake/Qt6"
  do
    [ -n "${dir}" ] && [ -f "${dir}/Qt6Config.cmake" ] && printf '%s' "${dir}" && return 0
  done
  return 1
}

NDK_ROOT="$(resolve_android_ndk)"
QT6_ANDROID_DIR_RESOLVED="$(resolve_qt6_android_dir)"

mkdir -p "${BUILD_DIR}"

cmake -S "${MOBILE_DIR}" -B "${BUILD_DIR}" \
  -DCMAKE_TOOLCHAIN_FILE="${NDK_ROOT}/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI="${ANDROID_ABI}" \
  -DANDROID_PLATFORM="android-${ANDROID_API}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DQt6_DIR="${QT6_ANDROID_DIR_RESOLVED}"

cmake --build "${BUILD_DIR}" --config Release
