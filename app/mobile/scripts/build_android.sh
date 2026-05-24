#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ANDROID_ABI="${NEURX_ANDROID_ABI:-arm64-v8a}"
ANDROID_API="${NEURX_ANDROID_API:-28}"
BUILD_DIR="${NEURX_MOBILE_BUILD_DIR:-${MOBILE_DIR}/build/android-${ANDROID_ABI}}"
ANDROID_SDK_ROOT_RESOLVED="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-C:/Users/Administrator/AppData/Local/Android/Sdk}}"
ANDROID_JAVA_HOME="${JAVA_HOME:-C:/Program Files/Android/Android Studio/jbr}"
ANDROID_COMPILE_SDK="${NEURX_ANDROID_COMPILE_SDK:-36}"
ANDROID_NDK_VERSION="${NEURX_ANDROID_NDK_VERSION:-27.2.12479018}"
ANDROID_PACKAGE_NAME="${NEURX_ANDROID_PACKAGE_NAME:-com.neurx.mobile}"
ANDROID_VERSION_CODE="${NEURX_ANDROID_VERSION_CODE:-1}"
ANDROID_VERSION_NAME="${NEURX_ANDROID_VERSION_NAME:-1.0.0}"

resolve_android_ndk() {
  local sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  for dir in \
    "${ANDROID_NDK_ROOT:-}" \
    "${NDK_ROOT:-}" \
    "${sdk_root}/ndk/27.2.12479018" \
    "${sdk_root}/ndk-bundle" \
    "${ANDROID_HOME:-}/ndk-bundle" \
    "${HOME}/Android/Sdk/ndk-bundle" \
    "/opt/android-ndk" \
    "C:/Users/Administrator/AppData/Local/Android/Sdk/ndk/27.2.12479018"
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
    "C:/Users/Public/qt/6.11.0/${abi_tag}/lib/cmake/Qt6" \
    "${HOME}/Qt/6.11.0/${abi_tag}/lib/cmake/Qt6" \
    "${HOME}/Qt/6.10.0/${abi_tag}/lib/cmake/Qt6"
  do
    [ -n "${dir}" ] && [ -f "${dir}/Qt6Config.cmake" ] && printf '%s' "${dir}" && return 0
  done
  return 1
}

patch_gradle_android_build() {
  local android_build_dir="${BUILD_DIR}/android-build"
  local gradle_props="${android_build_dir}/gradle.properties"
  local build_gradle="${android_build_dir}/build.gradle"
  local gradle_wrapper_props="${android_build_dir}/gradle/wrapper/gradle-wrapper.properties"
  local gradlew_bat="${android_build_dir}/gradlew.bat"

  if [ -f "${gradle_props}" ]; then
    sed -i \
      -e '/^androidBuildToolsVersion=/d' \
      -e "s/^androidCompileSdkVersion=.*/androidCompileSdkVersion=android-${ANDROID_COMPILE_SDK}/" \
      -e "s/^androidNdkVersion=.*/androidNdkVersion=${ANDROID_NDK_VERSION}/" \
      -e "s/^androidPackageName=.*/androidPackageName=${ANDROID_PACKAGE_NAME}/" \
      -e "s/^qtTargetSdkVersion=.*/qtTargetSdkVersion=${ANDROID_COMPILE_SDK}/" \
      -e 's/^org\.gradle\.offline=.*/org.gradle.offline=false/' \
      "${gradle_props}"
  fi

  if [ -f "${build_gradle}" ]; then
    if ! grep -q "maven.aliyun.com/repository/google" "${build_gradle}"; then
      sed -i \
        -e 's/google()/maven { url '"'"'https:\/\/maven.aliyun.com\/repository\/google'"'"' }\n        maven { url '"'"'https:\/\/maven.aliyun.com\/repository\/public'"'"' }\n        google()/g' \
        -e 's/mavenCentral()/maven { url '"'"'https:\/\/maven.aliyun.com\/repository\/central'"'"' }\n        mavenCentral()/g' \
        "${build_gradle}"
    fi
    sed -i \
      -e "/buildToolsVersion /d" \
      "${build_gradle}"

    if ! grep -q "versionCode ${ANDROID_VERSION_CODE}" "${build_gradle}"; then
      sed -i \
        -e "/defaultConfig {/a\\        versionCode ${ANDROID_VERSION_CODE}\\n        versionName '${ANDROID_VERSION_NAME}'" \
        "${build_gradle}"
    fi
  fi

  if [ -f "${gradle_wrapper_props}" ]; then
    sed -i \
      -e 's/gradle-9\.3\.1-bin\.zip/gradle-9.4.1-bin.zip/' \
      "${gradle_wrapper_props}"
  fi

  if [ -f "${gradlew_bat}" ]; then
    unix2dos -q "${gradlew_bat}" 2>/dev/null || true
  fi
}

NDK_ROOT="$(resolve_android_ndk)"
QT6_ANDROID_DIR_RESOLVED="$(resolve_qt6_android_dir)"

mkdir -p "${BUILD_DIR}"

cmake -S "${MOBILE_DIR}" -B "${BUILD_DIR}" \
  -DCMAKE_TOOLCHAIN_FILE="${NDK_ROOT}/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI="${ANDROID_ABI}" \
  -DANDROID_PLATFORM="android-${ANDROID_API}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DANDROID_SDK_ROOT="${ANDROID_SDK_ROOT_RESOLVED}" \
  -DQt6_DIR="${QT6_ANDROID_DIR_RESOLVED}"

patch_gradle_android_build

if [ -d "${ANDROID_JAVA_HOME}/bin" ]; then
  export JAVA_HOME="${ANDROID_JAVA_HOME}"
  export PATH="${ANDROID_JAVA_HOME}/bin:${PATH}"
fi

cmake --build "${BUILD_DIR}" --config Release
patch_gradle_android_build
(
  cd "${BUILD_DIR}/android-build"
  cmd.exe //c gradlew.bat assembleDebug
)
