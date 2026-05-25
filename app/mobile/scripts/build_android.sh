#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ANDROID_ABI="${NEURX_ANDROID_ABI:-arm64-v8a}"
ANDROID_API="${NEURX_ANDROID_API:-28}"
BUILD_DIR="${NEURX_MOBILE_BUILD_DIR:-${MOBILE_DIR}/build/android-${ANDROID_ABI}}"
DEFAULT_ANDROID_SDK_ROOT="${HOME}/Android/Sdk"
if [[ "${OS:-}" == "Windows_NT" ]]; then
  DEFAULT_ANDROID_SDK_ROOT="C:/Users/Administrator/AppData/Local/Android/Sdk"
fi
ANDROID_SDK_ROOT_RESOLVED="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-${DEFAULT_ANDROID_SDK_ROOT}}}"
DEFAULT_ANDROID_JAVA_HOME="${JAVA_HOME:-}"
if [[ -z "${DEFAULT_ANDROID_JAVA_HOME}" ]]; then
  if [[ "${OS:-}" == "Windows_NT" ]]; then
    DEFAULT_ANDROID_JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"
  elif [[ -d "/usr/lib/jvm/default-java" ]]; then
    DEFAULT_ANDROID_JAVA_HOME="/usr/lib/jvm/default-java"
  elif [[ -d "/usr/lib/jvm/java-17-openjdk-amd64" ]]; then
    DEFAULT_ANDROID_JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
  fi
fi
ANDROID_JAVA_HOME="${DEFAULT_ANDROID_JAVA_HOME}"
# Qt 6.4.x still generates an Android Gradle Plugin 7.2.1 project.
# compileSdk 36 is too new for that toolchain on this host, while 34 is installed and stable.
ANDROID_COMPILE_SDK="${NEURX_ANDROID_COMPILE_SDK:-34}"
ANDROID_NDK_VERSION="${NEURX_ANDROID_NDK_VERSION:-27.2.12479018}"
ANDROID_PACKAGE_NAME="${NEURX_ANDROID_PACKAGE_NAME:-com.neurx.mobile}"
ANDROID_VERSION_CODE="${NEURX_ANDROID_VERSION_CODE:-1}"
ANDROID_VERSION_NAME="${NEURX_ANDROID_VERSION_NAME:-1.0.0}"
DEFAULT_GRADLE_USER_HOME="${TMPDIR:-/tmp}/neurx-gradle"
GRADLE_USER_HOME="${GRADLE_USER_HOME:-${NEURX_GRADLE_USER_HOME:-${DEFAULT_GRADLE_USER_HOME}}}"

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
    "${HOME}/Qt/6.11.0/${abi_tag}/lib/cmake/Qt6" \
    "C:/Users/Public/qt/6.11.0/${abi_tag}/lib/cmake/Qt6" \
    "${HOME}/Qt/6.10.0/${abi_tag}/lib/cmake/Qt6" \
    "/opt/Qt/6.11.0/${abi_tag}/lib/cmake/Qt6" \
    "/opt/Qt/6.10.0/${abi_tag}/lib/cmake/Qt6" \
    "${HOME}/Qt/6.4.2/${abi_tag}/lib/cmake/Qt6" \
    "/opt/Qt/6.4.2/${abi_tag}/lib/cmake/Qt6"
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
      -e "s/^androidCompileSdkVersion=.*/androidCompileSdkVersion=${ANDROID_COMPILE_SDK}/" \
      -e "s/^androidNdkVersion=.*/androidNdkVersion=${ANDROID_NDK_VERSION}/" \
      -e "s/^androidPackageName=.*/androidPackageName=${ANDROID_PACKAGE_NAME}/" \
      -e "s/^qtTargetSdkVersion=.*/qtTargetSdkVersion=${ANDROID_COMPILE_SDK}/" \
      -e 's/^org\.gradle\.offline=.*/org.gradle.offline=false/' \
      "${gradle_props}"
    # AndroidX is required for CameraX and ML Kit
    if ! grep -q "android.useAndroidX" "${gradle_props}"; then
      echo "android.useAndroidX=true" >> "${gradle_props}"
    else
      sed -i -e 's/^android\.useAndroidX=.*/android.useAndroidX=true/' "${gradle_props}"
    fi
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

    # --- QR scanner dependencies (CameraX + ML Kit) ---
    if ! grep -q "mlkit:barcode-scanning" "${build_gradle}"; then
      sed -i \
        -e "s|implementation fileTree(dir: 'libs', include: \['\*.jar', '\*.aar'\])|implementation fileTree(dir: 'libs', include: ['*.jar', '*.aar'])\n    implementation 'com.google.mlkit:barcode-scanning:17.1.0'\n    implementation 'androidx.camera:camera-camera2:1.1.0'\n    implementation 'androidx.camera:camera-lifecycle:1.1.0'\n    implementation 'androidx.camera:camera-view:1.1.0'|" \
        "${build_gradle}"
    fi

    # --- Java 8 compile options required by CameraX lambdas ---
    if ! grep -q "JavaVersion.VERSION_1_8" "${build_gradle}"; then
      # Insert compileOptions block after the compileSdkVersion line inside android {}
      sed -i \
        -e "/compileSdkVersion/a\\    compileOptions {\n        sourceCompatibility JavaVersion.VERSION_1_8\n        targetCompatibility JavaVersion.VERSION_1_8\n    }" \
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

patch_android_manifest() {
  local android_build_dir="${BUILD_DIR}/android-build"
  local manifest="${android_build_dir}/AndroidManifest.xml"

  if [ ! -f "${manifest}" ]; then
    return 0
  fi

  python3 - "${manifest}" <<'PY'
import sys
import xml.etree.ElementTree as ET

manifest_path = sys.argv[1]
android_ns = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", android_ns)

tree = ET.parse(manifest_path)
root = tree.getroot()
app = root.find("application")
if app is None:
    raise SystemExit(0)

def a(name: str) -> str:
    return f"{{{android_ns}}}{name}"

permission_names = {
    child.get(a("name"))
    for child in root.findall("uses-permission")
    if child.get(a("name"))
}
if "android.permission.CAMERA" not in permission_names:
    permission = ET.Element("uses-permission")
    permission.set(a("name"), "android.permission.CAMERA")
    root.insert(1, permission)

feature_names = {
    child.get(a("name"))
    for child in root.findall("uses-feature")
    if child.get(a("name"))
}
if "android.hardware.camera" not in feature_names:
    feature = ET.Element("uses-feature")
    feature.set(a("name"), "android.hardware.camera")
    feature.set(a("required"), "true")
    root.insert(2, feature)

app.set(a("name"), "org.qtproject.qt.android.bindings.QtApplication")
app.set(a("allowBackup"), "true")
app.set(a("allowNativeHeapPointerTagging"), "false")
app.set(a("fullBackupOnly"), "false")

activity = None
for candidate in app.findall("activity"):
    if candidate.get(a("name")) == "org.qtproject.qt.android.bindings.QtActivity":
        activity = candidate
        break

if activity is None:
    raise SystemExit(0)

activity.set(a("label"), "@string/app_name")
activity.set(a("configChanges"), "orientation|uiMode|screenLayout|screenSize|smallestScreenSize|layoutDirection|locale|fontScale|keyboard|keyboardHidden|navigation|mcc|mnc|density")
activity.set(a("launchMode"), "singleTop")

metadata_values = {
    "android.app.lib_name": "neurx_mobile",
    "android.app.arguments": "",
    "android.app.background_running": "true",
    "android.app.extract_android_style": "minimal",
}

existing = {
    child.get(a("name")): child
    for child in activity.findall("meta-data")
    if child.get(a("name"))
}

for key, value in metadata_values.items():
    node = existing.get(key)
    if node is None:
        node = ET.SubElement(activity, "meta-data")
        node.set(a("name"), key)
    node.set(a("value"), value)

qr_activity = None
for candidate in app.findall("activity"):
    if candidate.get(a("name")) == "com.neurx.mobile.QrScanActivity":
        qr_activity = candidate
        break

if qr_activity is None:
    qr_activity = ET.SubElement(app, "activity")
    qr_activity.set(a("name"), "com.neurx.mobile.QrScanActivity")

qr_activity.set(a("exported"), "false")
qr_activity.set(a("screenOrientation"), "portrait")
qr_activity.set(a("theme"), "@android:style/Theme.Black.NoTitleBar.Fullscreen")

tree.write(manifest_path, encoding="utf-8", xml_declaration=True)
PY
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

mkdir -p "${GRADLE_USER_HOME}"
export GRADLE_USER_HOME

# Build only through the APK staging target first so Qt's generated Gradle
# files can be patched before Gradle packaging starts.
cmake --build "${BUILD_DIR}" --config Release --target neurx_mobile_prepare_apk_dir
patch_gradle_android_build
patch_android_manifest
(
  cd "${BUILD_DIR}/android-build"
  if [[ "${OS:-}" == "Windows_NT" ]]; then
    cmd.exe //c gradlew.bat assembleDebug
  else
    chmod +x gradlew 2>/dev/null || true
    ./gradlew assembleDebug
  fi
)
