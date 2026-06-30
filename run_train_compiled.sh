#!/bin/bash

# 编译S脚本到IR
echo "编译S源代码..."
/Users/feifei/train/s/.local/bin/s /Users/feifei/shuwen/neurx/train/train_large_model_simple.s /Users/feifei/shuwen/neurx/build/large_model_training/train.ir

# 检查编译是否成功
if [ -f /Users/feifei/shuwen/neurx/build/large_model_training/train.ir ]; then
    echo "✓ S源代码已编译为IR"
    
    # 显示IR内容（用于调试）
    echo ""
    echo "=== 生成的IR代码 ==="
    head -50 /Users/feifei/shuwen/neurx/build/large_model_training/train.ir
    echo "..."
else
    echo "✗ 编译失败"
    exit 1
fi

# 尝试从S编译器目录生成二进制
echo ""
echo "生成二进制..."
cd /Users/feifei/train/s && /Users/feifei/train/s/.local/bin/s --emit-bin /Users/feifei/shuwen/neurx/build/large_model_training/train.ir /Users/feifei/shuwen/neurx/build/large_model_training/train.bin

# 检查二进制是否生成
if [ -f /Users/feifei/shuwen/neurx/build/large_model_training/train.bin ]; then
    echo "✓ 二进制文件已生成"
    ls -lh /Users/feifei/shuwen/neurx/build/large_model_training/train.bin
    
    echo ""
    echo "尝试执行..."
    /Users/feifei/shuwen/neurx/build/large_model_training/train.bin
else
    echo "✗ 二进制生成失败"
    exit 1
fi
