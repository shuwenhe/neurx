#!/bin/bash

# 快速测试脚本：验证 Agent 文件创建功能

set -e

echo "================================================"
echo "NeurX Code - Agent 文件创建快速测试"
echo "================================================"
echo ""

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

WORKSPACE="/Users/feifei/agent/neurx-code"
APP_PATH="/Users/feifei/agent/neurx-code/build/neurx-codeApp.app/Contents/MacOS/neurx-codeApp"

echo -e "${YELLOW}📋 测试准备${NC}"
echo ""

# 检查应用是否存在
if [ ! -f "$APP_PATH" ]; then
    echo -e "${RED}❌ 应用未找到：$APP_PATH${NC}"
    echo "请先编译应用："
    echo "  cd /Users/feifei/agent/neurx-code/build"
    echo "  make -j4"
    exit 1
fi

echo -e "${GREEN}✅ 应用存在：$APP_PATH${NC}"

# 检查工作空间
if [ ! -d "$WORKSPACE" ]; then
    echo -e "${RED}❌ 工作空间不存在：$WORKSPACE${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 工作空间存在：$WORKSPACE${NC}"
echo ""

# 创建测试文件夹
TEST_OUTPUT="/tmp/neurx_test_output_$$"
mkdir -p "$TEST_OUTPUT"

echo -e "${YELLOW}🚀 启动应用测试${NC}"
echo ""
echo "请按照以下步骤操作："
echo ""
echo -e "${YELLOW}步骤 1：${NC}应用会自动启动"
echo -e "${YELLOW}步骤 2：${NC}在应用中打开工作空间"
echo "        File -> Open Workspace -> 选择 $WORKSPACE"
echo ""
echo -e "${YELLOW}步骤 3：${NC}在 Agent 对话框中输入以下任一指令："
echo ""
echo "   选项 A (相对路径):"
echo -e "   ${GREEN}在 src 目录下创建 hello.cc 文件，用 C++ 实现 Hello World${NC}"
echo ""
echo "   选项 B (绝对路径):"
echo -e "   ${GREEN}在 /Users/feifei/agent/neurx-code/src 下创建 hello.cc 文件，用 C++ 实现 Hello World${NC}"
echo ""
echo -e "${YELLOW}步骤 4：${NC}观察终端输出，寻找关键日志："
echo "        - [AgentToolRegistry] Registering tool: Write"
echo "        - [Provider] Adding X tools to request"
echo "        - [agent] tool executing: Write"
echo "        - [WriteTool] Successfully wrote XXX bytes"
echo ""
echo -e "${YELLOW}步骤 5：${NC}验证文件是否创建成功："
echo "        ls -la $WORKSPACE/src/hello.cc"
echo ""
echo "================================================"
echo -e "${YELLOW}按 Enter 启动应用，Ctrl+C 退出测试${NC}"
echo "================================================"
echo ""

read -p "准备好了吗？按 Enter 继续..."

echo ""
echo -e "${GREEN}🎬 启动应用...${NC}"
echo ""
echo "日志输出将保存到：$TEST_OUTPUT/app.log"
echo ""
echo "================================================"
echo ""

# 启动应用并捕获日志
"$APP_PATH" 2>&1 | tee "$TEST_OUTPUT/app.log" | grep -E --line-buffered "Tool|Write|agent|Error|Planner|Provider" || true

echo ""
echo "================================================"
echo -e "${YELLOW}📊 测试总结${NC}"
echo "================================================"
echo ""

# 检查日志
LOG_FILE="$TEST_OUTPUT/app.log"

if [ -f "$LOG_FILE" ]; then
    echo "日志文件：$LOG_FILE"
    echo ""
    
    # 检查工具注册
    if grep -q "Registering tool: Write" "$LOG_FILE"; then
        echo -e "${GREEN}✅ Write 工具已注册${NC}"
    else
        echo -e "${RED}❌ Write 工具未注册（工作空间可能未打开）${NC}"
    fi
    
    # 检查工具发送
    if grep -q "Adding.*tools to request" "$LOG_FILE"; then
        TOOL_COUNT=$(grep "Adding.*tools to request" "$LOG_FILE" | tail -1 | grep -oE '[0-9]+' | head -1)
        echo -e "${GREEN}✅ 已发送 $TOOL_COUNT 个工具到 LLM${NC}"
    else
        echo -e "${RED}❌ 未发送工具到 LLM${NC}"
    fi
    
    # 检查工具执行
    if grep -q "tool executing: Write" "$LOG_FILE"; then
        echo -e "${GREEN}✅ LLM 调用了 Write 工具${NC}"
    else
        echo -e "${YELLOW}⚠️  LLM 未调用 Write 工具（可能需要更明确的指令）${NC}"
    fi
    
    # 检查执行结果
    if grep -q "Successfully wrote.*bytes" "$LOG_FILE"; then
        echo -e "${GREEN}✅ 文件写入成功${NC}"
    elif grep -q "Error:" "$LOG_FILE" | grep -q "Write"; then
        echo -e "${RED}❌ 文件写入失败，查看错误：${NC}"
        grep "WriteTool.*Error" "$LOG_FILE" | tail -3
    fi
    
    echo ""
    echo "查看完整日志："
    echo "  cat $LOG_FILE"
    echo ""
    echo "查看 Write 相关日志："
    echo "  grep -i write $LOG_FILE"
    echo ""
fi

# 检查文件是否创建
echo "验证文件创建："
if [ -f "$WORKSPACE/src/hello.cc" ]; then
    echo -e "${GREEN}✅ 文件已创建：$WORKSPACE/src/hello.cc${NC}"
    echo ""
    echo "文件内容："
    cat "$WORKSPACE/src/hello.cc"
else
    echo -e "${YELLOW}⚠️  文件未找到：$WORKSPACE/src/hello.cc${NC}"
    echo "   可能需要："
    echo "   - 确保打开了工作空间"
    echo "   - 使用更明确的指令"
    echo "   - 查看日志了解失败原因"
fi

echo ""
echo "================================================"
echo "测试完成！"
echo "================================================"
