#!/usr/bin/env bash
set -euo pipefail

# Build and deploy the NeurX Qt app to an Android device or emulator.
# Requirements:
#   - Android NDK (set ANDROID_NDK_ROOT or NDK_ROOT)
#   - Android SDK with platform-tools (adb on PATH)
#   - Qt for Android arm64-v8a (set Qt6_ANDROID_DIR)
#   - cmake + ninja

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${APP_DIR}/.." && pwd)"

# ---------------------------------------------------------------------------
# Configuration (override via env)
# ---------------------------------------------------------------------------
ANDROID_ABI="${NEURX_ANDROID_ABI:-arm64-v8a}"
ANDROID_API="${NEURX_ANDROID_API:-26}"
BUILD_DIR="${NEURX_APP_BUILD_DIR:-${APP_DIR}/build/make-android}"
OUTPUT_DIR="${ROOT_DIR}/bin/android-${ANDROID_ABI}"

Qt6_ANDROID_DIR="${Qt6_ANDROID_DIR:-${Qt6_DIR:-}}"

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
resolve_android_ndk() {
  for dir in \
    "${ANDROID_NDK_ROOT:-}" \
    "${NDK_ROOT:-}" \
    "${ANDROID_HOME:-}/ndk-bundle" \
    "${HOME}/Library/Android/sdk/ndk-bundle" \
    "${HOME}/Android/Sdk/ndk-bundle" \
    "/opt/android-ndk"
  do
    [ -n "${dir}" ] && [ -f "${dir}/build/cmake/android.toolchain.cmake" ] && \
      printf '%s' "${dir}" && return 0
  done
  # Try versioned NDK directories under ANDROID_HOME/ndk/
  local sdk_ndk_base="${ANDROID_HOME:-${HOME}/Android/Sdk}/ndk"
  if [ -d "${sdk_ndk_base}" ]; then
    local latest
    latest="$(ls -1 "${sdk_ndk_base}" 2>/dev/null | sort -V | tail -n 1 || true)"
    if [ -n "${latest}" ] && [ -f "${sdk_ndk_base}/${latest}/build/cmake/android.toolchain.cmake" ]; then
      printf '%s' "${sdk_ndk_base}/${latest}"
      return 0
    fi
  fi
  return 1
}

resolve_qt6_android_dir() {
  if [ -n "${Qt6_ANDROID_DIR}" ] && [ -f "${Qt6_ANDROID_DIR}/Qt6Config.cmake" ]; then
    printf '%s' "${Qt6_ANDROID_DIR}"
    return 0
  fi
  local abi_tag="android_arm64_v8a"
  [[ "${ANDROID_ABI}" == "x86_64" ]] && abi_tag="android_x86_64"
  [[ "${ANDROID_ABI}" == "x86"    ]] && abi_tag="android_x86"
  [[ "${ANDROID_ABI}" == "armeabi-v7a" ]] && abi_tag="android_armv7"
  local candidates=(
    "${HOME}/Qt/6.11.0/${abi_tag}/lib/cmake/Qt6"
    "${HOME}/Qt/6.10.0/${abi_tag}/lib/cmake/Qt6"
    "${HOME}/Qt/6.9.0/${abi_tag}/lib/cmake/Qt6"
    "${HOME}/Qt/6.8.0/${abi_tag}/lib/cmake/Qt6"
  )
  local c
  for c in "${candidates[@]}"; do
    [ -f "${c}/Qt6Config.cmake" ] && printf '%s' "${c}" && return 0
  done
  return 1
}

if ! command -v cmake >/dev/null 2>&1; then
  echo "Error: cmake not found."
  echo "Hint: install CMake or set NEURX_CMAKE=/path/to/cmake."
  exit 1
fi
CMAKE_BIN="${NEURX_CMAKE:-cmake}"

NDK_ROOT_RESOLVED="$(resolve_android_ndk || true)"
if [ -z "${NDK_ROOT_RESOLVED}" ]; then
  echo "Error: Android NDK not found."
  echo "Hint: install the NDK via Android Studio SDK Manager and set:"
  echo "  ANDROID_NDK_ROOT=/path/to/android-ndk"
  exit 1
fi

QT6_ANDROID_RESOLVED="$(resolve_qt6_android_dir || true)"
if [ -z "${QT6_ANDROID_RESOLVED}" ]; then
  echo "Error: Qt for Android (${ANDROID_ABI}) cmake dir not found."
  echo "Hint: install the Qt Android kit via Qt Maintenance Tool and set:"
  echo "  Qt6_ANDROID_DIR=\$HOME/Qt/6.x.x/android_arm64_v8a/lib/cmake/Qt6"
  exit 1
fi

if ! command -v adb >/dev/null 2>&1; then
  echo "Error: adb not found on PATH."
  echo "Hint: install Android SDK platform-tools or add them to PATH."
  exit 1
fi

# ---------------------------------------------------------------------------
# CMake configure + build
# ---------------------------------------------------------------------------
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

echo "Configuring NeurX app for Android (ABI=${ANDROID_ABI}, API=${ANDROID_API})..."
"${CMAKE_BIN}" -S "${APP_DIR}" -B "${BUILD_DIR}" \
  -DCMAKE_TOOLCHAIN_FILE="${NDK_ROOT_RESOLVED}/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI="${ANDROID_ABI}" \
  -DANDROID_PLATFORM="android-${ANDROID_API}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DQt6_DIR="${QT6_ANDROID_RESOLVED}" \
  -DCMAKE_PREFIX_PATH="$(cd "${QT6_ANDROID_RESOLVED}/../../.." && pwd)" \
  -DNEURX_APP_TARGET_PLATFORM=android \
  ${NEURX_ANDROID_CMAKE_ARGS:-}

echo "Building NeurX app for Android..."
"${CMAKE_BIN}" --build "${BUILD_DIR}" --config Release -j"$(nproc)"

# ---------------------------------------------------------------------------
# Deploy APK/AAB via adb
# ---------------------------------------------------------------------------
APK="$(find "${BUILD_DIR}" -name "*.apk" -maxdepth 5 | head -n 1 || true)"
if [ -z "${APK}" ]; then
  echo "Warning: no APK found under ${BUILD_DIR}."
  echo "The Qt for Android CMake flow may generate an APK in a subdirectory."
  echo "Set NEURX_ANDROID_APK=/path/to/NeurX.apk to install manually."
  APK="${NEURX_ANDROID_APK:-}"
fi

if [ -z "${APK}" ]; then
  echo "Build succeeded. Install the APK manually with:"
  echo "  adb install -r <path/to/NeurX.apk>"
  exit 0
fi

echo "Installing ${APK} via adb..."
adb install -r "${APK}"

PACKAGE="${NEURX_ANDROID_PACKAGE:-com.neurx.app}"
ACTIVITY="${NEURX_ANDROID_ACTIVITY:-${PACKAGE}/.MainActivity}"
echo "Launching ${ACTIVITY}..."
adb shell am start -n "${ACTIVITY}"
