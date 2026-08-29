#!/bin/bash

# Setup + Build Script for NeurX on Remote Servers
# 首先安装依赖，然后编译 S 和 NeurX

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ NeurX Remote Setup & Compile                                  ║"
echo "║ Auto-installing dependencies + building                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# 获取系统信息
SYSTEM=$(uname -s)
ARCH=$(uname -m)

echo "System: $SYSTEM"
echo "Architecture: $ARCH"
echo ""

# ============================================================
# Phase 0: Install Dependencies
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 0: Installing Build Dependencies"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v apt-get &> /dev/null; then
    echo "🔧 Detected Debian/Ubuntu, installing with apt-get..."
    sudo apt-get update >/dev/null 2>&1
    sudo apt-get install -y build-essential gcc make git curl wget python3 python3-pip >/dev/null 2>&1
    echo "✅ Dependencies installed"
elif command -v yum &> /dev/null; then
    echo "🔧 Detected RedHat/CentOS, installing with yum..."
    sudo yum install -y gcc make git curl wget python3 python3-pip >/dev/null 2>&1
    echo "✅ Dependencies installed"
elif command -v brew &> /dev/null; then
    echo "🔧 Detected macOS, installing with brew..."
    brew install gcc make git >/dev/null 2>&1
    echo "✅ Dependencies installed"
else
    echo "⚠️  Package manager not found, skipping auto-install"
    echo "   Please install: gcc, make, git manually"
fi

echo ""

# ============================================================
# Phase 1: Verify Tools
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 1: Verifying Build Tools"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TOOLS_FOUND=0
for tool in gcc make git python3; do
    if command -v "$tool" &> /dev/null; then
        VERSION=$($tool --version 2>&1 | head -1 || echo "unknown")
        echo "✅ $tool: $VERSION"
        ((TOOLS_FOUND++))
    else
        echo "❌ $tool: NOT FOUND"
    fi
done

echo ""
if [ $TOOLS_FOUND -lt 4 ]; then
    echo "⚠️  Some tools are missing. Build may fail."
fi

echo ""

# ============================================================
# Phase 2: Setup Workspace
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 2: Setting up Workspace"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

WORKSPACE_ROOT="${HOME}/shuwen"
S_DIR="$WORKSPACE_ROOT/s"
NEURX_DIR="$WORKSPACE_ROOT/neurx"

echo "Workspace: $WORKSPACE_ROOT"
echo "S source: $S_DIR"
echo "NeurX source: $NEURX_DIR"
echo ""

if [ ! -d "$S_DIR" ]; then
    echo "⚠️  S directory not found, will skip S compilation"
else
    echo "✓ S directory found"
fi

if [ ! -d "$NEURX_DIR" ]; then
    echo "⚠️  NeurX directory not found, will skip NeurX compilation"
else
    echo "✓ NeurX directory found"
fi

echo ""

# ============================================================
# Phase 3: Build S Language
# ============================================================
if [ -d "$S_DIR" ] && [ -f "$S_DIR/makefile" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Phase 3: Building S Language Compiler"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    cd "$S_DIR"
    
    echo "🔨 Compiling S..."
    if make -j$(nproc) 2>&1 | tail -30; then
        if [ -f "bin/s" ]; then
            echo ""
            echo "✅ S compiler built successfully!"
            ls -lh bin/s
            
            # 部署到 /app/s
            echo ""
            echo "📦 Deploying S compiler..."
            mkdir -p /app/s
            cp bin/s /app/s/s
            chmod +x /app/s/s
            echo "✓ S deployed to /app/s/s"
        fi
    else
        echo "⚠️  S compilation had issues, check output above"
    fi
else
    echo "⚠️  S source not found, skipping S compilation"
fi

echo ""

# ============================================================
# Phase 4: Build NeurX
# ============================================================
if [ -d "$NEURX_DIR" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Phase 4: Building NeurX"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    cd "$NEURX_DIR"
    
    # 编译 EFI 启动
    if [ -f "boot/build.sh" ]; then
        echo "🔨 Building NeurX EFI Boot..."
        if bash boot/build.sh 2>&1 | tail -20; then
            echo "✅ NeurX EFI build completed"
        else
            echo "⚠️  NeurX EFI build had issues"
        fi
    fi
    
    echo ""
    
    # 部署到 /app/neurx
    echo "📦 Deploying NeurX..."
    mkdir -p /app/neurx/build
    mkdir -p /app/neurx/backend/platform/cuda
    
    if [ -d "build" ]; then
        cp -r build/* /app/neurx/build/ 2>/dev/null || true
        echo "✓ NeurX build artifacts deployed"
    fi
    
    if [ -f "backend/platform/cuda/inference_server.s" ]; then
        cp backend/platform/cuda/inference_server.s /app/neurx/backend/platform/cuda/
        echo "✓ Inference server deployed"
    fi
else
    echo "⚠️  NeurX source not found, skipping NeurX compilation"
fi

echo ""

# ============================================================
# Phase 5: Verification
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 5: Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📊 Build Artifacts:"
echo ""

if [ -f "/app/s/s" ]; then
    echo "✅ S Compiler:"
    file /app/s/s
    ls -lh /app/s/s
else
    echo "⚠️  S Compiler: NOT FOUND"
fi

echo ""

if [ -d "/app/neurx/build" ]; then
    echo "✅ NeurX Build:"
    ls -lh /app/neurx/build/ 2>/dev/null | head -5
fi

echo ""

# ============================================================
# Completion
# ============================================================
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ ✅ Build & Setup Complete!                                    ║"
echo "║                                                                ║"
echo "║ Deployment Summary:                                            ║"
echo "║  • S Compiler:    /app/s/s"
echo "║  • NeurX Build:   /app/neurx/build/"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "🚀 Next steps on this server:"
echo "  1. export PATH=\"/app/s:\$PATH\""
echo "  2. Run: /app/s/s --version"
echo "  3. Verify build: ls -la /app/neurx/build/"
echo ""
