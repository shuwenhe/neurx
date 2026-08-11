#!/usr/bin/env bash
set -euo pipefail

log() {
    printf '%s\n' "$*"
}

have() {
    command -v "$1" >/dev/null 2>&1
}

need_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log "root required"
        exit 1
    fi
}

has_nvidia_pci() {
    for vendor in /sys/bus/pci/devices/*/vendor; do
        [ -e "$vendor" ] || continue
        if [ "$(cat "$vendor")" = "0x10de" ]; then
            return 0
        fi
    done
    return 1
}

module_loaded() {
    grep -q "^$1 " /proc/modules 2>/dev/null
}

load_module() {
    if module_loaded "$1"; then
        log "module ok: $1"
        return 0
    fi
    if have modprobe && modprobe "$1"; then
        log "module loaded: $1"
        return 0
    fi
    log "module load failed: $1"
    return 1
}

ensure_node() {
    path="$1"
    major="$2"
    minor="$3"
    mode="$4"
    group="$5"
    if [ ! -c "$path" ]; then
        rm -f "$path"
        mknod "$path" c "$major" "$minor"
    fi
    chown root:"$group" "$path" 2>/dev/null || true
    chmod "$mode" "$path" 2>/dev/null || true
}

check_smi() {
    if ! have nvidia-smi; then
        log "nvidia-smi missing"
        return 1
    fi
    if nvidia-smi -L; then
        return 0
    fi
    return 1
}

repair() {
    load_module nvidia || true
    load_module nvidia_uvm || true
    load_module nvidia_modeset || true
    load_module nvidia_drm || true
    if have nvidia-modprobe; then
        nvidia-modprobe -u -c=0 || true
    fi
    group=video
    if ! getent group video >/dev/null 2>&1; then
        group=root
    fi
    ensure_node /dev/nvidiactl 195 255 660 "$group"
    ensure_node /dev/nvidia0 195 0 660 "$group"
    ensure_node /dev/nvidia-modeset 195 254 660 "$group"
    ensure_node /dev/nvidia-uvm 510 0 660 "$group"
    ensure_node /dev/nvidia-uvm-tools 510 1 660 "$group"
}

main() {
    need_root
    if ! has_nvidia_pci; then
        log "no nvidia pci device"
        exit 0
    fi
    log "nvidia pci device detected"
    if check_smi; then
        log "nvidia-smi ok"
        exit 0
    fi
    log "nvidia-smi failed, repairing"
    repair
    if check_smi; then
        log "repair ok"
        exit 0
    fi
    log "repair failed"
    if have dmesg; then
        dmesg | tail -n 40 || true
    fi
    exit 1
}

main "$@"
