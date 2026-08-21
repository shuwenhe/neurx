#!/bin/bash
# Start NeurX Web UI Frontend in background

set -e

export NEURX_ROOT="${1:-.}"

FRONTEND_IR="${NEURX_ROOT}/artifacts/build/production_s_inference/web_ui_server.ir"
S_RUNNER="${NEURX_ROOT}/artifacts/build/s_runner/s_ir_runner"

# Kill old processes
pkill -9 -f "s_ir_runner.*web_ui_server" 2>/dev/null || true
sleep 1

# Start frontend
echo "🌐 Starting NeurX Web UI on port 8081..."
nohup "$S_RUNNER" "$FRONTEND_IR" >/tmp/neurx_frontend.log 2>&1 &

# Wait for initialization
sleep 3

# Verify
if lsof -i :8081 2>/dev/null | grep -q LISTEN; then
    echo "✅ Frontend is running on port 8081"
    echo "🌐 Access UI: http://127.0.0.1:8081"
    echo "📋 Log: tail -f /tmp/neurx_frontend.log"
    echo "🛑 Stop: make frontend-stop"
    exit 0
else
    echo "❌ Frontend failed. Check: tail /tmp/neurx_frontend.log"
    tail -10 /tmp/neurx_frontend.log
    exit 1
fi
    tail -10 /tmp/neurx_frontend.log
    exit 1
fi
