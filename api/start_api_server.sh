#!/bin/bash
# NeurX API Server Startup Script

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_PORT=${API_PORT:-8000}
API_HOST=${API_HOST:-0.0.0.0}
NEURX_MODEL_PATH=${NEURX_MODEL_PATH:-/app/shuwen/model/Qwen2.5-0.5B-Instruct}

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          NeurX REST API Server - Startup                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Configuration:"
echo "  Project Root: $PROJECT_ROOT"
echo "  Model Path:   $NEURX_MODEL_PATH"
echo "  Host:         $API_HOST"
echo "  Port:         $API_PORT"
echo ""

# Check model files
if [ ! -f "$NEURX_MODEL_PATH/model.safetensors" ]; then
    echo "❌ Error: Model file not found at $NEURX_MODEL_PATH/model.safetensors"
    echo "   Please download the model first:"
    echo "   python -m huggingface_hub download Qwen/Qwen2.5-0.5B-Instruct \\"
    echo "     --local-dir $NEURX_MODEL_PATH"
    exit 1
fi
echo "✓ Model file found: $NEURX_MODEL_PATH/model.safetensors"

# Check dependencies
echo ""
echo "📦 Checking Python dependencies..."
python3 -c "import fastapi" 2>/dev/null || {
    echo "  Installing FastAPI..."
    pip install -q fastapi uvicorn pydantic
}
echo "✓ Dependencies ready"

# Start API server
echo ""
echo "🚀 Starting API server..."
echo ""

export NEURX_MODEL_PATH="$NEURX_MODEL_PATH"
export API_HOST="$API_HOST"
export API_PORT="$API_PORT"

cd "$PROJECT_ROOT"
python3 neurx_api_server.py
