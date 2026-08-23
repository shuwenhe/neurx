#!/bin/bash

set -e

NEURX_HOME="${NEURX_HOME:-/app/neurx}"
NEURX_MODEL_DIR="${NEURX_MODEL_DIR:-/models/default}"
NEURX_INFER_DEVICE="${NEURX_INFER_DEVICE:-cpu}"
NEURX_S_PORT="${NEURX_S_PORT:-8000}"
NEURX_S_HOST="${NEURX_S_HOST:-0.0.0.0}"
NEURX_CPU_THREADS="${NEURX_CPU_THREADS:-4}"
NEURX_CHAT_MAX_NEW_TOKENS="${NEURX_CHAT_MAX_NEW_TOKENS:-512}"

BACKEND_PORT=9000
FRONTEND_PORT=8000

mkdir -p /etc/nginx /var/log/nginx /var/cache/nginx

cat > /etc/nginx/nginx.conf << 'EOF'
user root;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    access_log /var/log/nginx/access.log;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    upstream neurx_backend {
        server 127.0.0.1:9000;
        keepalive 64;
    }

    server {
        listen 0.0.0.0:8000;
        listen [::]:8000;
        server_name _;
        client_max_body_size 100M;

        location / {
            proxy_pass http://neurx_backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_read_timeout 600s;
            proxy_connect_timeout 60s;
        }
    }
}
EOF

echo "[INFO] Starting NeurX with nginx proxy..."
echo "[INFO] Backend will run on port $BACKEND_PORT"
echo "[INFO] Frontend nginx will listen on 0.0.0.0:$FRONTEND_PORT"

export NEURX_S_PORT="${BACKEND_PORT}"
export NEURX_S_HOST="127.0.0.1"

if [ "$NEURX_INFER_DEVICE" == "gpu" ]; then
    BACKEND_IR="/app/neurx/artifacts/build/production_s_inference/gpu_backend_enhanced.ir"
else
    BACKEND_IR="/app/neurx/artifacts/build/production_s_inference/cpu_backend.ir"
fi

/app/neurx/artifacts/build/s_runner/s_ir_runner "$BACKEND_IR" > /var/log/neurx/backend.log 2>&1 &
BACKEND_PID=$!

sleep 5

if ! kill -0 $BACKEND_PID 2>/dev/null; then
    echo "[ERROR] Backend failed to start"
    cat /var/log/neurx/backend.log
    exit 1
fi

echo "[INFO] Backend PID: $BACKEND_PID"
echo "[INFO] Starting nginx proxy..."

nginx -g "daemon off;" &
NGINX_PID=$!

echo "[INFO] Nginx PID: $NGINX_PID"
echo "[✓] NeurX service ready at 0.0.0.0:8000"

wait $BACKEND_PID $NGINX_PID
