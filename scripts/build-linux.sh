#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  NeurX Code — Linux build script
#  Usage:  ./scripts/build-linux.sh [Debug|Release] [-- extra cmake args]
#
#  Requires:
#    apt install cmake ninja-build \
#        qt6-base-dev qt6-base-dev-tools \
#        qt6-declarative-dev qt6-declarative-dev-tools \
#        libqt6concurrent6t64 \
#        libgl1-mesa-dev libvulkan-dev
#  OR use an official Qt installer and set QT6_DIR / Qt6_DIR below.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_TYPE="${1:-Release}"
BUILD_DIR="$PROJECT_DIR/build/linux-$BUILD_TYPE"

# If the build directory was generated from a different checkout path, CMake
# will refuse to re-use it. Detect that case and start from a clean build dir.
if [ -f "$BUILD_DIR/CMakeCache.txt" ]; then
    CACHE_SOURCE_DIR="$(sed -n 's/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' "$BUILD_DIR/CMakeCache.txt" | head -n 1)"
    if [ -n "$CACHE_SOURCE_DIR" ] && [ "$CACHE_SOURCE_DIR" != "$PROJECT_DIR" ]; then
        echo "[linux] Removing stale build dir from previous source tree:"
        echo "[linux]   cache source: $CACHE_SOURCE_DIR"
        echo "[linux]   current source: $PROJECT_DIR"
        rm -rf "$BUILD_DIR"
    fi
fi

# ── Qt discovery ─────────────────────────────────────────────────────────────
# Try user-installed Qt first (e.g. ~/Qt/6.x.x/gcc_64), then system Qt.
QT_SEARCH_PATHS=(
    "$HOME/Qt/6.*/gcc_64"
    "$HOME/Qt/6*/gcc_64"
    "/opt/Qt/6.*/gcc_64"
)
QT_CMAKE_PREFIX=""
for pat in "${QT_SEARCH_PATHS[@]}"; do
    for dir in $pat; do
        if [ -f "$dir/lib/cmake/Qt6/Qt6Config.cmake" ]; then
            QT_CMAKE_PREFIX="$dir"
            break 2
        fi
    done
done

CMAKE_EXTRA_ARGS=()
if [ -n "$QT_CMAKE_PREFIX" ]; then
    echo "[linux] Using Qt from: $QT_CMAKE_PREFIX"
    CMAKE_EXTRA_ARGS+=("-DCMAKE_PREFIX_PATH=$QT_CMAKE_PREFIX")
else
    echo "[linux] Using system Qt"
fi

# ── Configure ────────────────────────────────────────────────────────────────
cmake -S "$PROJECT_DIR" \
      -B "$BUILD_DIR" \
      -G Ninja \
      -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
      -DLINK_INSIGHT=OFF \
      -DBUILD_QDS_COMPONENTS=OFF \
      -DBUILD_CODEX_CLI=OFF \
      "${CMAKE_EXTRA_ARGS[@]}" \
      "${@:2}"

# ── Build ─────────────────────────────────────────────────────────────────────
cmake --build "$BUILD_DIR" --parallel "$(nproc)"

echo ""
echo "✓ Build complete: $BUILD_DIR/neurx-codeApp"
echo "  Launching: $BUILD_DIR/neurx-codeApp $PROJECT_DIR"
echo ""

# ── Sync system IME plugins into the Qt installation used for building ───────
# Qt from ~/Qt/<ver>/gcc_64 does not ship fcitx/ibus plugins; copy them from
# the system Qt (same 6.4.2 ABI) so Chinese input works at runtime.
SYSTEM_IM_DIR="/usr/lib/x86_64-linux-gnu/qt6/plugins/platforminputcontexts"
if [ -n "$QT_CMAKE_PREFIX" ] && [ -d "$SYSTEM_IM_DIR" ]; then
    QT_IM_PLUGIN_DIR="$QT_CMAKE_PREFIX/plugins/platforminputcontexts"
    for plugin in libfcitxplatforminputcontextplugin-qt6.so \
                  libfcitx5platforminputcontextplugin.so \
                  libibusplatforminputcontextplugin.so; do
        if [ -f "$SYSTEM_IM_DIR/$plugin" ] && [ ! -f "$QT_IM_PLUGIN_DIR/$plugin" ]; then
            echo "[linux] Copying IME plugin: $plugin"
            cp "$SYSTEM_IM_DIR/$plugin" "$QT_IM_PLUGIN_DIR/"
        fi
    done
fi

# ── Ensure input method daemon is available for Chinese input ─────────────────
if command -v fcitx >/dev/null 2>&1; then
    if ! pgrep -x fcitx >/dev/null 2>&1; then
        echo "[linux] Starting fcitx input method daemon…"
        nohup fcitx -d >/tmp/neurx-fcitx.log 2>&1 &
        sleep 1
    fi
    if pgrep -x fcitx >/dev/null 2>&1; then
        echo "[linux] Input method: fcitx is running"
    else
        echo "[linux] Input method: fcitx is not running"
    fi
else
    echo "[linux] Input method: fcitx not installed"
fi

# ── Kill any stale instances to avoid pipe-user-pages exhaustion ─────────────
if pgrep -x neurx-codeApp >/dev/null 2>&1; then
    echo "[linux] Killing existing neurx-codeApp instance(s)…"
    pkill -x neurx-codeApp 2>/dev/null || true
    sleep 0.5
fi

# ── Launch the app in the foreground so terminal logs stay attached ─────────
export QT_IM_MODULE="${QT_IM_MODULE:-fcitx}"
export XMODIFIERS="${XMODIFIERS:-@im=fcitx}"
export GTK_IM_MODULE="${GTK_IM_MODULE:-fcitx}"
"$BUILD_DIR/neurx-codeApp" "$PROJECT_DIR"

# ── Optional: package as AppImage ────────────────────────────────────────────
if command -v linuxdeployqt &>/dev/null; then
    echo "[linux] Packaging AppImage…"
    DESTDIR="$BUILD_DIR/AppDir" cmake --install "$BUILD_DIR"
    linuxdeployqt "$BUILD_DIR/AppDir/usr/bin/neurx-codeApp" \
        -appimage -qmldir="$PROJECT_DIR" \
        -qmake="${QT_CMAKE_PREFIX:+$QT_CMAKE_PREFIX/bin/qmake6}" 2>/dev/null || true
    echo "✓ AppImage created in $BUILD_DIR/"
fi
