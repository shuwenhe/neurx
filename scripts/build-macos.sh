#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  NeurX Code — macOS build script
#  Usage:  ./scripts/build-macos.sh [Debug|Release]
#
#  Requires:
#    • Xcode Command Line Tools:  xcode-select --install
#    • Qt 6.5+ for macOS, one of:
#        brew install qt          (Homebrew)
#        ~/Qt/6.x.x/macos        (official Qt Installer)
#    • CMake 3.21+:  brew install cmake
#    • Ninja (optional):  brew install ninja
#    • Rust toolchain (for Codex CLI):  curl https://sh.rustup.rs -sSf | sh
#      Or disable:  pass -DBUILD_CODEX_CLI=OFF to cmake
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_TYPE="${1:-Release}"
BUILD_DIR="$PROJECT_DIR/build/macos-$BUILD_TYPE"

# ── Qt discovery ─────────────────────────────────────────────────────────────
QT_CMAKE_PREFIX=""

# 1. Homebrew (arm64 or x86_64)
for brew_prefix in /opt/homebrew /usr/local; do
    if [ -f "$brew_prefix/opt/qt/lib/cmake/Qt6/Qt6Config.cmake" ]; then
        QT_CMAKE_PREFIX="$brew_prefix/opt/qt"
        break
    fi
    if [ -f "$brew_prefix/opt/qt6/lib/cmake/Qt6/Qt6Config.cmake" ]; then
        QT_CMAKE_PREFIX="$brew_prefix/opt/qt6"
        break
    fi
done

# 2. Official Qt Installer
if [ -z "$QT_CMAKE_PREFIX" ]; then
    for dir in "$HOME/Qt/6."*/macos "$HOME/Qt/6."*/macos_*; do
        if [ -f "$dir/lib/cmake/Qt6/Qt6Config.cmake" ]; then
            QT_CMAKE_PREFIX="$dir"
            break
        fi
    done
fi

# 3. Homebrew prefix fallback. Some setups expose the keg prefix reliably even
# when the direct probe paths above are not linked yet.
if [ -z "$QT_CMAKE_PREFIX" ] && command -v brew &>/dev/null; then
    for formula in qt qt6; do
        brew_prefix="$(brew --prefix "$formula" 2>/dev/null || true)"
        if [ -n "$brew_prefix" ] && [ -f "$brew_prefix/lib/cmake/Qt6/Qt6Config.cmake" ]; then
            QT_CMAKE_PREFIX="$brew_prefix"
            break
        fi
    done
fi

CMAKE_EXTRA_ARGS=()
if [ -n "$QT_CMAKE_PREFIX" ]; then
    echo "[macos] Using Qt from: $QT_CMAKE_PREFIX"
    CMAKE_EXTRA_ARGS+=("-DCMAKE_PREFIX_PATH=$QT_CMAKE_PREFIX")
else
    echo "[macos] WARNING: Qt6 not found. Set CMAKE_PREFIX_PATH or install via Homebrew."
fi

# ── Codex CLI (Rust) toggle ──────────────────────────────────────────────────
# By default we skip building the bundled Codex CLI to avoid requiring Rust/cargo.
# Enable explicitly with:
#   NEURX_BUILD_CODEX_CLI=1 make mac
NEURX_BUILD_CODEX_CLI="${NEURX_BUILD_CODEX_CLI:-0}"

if [ "$NEURX_BUILD_CODEX_CLI" != "1" ]; then
    echo "[macos] Codex CLI build disabled (set NEURX_BUILD_CODEX_CLI=1 to enable)"
    CMAKE_EXTRA_ARGS+=("-DBUILD_CODEX_CLI=OFF")
else
    # ── Rust / Cargo check ────────────────────────────────────────────────────
    if ! command -v cargo &>/dev/null && [ -x "$HOME/.cargo/bin/cargo" ]; then
        export PATH="$HOME/.cargo/bin:$PATH"
    fi

    if command -v cargo &>/dev/null; then
        echo "[macos] cargo found: $(cargo --version)"
    else
        echo "[macos] ERROR: 'cargo' not found but NEURX_BUILD_CODEX_CLI=1."
        echo "        Install Rust: curl https://sh.rustup.rs -sSf | sh"
        exit 1
    fi
fi

# ── Select generator ─────────────────────────────────────────────────────────
GENERATOR="Xcode"
if command -v ninja &>/dev/null; then
    GENERATOR="Ninja"
fi

# ── Configure ────────────────────────────────────────────────────────────────
cmake_args=(
    -S "$PROJECT_DIR"
    -B "$BUILD_DIR"
    -G "$GENERATOR"
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
    -DLINK_INSIGHT=OFF
    -DBUILD_QDS_COMPONENTS=OFF
)
if [ "${#CMAKE_EXTRA_ARGS[@]}" -gt 0 ]; then
    cmake_args+=("${CMAKE_EXTRA_ARGS[@]}")
fi
cmake "${cmake_args[@]}"

# ── Build ─────────────────────────────────────────────────────────────────────
if [ "$GENERATOR" = "Xcode" ]; then
    cmake --build "$BUILD_DIR" --config "$BUILD_TYPE" --parallel "$(sysctl -n hw.logicalcpu)"
else
    cmake --build "$BUILD_DIR" --parallel "$(sysctl -n hw.logicalcpu)"
fi

# ── macdeployqt: bundle Qt frameworks into the .app ──────────────────────────
APP_BUNDLE=$(find "$BUILD_DIR" -name "neurx-codeApp.app" -maxdepth 3 | head -1)

if [ -n "$APP_BUNDLE" ] && [ -n "$QT_CMAKE_PREFIX" ]; then
    MACDEPLOYQT="$QT_CMAKE_PREFIX/bin/macdeployqt"
    if [ -f "$MACDEPLOYQT" ]; then
        echo "[macos] Running macdeployqt on $APP_BUNDLE …"
        "$MACDEPLOYQT" "$APP_BUNDLE" \
            -qmldir="$PROJECT_DIR" \
            -dmg \
            -always-overwrite
        DMG=$(find "$BUILD_DIR" -name "*.dmg" | head -1)
        echo ""
        echo "✓ DMG created: ${DMG:-$BUILD_DIR/}"
    fi
fi

echo ""
echo "✓ Build complete: ${APP_BUNDLE:-$BUILD_DIR}"
echo "  Run:  open '${APP_BUNDLE:-$BUILD_DIR/neurx-codeApp.app}'"
echo ""
