#!/usr/bin/env bash
set -euo pipefail
# setup_ssh_keys.sh
# Generate an SSH key (if missing) and copy it to one or more remote hosts.
# Usage:
#   WORKER_HOSTS="root@112.29.145.15 root@host2" ./setup_ssh_keys.sh
# Or pass hosts as args:
#   ./setup_ssh_keys.sh root@112.29.145.15

KEY_PATH=${KEY_PATH:-$HOME/.ssh/neurx_id_rsa}
WORKER_PASS=${WORKER_PASS:-}

if [ $# -gt 0 ]; then
  HOSTS=("$@")
elif [ -n "${WORKER_HOSTS:-}" ]; then
  read -r -a HOSTS <<< "$WORKER_HOSTS"
else
  echo "Usage: WORKER_HOSTS=\"root@host1 root@host2\" $0" >&2
  echo "       or: $0 root@host1 [root@host2 ...]" >&2
  exit 2
fi

if [ ! -f "$KEY_PATH" ]; then
  echo "Generating SSH key at $KEY_PATH"
  mkdir -p "$(dirname "$KEY_PATH")"
  ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N "" -C "neurx-ssh-key"
else
  echo "Using existing key: $KEY_PATH"
fi

PUB_KEY="$KEY_PATH.pub"
if [ ! -f "$PUB_KEY" ]; then
  echo "Public key not found: $PUB_KEY" >&2
  exit 3
fi

for host in "${HOSTS[@]}"; do
  echo "Copying key to $host"
  if command -v ssh-copy-id >/dev/null 2>&1; then
    if [ -n "$WORKER_PASS" ] && command -v sshpass >/dev/null 2>&1; then
      sshpass -p "$WORKER_PASS" ssh-copy-id -i "$PUB_KEY" -o StrictHostKeyChecking=no "$host"
    else
      ssh-copy-id -i "$PUB_KEY" -o StrictHostKeyChecking=no "$host" || true
      # ssh-copy-id returns non-zero if key already present; ignore
    fi
  else
    # Fallback: append pubkey via ssh
    if [ -n "$WORKER_PASS" ] && command -v sshpass >/dev/null 2>&1; then
      sshpass -p "$WORKER_PASS" ssh -o StrictHostKeyChecking=no "$host" "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys" < "$PUB_KEY"
    else
      echo "ssh-copy-id not found; running manual append (you will be prompted for password)"
      cat "$PUB_KEY" | ssh -o StrictHostKeyChecking=no "$host" 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'
    fi
  fi

  echo "Testing SSH connection to $host"
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" 'echo SSH_OK' || echo "SSH to $host failed (maybe verify host key or password needed)"
done

echo "Done. You can now ssh -i $KEY_PATH <host>"
