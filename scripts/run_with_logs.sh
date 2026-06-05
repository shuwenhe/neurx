#!/bin/bash

# 运行NeurX Code并显示诊断日志
echo "🚀 启动 NeurX Code（带诊断日志）..."
echo ""
echo "⚠️  说明："
echo "  1. 应用启动后，打开一个文件夹作为工作空间"
echo "  2. 尝试创建文件夹"
echo "  3. 下面会显示诊断日志"
echo ""
echo "═══════════════════════════════════════════════════════════════"

# 运行应用并捕获输出
./build/neurx-codeApp.app/Contents/MacOS/neurx-codeApp 2>&1 | grep -E '\[createWorkspaceEntry\]|\[isPathInsideWorkspace\]'
