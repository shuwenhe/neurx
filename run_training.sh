#!/bin/bash

# NeurX 训练系统启动脚本

echo "======================================================================="
echo "NeurX 深度学习框架 - 纯 S 语言训练系统"
echo "======================================================================="
echo ""

# 进入项目目录
cd /Users/feifei/train/neurx

# 创建 build 目录
echo "✓ 创建 build 目录..."
mkdir -p build
echo ""

# 编译 S 语言文件
echo "✓ 编译 S 语言文件 (training_system.s)..."
echo "  使用编译器: /Users/feifei/train/s/bin/s"
echo ""

/Users/feifei/train/s/bin/s compile training_system.s -o build/training_system.ir

if [ $? -ne 0 ]; then
    echo "❌ 编译失败!"
    exit 1
fi

echo ""
echo "✓ 编译成功！生成文件: build/training_system.ir"
echo ""
echo "======================================================================="
echo "开始运行训练..."
echo "======================================================================="
echo ""

# 运行编译后的程序
./build/training_system

echo ""
echo "======================================================================="
echo "训练完成！"
echo "======================================================================="
