#!/usr/bin/env bash
set -euo pipefail

# Build and deploy the NeurX app to a HarmonyOS device.
# Requirements:
#   - DevEco Studio command-line tools or HarmonyOS SDK
#   - hvigor (HarmonyOS build tool)
#   - hdc (HarmonyOS Device Connector, like adb)
#   - ohpm (OpenHarmony package manager)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${APP_DIR}/.." && pwd)"

# ---------------------------------------------------------------------------
# Configuration (override via env)
# ---------------------------------------------------------------------------
HARMONY_ABI="${NEURX_HARMONY_ABI:-arm64-v8a}"
BUILD_DIR="${NEURX_APP_BUILD_DIR:-${APP_DIR}/build/make-harmony}"
OUTPUT_DIR="${ROOT_DIR}/bin/harmony-arm64"
HARMONY_PROJECT_DIR="${NEURX_HARMONY_PROJECT_DIR:-${APP_DIR}/platform/harmony}"
HARMONY_SDK_HOME="${DEVECO_SDK_HOME:-${HOS_SDK_HOME:-${HOME}/DevEcoStudio/sdk}}"

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
resolve_hvigor() {
  # Check explicit path first
  if [ -n "${NEURX_HVIGOR:-}" ] && [ -x "${NEURX_HVIGOR}" ]; then
    printf '%s' "${NEURX_HVIGOR}"
    return 0
  fi
  # Project-local hvigor wrapper (typical DevEco project structure)
  if [ -x "${HARMONY_PROJECT_DIR}/hvigorw" ]; then
    printf '%s' "${HARMONY_PROJECT_DIR}/hvigorw"
    return 0
  fi
  # SDK-bundled hvigor
  for candidate in \
    "${HARMONY_SDK_HOME}/hvigor/bin/hvigor" \
    "${HOME}/.deveco/hvigor/bin/hvigor" \
    "/opt/deveco/hvigor/bin/hvigor"
  do
    [ -x "${candidate}" ] && printf '%s' "${candidate}" && return 0
  done
  if command -v hvigor >/dev/null 2>&1; then
    command -v hvigor
    return 0
  fi
  return 1
}

resolve_hdc() {
  if [ -n "${NEURX_HDC:-}" ] && [ -x "${NEURX_HDC}" ]; then
    printf '%s' "${NEURX_HDC}"
    return 0
  fi
  for candidate in \
    "${HARMONY_SDK_HOME}/toolchains/hdc" \
    "${HOME}/.deveco/toolchains/hdc" \
    "/opt/deveco/toolchains/hdc"
  do
    [ -x "${candidate}" ] && printf '%s' "${candidate}" && return 0
  done
  if command -v hdc >/dev/null 2>&1; then
    command -v hdc
    return 0
  fi
  return 1
}

HVIGOR="$(resolve_hvigor || true)"
if [ -z "${HVIGOR}" ]; then
  echo "Error: hvigor not found."
  echo "Hint: install DevEco Studio and ensure hvigor is on PATH, or set:"
  echo "  NEURX_HVIGOR=/path/to/hvigorw"
  echo "  DEVECO_SDK_HOME=/path/to/DevEcoStudio/sdk"
  exit 1
fi

HDC="$(resolve_hdc || true)"
if [ -z "${HDC}" ]; then
  echo "Error: hdc (HarmonyOS Device Connector) not found."
  echo "Hint: install the HarmonyOS SDK toolchains and add them to PATH, or set:"
  echo "  NEURX_HDC=/path/to/hdc"
  exit 1
fi

if [ ! -d "${HARMONY_PROJECT_DIR}" ]; then
  echo "Error: HarmonyOS project directory not found: ${HARMONY_PROJECT_DIR}"
  echo "Hint: create a HarmonyOS app project under app/platform/harmony/ or set:"
  echo "  NEURX_HARMONY_PROJECT_DIR=/path/to/harmony-project"
  exit 1
fi

# ---------------------------------------------------------------------------
# Install dependencies (ohpm)
# ---------------------------------------------------------------------------
if command -v ohpm >/dev/null 2>&1 && [ -f "${HARMONY_PROJECT_DIR}/oh-package.json5" ]; then
  echo "Installing ohpm dependencies..."
  (cd "${HARMONY_PROJECT_DIR}" && ohpm install)
fi

# ---------------------------------------------------------------------------
# Build HAP via hvigor
# ---------------------------------------------------------------------------
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

echo "Building NeurX app for HarmonyOS (ABI=${HARMONY_ABI})..."
(
  cd "${HARMONY_PROJECT_DIR}"
  "${HVIGOR}" --mode module -p module=entry@default \
    -p product=default \
    assembleHap \
    --stacktrace \
    ${NEURX_HVIGOR_ARGS:-}
)

# ---------------------------------------------------------------------------
# Locate and deploy HAP
# ---------------------------------------------------------------------------
HAP="$(find "${HARMONY_PROJECT_DIR}" -name "*.hap" -maxdepth 6 | sort | tail -n 1 || true)"
if [ -z "${HAP}" ]; then
  HAP="${NEURX_HARMONY_HAP:-}"
fi

if [ -z "${HAP}" ]; then
  echo "Build succeeded. Install the HAP manually with:"
  echo "  hdc app install <path/to/NeurX.hap>"
  exit 0
fi

# Copy to bin output dir
cp "${HAP}" "${OUTPUT_DIR}/"
echo "HAP artifact: ${OUTPUT_DIR}/$(basename "${HAP}")"

echo "Checking connected HarmonyOS devices..."
if ! "${HDC}" list targets 2>/dev/null | grep -qv "^$"; then
  echo "Warning: no HarmonyOS device connected."
  echo "Hint: connect your device via USB, enable developer mode, and run:"
  echo "  hdc app install ${HAP}"
  exit 0
fi

echo "Installing ${HAP} via hdc..."
"${HDC}" app install "${HAP}"

BUNDLE_NAME="${NEURX_HARMONY_BUNDLE:-com.neurx.app}"
ABILITY="${NEURX_HARMONY_ABILITY:-EntryAbility}"
echo "Launching ${BUNDLE_NAME}/${ABILITY}..."
"${HDC}" shell aa start -b "${BUNDLE_NAME}" -a "${ABILITY}"
