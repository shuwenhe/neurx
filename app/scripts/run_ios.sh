#!/usr/bin/env bash
set -euo pipefail

# Build and deploy the NeurX Qt app to an iOS device or simulator.
# Requirements:
#   - macOS host with Xcode installed (xcodebuild, xcrun, simctl)
#   - Qt for iOS (set Qt6_DIR or Qt6_IOS_DIR to the iOS cmake dir)
#   - Apple Developer account for on-device deployment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${APP_DIR}/.." && pwd)"

# ---------------------------------------------------------------------------
# Configuration (override via env)
# ---------------------------------------------------------------------------
IOS_SIMULATOR="${NEURX_IOS_SIMULATOR:-1}"   # 1=simulator, 0=real device
IOS_DEVICE_ID="${NEURX_IOS_DEVICE_ID:-}"    # xcrun device UDID (optional)
IOS_BUNDLE_ID="${NEURX_IOS_BUNDLE_ID:-com.neurx.app}"
BUILD_DIR="${NEURX_APP_BUILD_DIR:-${APP_DIR}/build/make-ios}"
OUTPUT_DIR="${ROOT_DIR}/bin/ios-arm64"

Qt6_IOS_DIR="${Qt6_IOS_DIR:-${Qt6_DIR:-}}"

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: iOS builds require a macOS host."
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Error: xcodebuild not found."
  echo "Hint: install Xcode from the App Store and accept the license:"
  echo "  sudo xcodebuild -license accept"
  exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
  echo "Error: cmake not found."
  echo "Hint: install CMake (brew install cmake) or set NEURX_CMAKE=/path/to/cmake."
  exit 1
fi
CMAKE_BIN="${NEURX_CMAKE:-cmake}"

# Resolve Qt for iOS cmake dir
resolve_qt6_ios_dir() {
  if [ -n "${Qt6_IOS_DIR}" ] && [ -f "${Qt6_IOS_DIR}/Qt6Config.cmake" ]; then
    printf '%s' "${Qt6_IOS_DIR}"
    return 0
  fi
  local candidates=(
    "${HOME}/Qt/6.11.0/ios/lib/cmake/Qt6"
    "${HOME}/Qt/6.10.0/ios/lib/cmake/Qt6"
    "${HOME}/Qt/6.9.0/ios/lib/cmake/Qt6"
    "${HOME}/Qt/6.8.0/ios/lib/cmake/Qt6"
  )
  local c
  for c in "${candidates[@]}"; do
    if [ -f "${c}/Qt6Config.cmake" ]; then
      printf '%s' "${c}"
      return 0
    fi
  done
  return 1
}

QT6_IOS_RESOLVED="$(resolve_qt6_ios_dir || true)"
if [ -z "${QT6_IOS_RESOLVED}" ]; then
  echo "Error: Qt for iOS cmake dir not found."
  echo "Hint: install the Qt iOS kit via Qt Maintenance Tool and set:"
  echo "  Qt6_IOS_DIR=\$HOME/Qt/6.x.x/ios/lib/cmake/Qt6"
  exit 1
fi

# ---------------------------------------------------------------------------
# CMake configure + build
# ---------------------------------------------------------------------------
SDK="iphonesimulator"
ARCH="arm64"
if [[ "${IOS_SIMULATOR}" == "0" ]]; then
  SDK="iphoneos"
fi

mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

echo "Configuring NeurX app for iOS (SDK=${SDK})..."
"${CMAKE_BIN}" -S "${APP_DIR}" -B "${BUILD_DIR}" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT="${SDK}" \
  -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DQt6_DIR="${QT6_IOS_RESOLVED}" \
  -DCMAKE_PREFIX_PATH="$(cd "${QT6_IOS_RESOLVED}/../../.." && pwd)" \
  -DNEURX_APP_TARGET_PLATFORM=ios \
  ${NEURX_IOS_CMAKE_ARGS:-}

echo "Building NeurX app for iOS..."
"${CMAKE_BIN}" --build "${BUILD_DIR}" --config Release -j"$(sysctl -n hw.logicalcpu)"

# ---------------------------------------------------------------------------
# Deploy to simulator or device
# ---------------------------------------------------------------------------
APP_BUNDLE="$(find "${BUILD_DIR}" -name "neurx_app.app" -maxdepth 4 | head -n 1 || true)"
if [ -z "${APP_BUNDLE}" ]; then
  echo "Error: neurx_app.app bundle not found under ${BUILD_DIR}"
  exit 1
fi

if [[ "${IOS_SIMULATOR}" == "1" ]]; then
  # Boot the default iPhone simulator if needed
  SIM_ID="${IOS_DEVICE_ID:-$(xcrun simctl list devices available -j \
    | python3 -c "import sys,json; devs=[d for ds in json.load(sys.stdin)['devices'].values() for d in ds if d['isAvailable'] and 'iPhone' in d['name']]; print(devs[0]['udid'] if devs else '')" 2>/dev/null || true)}"

  if [ -z "${SIM_ID}" ]; then
    echo "Error: no available iPhone simulator found."
    echo "Hint: open Xcode > Window > Devices and Simulators to create one."
    exit 1
  fi

  echo "Booting iOS simulator ${SIM_ID}..."
  xcrun simctl boot "${SIM_ID}" 2>/dev/null || true
  open -a Simulator

  echo "Installing ${APP_BUNDLE} on simulator..."
  xcrun simctl install "${SIM_ID}" "${APP_BUNDLE}"

  echo "Launching ${IOS_BUNDLE_ID} on simulator..."
  xcrun simctl launch --console "${SIM_ID}" "${IOS_BUNDLE_ID}"
else
  if [ -z "${IOS_DEVICE_ID}" ]; then
    echo "Error: NEURX_IOS_DEVICE_ID is not set."
    echo "Hint: run 'xcrun xctrace list devices' to find your device UDID."
    exit 1
  fi
  echo "Installing ${APP_BUNDLE} on device ${IOS_DEVICE_ID}..."
  xcrun devicectl device install app --device "${IOS_DEVICE_ID}" "${APP_BUNDLE}"
  echo "Launching ${IOS_BUNDLE_ID} on device..."
  xcrun devicectl device process launch --device "${IOS_DEVICE_ID}" "${IOS_BUNDLE_ID}"
fi
