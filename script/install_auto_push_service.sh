#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_SRC="${REPO_ROOT}/systemd/neurx-auto-push.service"
SERVICE_DST="/etc/systemd/system/neurx-auto-push.service"

if [[ ! -f "${SERVICE_SRC}" ]]; then
  echo "Service file not found: ${SERVICE_SRC}" >&2
  exit 1
fi

cp "${SERVICE_SRC}" "${SERVICE_DST}"
systemctl daemon-reload
systemctl enable --now neurx-auto-push.service
systemctl status neurx-auto-push.service --no-pager