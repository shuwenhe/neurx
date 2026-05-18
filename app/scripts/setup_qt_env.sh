#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QT_ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$QT_ROOT_DIR/.." && pwd)"

log() {
    printf '[qt-setup] %s\n' "$1"
}

detect_qt6_dir_linux() {
    local candidates=(
        /usr/lib/x86_64-linux-gnu/cmake/Qt6
        /usr/lib64/cmake/Qt6
        /usr/lib/cmake/Qt6
        /usr/local/lib/cmake/Qt6
    )

    for p in "${candidates[@]}"; do
        if [[ -d "$p" ]]; then
            printf '%s' "$p"
            return 0
        fi
    done

    if command -v qtpaths6 >/dev/null 2>&1; then
        local prefix
        prefix="$(qtpaths6 --install-prefix 2>/dev/null || true)"
        if [[ -n "$prefix" && -d "$prefix/lib/cmake/Qt6" ]]; then
            printf '%s' "$prefix/lib/cmake/Qt6"
            return 0
        fi
    fi

    return 1
}

install_qt_linux() {
    if command -v apt-get >/dev/null 2>&1; then
        log "Installing Qt6 for Debian/Ubuntu"
        sudo apt-get update
        sudo apt-get install -y \
            qt6-base-dev \
            qt6-declarative-dev \
            qt6-declarative-dev-tools \
            qt6-tools-dev-tools \
            qml6-module-qtquick \
            qml6-module-qtquick-window \
            qml6-module-qtquick-layouts \
            qml6-module-qtquick-controls \
            qml6-module-qtquick-templates \
            cmake \
            ninja-build \
            pkg-config
        return
    fi

    if command -v dnf >/dev/null 2>&1; then
        log "Installing Qt6 for Fedora/RHEL"
        sudo dnf install -y qt6-qtbase-devel qt6-qttools-devel cmake ninja-build gcc-c++
        return
    fi

    if command -v pacman >/dev/null 2>&1; then
        log "Installing Qt6 for Arch"
        sudo pacman -Sy --noconfirm qt6-base qt6-tools cmake ninja
        return
    fi

    log "Unsupported Linux package manager. Install Qt6 manually and rerun this script."
    exit 1
}

configure_macos() {
    if ! command -v brew >/dev/null 2>&1; then
        log "Homebrew is required on macOS."
        exit 1
    fi

    log "Installing Qt with Homebrew"
    brew install qt cmake ninja

    local qt_prefix
    qt_prefix="$(brew --prefix qt)"
    local qt6_dir="$qt_prefix/lib/cmake/Qt6"

    cat > "$QT_ROOT_DIR/.env.qt" <<EOF
export CMAKE_PREFIX_PATH="$qt_prefix"
export Qt6_DIR="$qt6_dir"
export NEURX_ROOT="$PROJECT_ROOT"
EOF

    log "Wrote $QT_ROOT_DIR/.env.qt"
    log "Run: source $QT_ROOT_DIR/.env.qt"
}

configure_linux() {
    install_qt_linux

    local qt6_dir
    qt6_dir="$(detect_qt6_dir_linux || true)"
    if [[ -z "$qt6_dir" ]]; then
        log "Qt6 was installed but Qt6_DIR was not detected. Set Qt6_DIR manually."
        exit 1
    fi

    local cmake_prefix
    cmake_prefix="$(cd "$qt6_dir/../../.." && pwd)"

    cat > "$QT_ROOT_DIR/.env.qt" <<EOF
export CMAKE_PREFIX_PATH="$cmake_prefix"
export Qt6_DIR="$qt6_dir"
export NEURX_ROOT="$PROJECT_ROOT"
EOF

    log "Wrote $QT_ROOT_DIR/.env.qt"
    log "Run: source $QT_ROOT_DIR/.env.qt"
}

main() {
    local os
    os="$(uname -s)"

    case "$os" in
        Linux)
            configure_linux
            ;;
        Darwin)
            configure_macos
            ;;
        *)
            log "Unsupported OS: $os"
            exit 1
            ;;
    esac
}

main "$@"
