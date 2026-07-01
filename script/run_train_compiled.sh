#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
S_COMPILER="${S_COMPILER:-/Users/feifei/shuwen/train/s/.local/bin/s}"
BUILD_DIR="$NEURX_ROOT/build/large_model_training"
TRAIN_SCRIPT="$NEURX_ROOT/train/train_large_model_simple.s"

# 编译S脚本到IR
echo "编译S源代码..."
"$S_COMPILER" "$TRAIN_SCRIPT" "$BUILD_DIR/train.ir"

# 检查编译是否成功
if [ -f "$BUILD_DIR/train.ir" ]; then
    echo "✓ S源代码已编译为IR"
    
    # 显示IR内容（用于调试）
    echo ""
    echo "=== 生成的IR代码 ==="
    head -50 "$BUILD_DIR/train.ir"
    echo "..."
else
    echo "✗ 编译失败"
    exit 1
fi

# 尝试从S编译器目录生成二进制
echo ""
echo "生成二进制..."
cd "$NEURX_ROOT/../s" && "$S_COMPILER" --emit-bin "$BUILD_DIR/train.ir" "$BUILD_DIR/train.bin"

# 检查二进制是否生成
if [ -f "$BUILD_DIR/train.bin" ]; then
    echo "✓ 二进制文件已生成"
    ls -lh "$BUILD_DIR/train.bin"
    
    echo ""
    echo "尝试执行..."
    "$BUILD_DIR/train.bin"
else
    echo "✗ 二进制生成失败"
    exit 1
fi
