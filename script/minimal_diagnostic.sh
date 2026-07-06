#!/bin/bash

# 最小化诊断：检查关键日志是否出现

set -e

echo "=================================================="
echo "NeurX Code - 最小化诊断工具"
echo "=================================================="
echo ""
echo "这个脚本会启动应用并监控关键日志"
echo ""

WORKSPACE="/Users/feifei/agent/neurx-code"
APP_PATH="/Users/feifei/agent/neurx-code/build/neurx-codeApp.app/Contents/MacOS/neurx-codeApp"
LOG_FILE="/tmp/neurx_minimal_test.log"

# 清空日志
> "$LOG_FILE"

echo "📊 启动应用并记录日志..."
echo "   日志文件：$LOG_FILE"
echo ""
echo "⚠️  应用启动后，请在 30 秒内："
echo "   1. 点击菜单 File"
echo "   2. 选择 Open Workspace"
echo "   3. 选择目录：$WORKSPACE"
echo "   4. 点击 Open"
echo ""
echo "然后等待日志出现..."
echo ""
echo "按 Enter 开始..."
read

# 在后台启动应用
"$APP_PATH" 2>&1 | tee -a "$LOG_FILE" &
APP_PID=$!

echo ""
echo "⏳ 等待 35 秒以收集日志..."
sleep 35

# 杀死应用
kill $APP_PID 2>/dev/null || true
wait $APP_PID 2>/dev/null || true

echo ""
echo ""
echo "=================================================="
echo "📋 诊断结果"
echo "=================================================="
echo ""

# 检查关键日志
echo "✅ 检查项 1：工作空间设置"
if grep -q "setWorkspacePath" "$LOG_FILE"; then
    WORKSPACE_SET=$(grep "setWorkspacePath" "$LOG_FILE" | head -1)
    echo "   ✅ 已检测到工作空间设置"
    echo "      $WORKSPACE_SET"
else
    echo "   ❌ 未检测到工作空间设置"
    echo "   → 您需要在应用中 File -> Open Workspace"
fi

echo ""
echo "✅ 检查项 2：Write 工具注册"
if grep -q "Registering tool: Write" "$LOG_FILE"; then
    echo "   ✅ Write 工具已注册"
    grep "Registering tool: Write" "$LOG_FILE" | head -1
else
    echo "   ❌ Write 工具未注册"
    echo "   → 可能是工作空间未打开，或注册过程失败"
fi

echo ""
echo "✅ 检查项 3：NeurX Standard Tools 注册完成"
if grep -q "NeurX Standard Tools registered" "$LOG_FILE"; then
    echo "   ✅ NeurX Standard Tools 已完成注册"
else
    echo "   ❌ NeurX Standard Tools 注册未完成"
fi

echo ""
echo "=================================================="
echo "📊 详细日志分析"
echo "=================================================="
echo ""

echo "工作空间相关日志："
grep -i "workspace" "$LOG_FILE" || echo "   (无)"

echo ""
echo "工具注册日志："
grep "Registering tool" "$LOG_FILE" | head -10 || echo "   (无)"

echo ""
echo "错误日志："
grep -i "error\|null" "$LOG_FILE" | head -10 || echo "   (无)"

echo ""
echo "完整日志位置："
echo "   $LOG_FILE"
echo ""
echo "查看完整日志："
echo "   cat $LOG_FILE"
echo ""
echo "查看工作空间日志："
echo "   grep -i workspace $LOG_FILE"
echo ""
echo "查看工具日志："
echo "   grep -i 'tool\\|registry' $LOG_FILE"
echo ""
echo "=================================================="

# 最终建议
if grep -q "Registering tool: Write" "$LOG_FILE"; then
    echo ""
    echo "✅ 好消息！Write 工具已成功注册！"
    echo ""
    echo "下一步："
    echo "1. 再次启动应用"
    echo "2. 打开工作空间"
    echo "3. 在 Agent 中输入创建文件指令"
    echo ""
    echo "例如："
    echo '   "在 src 下创建 hello.cc 文件，用 C++ 实现 Hello World"'
else
    echo ""
    echo "❌ 问题：Write 工具未被注册"
    echo ""
    echo "最可能的原因："
    echo "1. 未打开工作空间（必须！）"
    echo "2. 应用启动后未等待足够的时间"
    echo ""
    echo "解决方案："
    echo "1. 再次运行本脚本"
    echo "2. 应用启动后立即打开工作空间"
    echo "3. 等待至少 5 秒以完成初始化"
fi

echo ""
