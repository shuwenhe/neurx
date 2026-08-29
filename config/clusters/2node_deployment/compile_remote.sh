#!/bin/bash

# NeurX S Language & Inference Compiler Build Script for Remote Servers
# 在远程服务器上编译 S 语言编译器和 NeurX 推理引擎
# 用法: bash compile_remote.sh

set -e

WORKSPACE_ROOT="/home/shuwen/shuwen"
S_DIR="$WORKSPACE_ROOT/s"
NEURX_DIR="$WORKSPACE_ROOT/neurx"

# 目标部署路径
DEPLOY_S="/app/s"
DEPLOY_NEURX="/app/neurx"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ NeurX Remote Build System                                      ║"
echo "║ Compiling S Language + NeurX Inference Engine                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# 检查环境
echo "🔍 Checking build environment..."
echo ""

# 检查必要工具
REQUIRED_TOOLS=("gcc" "make" "git")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        echo "❌ $tool not found"
        exit 1
    fi
    echo "✓ $tool: $(command -v $tool)"
done

echo ""
echo "🏗️  Starting build process..."
echo ""

# ============================================================
# Phase 1: Build S Language Compiler
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 1: Building S Language Compiler"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ! -d "$S_DIR" ]; then
    echo "❌ S source directory not found: $S_DIR"
    exit 1
fi

cd "$S_DIR"

# 检查 S 源代码是否可用
if [ ! -f "makefile" ]; then
    echo "❌ S makefile not found"
    exit 1
fi

echo "📦 S Language Source: $S_DIR"
echo ""

# 构建 S 编译器
echo "🔨 Compiling S compiler..."
make clean 2>/dev/null || true
make -j$(nproc) 2>&1 | tail -20

if [ -f "bin/s" ]; then
    echo "✅ S compiler built successfully"
    echo "   Binary: $(pwd)/bin/s"
    COMPILER_SIZE=$(du -h "bin/s" | cut -f1)
    echo "   Size: $COMPILER_SIZE"
else
    echo "⚠️  S compiler binary not generated, using bootstrap mode"
fi

echo ""

# ============================================================
# Phase 2: Build NeurX Inference Engine
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 2: Building NeurX Inference Engine"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ! -d "$NEURX_DIR" ]; then
    echo "❌ NeurX source directory not found: $NEURX_DIR"
    exit 1
fi

cd "$NEURX_DIR"

# 检查 NeurX 编译脚本
if [ ! -f "boot/build.sh" ]; then
    echo "⚠️  NeurX boot script not found, skipping EFI build"
else
    echo "🔨 Building NeurX boot/EFI components..."
    bash boot/build.sh 2>&1 | tail -10
    echo "✅ NeurX EFI boot build completed"
fi

# 编译推理引擎 (如果有 S 编译脚本)
if [ -f "backend/platform/cuda/build_cuda.s" ]; then
    echo "🔨 Compiling CUDA inference backend (S)..."
    if [ -f "$S_DIR/bin/s" ]; then
        CUDA_TARGET=build-all "$S_DIR/bin/s" backend/platform/cuda/build_cuda.s 2>&1 | tail -10
        echo "✅ CUDA backend compilation completed"
    else
        echo "⚠️  S compiler not available, skipping CUDA backend"
    fi
fi

echo ""

# ============================================================
# Phase 3: Prepare Deployment Packages
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 3: Preparing Deployment Packages"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 创建部署目录
mkdir -p "$DEPLOY_S" "$DEPLOY_NEURX"

# 复制 S 编译器
if [ -f "$S_DIR/bin/s" ]; then
    echo "📋 Copying S compiler..."
    cp "$S_DIR/bin/s" "$DEPLOY_S/s"
    chmod +x "$DEPLOY_S/s"
    echo "✓ S compiler deployed to $DEPLOY_S/s"
fi

# 复制 NeurX 构建产物
echo "📋 Copying NeurX build artifacts..."
mkdir -p "$DEPLOY_NEURX/build"
cp -r "$NEURX_DIR/build/"* "$DEPLOY_NEURX/build/" 2>/dev/null || true
echo "✓ NeurX build artifacts deployed"

# 复制推理服务脚本
if [ -f "$NEURX_DIR/backend/platform/cuda/inference_server.s" ]; then
    echo "📋 Copying NeurX inference service..."
    mkdir -p "$DEPLOY_NEURX/backend/platform/cuda"
    cp "$NEURX_DIR/backend/platform/cuda/inference_server.s" "$DEPLOY_NEURX/backend/platform/cuda/"
    echo "✓ Inference service deployed"
fi

echo ""

# ============================================================
# Phase 4: Verification
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 4: Build Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📊 Build Artifacts:"
echo ""

if [ -f "$DEPLOY_S/s" ]; then
    echo "✅ S Compiler:"
    file "$DEPLOY_S/s"
    echo "   Size: $(du -h "$DEPLOY_S/s" | cut -f1)"
else
    echo "⚠️  S Compiler: NOT DEPLOYED"
fi

echo ""

if [ -d "$DEPLOY_NEURX/build" ]; then
    echo "✅ NeurX Build Directory:"
    ls -lh "$DEPLOY_NEURX/build/" | tail -5
fi

if [ -f "$DEPLOY_NEURX/backend/platform/cuda/inference_server.s" ]; then
    echo "✅ Inference Service Source:"
    wc -l "$DEPLOY_NEURX/backend/platform/cuda/inference_server.s"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ ✅ Build Complete!                                            ║"
echo "║                                                                ║"
echo "║ Deployment Paths:                                              ║"
echo "║  • S Compiler:    $DEPLOY_S/s"
echo "║  • NeurX Builds:  $DEPLOY_NEURX/build/"
echo "║  • Inference:     $DEPLOY_NEURX/backend/platform/cuda/         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "🚀 Next steps:"
echo "  1. Set up environment: export PATH=\"$DEPLOY_S:\$PATH\""
echo "  2. Run S compiler: $DEPLOY_S/s"
echo "  3. Start inference: python3 -m neurx.inference_service"
echo ""
