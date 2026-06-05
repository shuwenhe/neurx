#!/bin/bash

echo "🧪 NeurX Code 工具注册诊断"
echo "================================"
echo ""

# 运行应用并捕获前几秒的日志
echo "启动应用并检查工具注册日志..."
echo ""

timeout 5 /Users/feifei/agent/neurx-code/build/neurx-codeApp.app/Contents/MacOS/neurx-codeApp 2>&1 | grep -E "\[AgentController|Registry|Tools|Planner" | head -50

echo ""
echo "================================"
echo "说明:"
echo "  • [AgentController::init] 应该显示："
echo "    - 'Registering Claude Standard Tools'"
echo "    - 'Claude Standard Tools registered successfully'"
echo ""
echo "  • [AgentToolRegistry] 应该显示: 'Registering tool: write', 'edit' 等"
echo ""
echo "  • [Planner] 应该显示非零的工具数量"
echo "    - 不应该显示 'Registry has 0 tools'"
echo ""
