#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-18080}"

echo "neurx s-backend http wrapper listening on 127.0.0.1:${PORT}" >&2

if command -v socat >/dev/null 2>&1; then
  # Drop benign disconnect noise from socat while keeping real backend errors visible.
  exec socat \
    TCP-LISTEN:"${PORT}",bind=127.0.0.1,reuseaddr,fork \
    SYSTEM:"${SCRIPT_DIR}/http_handler.sh" \
    2> >(awk '
      /Broken pipe/ { next }
      /exiting on signal 15/ { next }
      { print > "/dev/stderr" }
    ')
fi

if command -v node >/dev/null 2>&1; then
  export NEURX_BASH="${BASH:-bash}"
  exec node "${SCRIPT_DIR}/http_server_node.js"
fi

if command -v python3 >/dev/null 2>&1; then
  export NEURX_BASH="${BASH:-bash}"
  exec python3 - "${SCRIPT_DIR}" "${PORT}" <<'PYEOF'
import sys, socket, threading, subprocess, os, traceback

script_dir = sys.argv[1]
port = int(sys.argv[2])
handler = os.path.join(script_dir, "http_handler.sh")
bash = os.environ.get("NEURX_BASH", "bash")

def handle(conn):
    try:
        data = b""
        while b"\r\n\r\n" not in data:
            chunk = conn.recv(4096)
            if not chunk:
                break
            data += chunk
        header_part, _, rest = data.partition(b"\r\n\r\n")
        headers = header_part.decode(errors="replace")
        content_length = 0
        for line in headers.splitlines():
            if line.lower().startswith("content-length:"):
                try:
                    content_length = int(line.split(":", 1)[1].strip())
                except ValueError:
                    pass
        body = rest
        while len(body) < content_length:
            chunk = conn.recv(4096)
            if not chunk:
                break
            body += chunk
        proc = subprocess.run(
            [bash, handler],
            input=header_part + b"\r\n\r\n" + body,
            capture_output=False,
            stdout=subprocess.PIPE,
            stderr=sys.stderr.fileno(),
        )
        conn.sendall(proc.stdout)
    except Exception:
        traceback.print_exc(file=sys.stderr)
    finally:
        try:
            conn.close()
        except Exception:
            pass

srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", port))
srv.listen(64)
while True:
    conn, _ = srv.accept()
    threading.Thread(target=handle, args=(conn,), daemon=True).start()
PYEOF
fi

echo "Error: neither socat nor node nor python3 is available on PATH." >&2
exit 1
