#!/bin/bash

# Verify Installation & Create Test Environment
# This script sets up the environment for compilation and testing

echo "🔍 Verifying NeurX Production System Setup"
echo "═════════════════════════════════════════════════════════"
echo ""

# Check Python availability
if command -v python3 &> /dev/null; then
    echo "✅ Python3: $(python3 --version)"
else
    echo "⚠️  Python3 not found"
fi

# Check for neurx-cli or similar
if command -v neurx &> /dev/null; then
    echo "✅ NeurX CLI: $(neurx --version 2>/dev/null || echo 'found')"
elif command -v neurxc &> /dev/null; then
    echo "✅ NeurX Compiler: $(neurxc --version 2>/dev/null || echo 'found')"
else
    echo "⚠️  NeurX CLI not found in PATH"
fi

# Check CUDA availability
if command -v nvidia-smi &> /dev/null; then
    echo "✅ NVIDIA GPU Found:"
    nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader | sed 's/^/   GPU /'
else
    echo "ℹ️  NVIDIA GPU not detected (CPU-only mode)"
fi

# Check Docker
if command -v docker &> /dev/null; then
    echo "✅ Docker: $(docker --version)"
else
    echo "ℹ️  Docker not installed"
fi

# Check Kubernetes
if command -v kubectl &> /dev/null; then
    echo "✅ Kubernetes: $(kubectl version --short 2>/dev/null | head -1)"
else
    echo "ℹ️  Kubernetes not installed"
fi

echo ""
echo "📁 Checking Source Files:"
echo "─────────────────────────────────────────────────────────"

for file in training/scaled_training_system.s dataset/real_data_loader.s cuda/cuda_accelerated_training.s distributed/ddp_distributed_training.s; do
    if [ -f "$file" ]; then
        lines=$(wc -l < "$file")
        echo "✅ $file ($lines lines)"
    else
        echo "❌ $file NOT FOUND"
    fi
done

echo ""
echo "═════════════════════════════════════════════════════════"
echo ""
echo "🚀 Ready to compile. Use: bash compile_all_components.sh"
echo ""
