#!/bin/bash
# NeurX Code 文件创建问题诊断脚本

echo "================================================"
echo "NeurX Code - 文件创建诊断工具"
echo "================================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查函数
check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
}

check_fail() {
    echo -e "${RED}❌ $1${NC}"
}

check_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 1. 检查项目结构
echo "🔍 检查 1: 项目结构"
if [ -f "src/tools/NeurXStandardTools.cpp" ]; then
    check_pass "NeurXStandardTools.cpp 存在"
else
    check_fail "NeurXStandardTools.cpp 不存在"
    echo "   请确保你在 neurx-code 项目根目录运行此脚本"
fi

if [ -f "src/tools/NeurXStandardTools.h" ]; then
    check_pass "NeurXStandardTools.h 存在"
else
    check_fail "NeurXStandardTools.h 不存在"
fi
echo ""

# 2. 检查编译产物
echo "🔍 检查 2: 编译状态"
if [ -d "build" ]; then
    check_pass "build 目录存在"
    
    if [ -f "build/neurx-codeApp" ] || [ -f "build/neurx-codeApp.exe" ] || [ -f "build/Debug/neurx-codeApp.app/Contents/MacOS/neurx-codeApp" ]; then
        check_pass "可执行文件已生成"
    else
        check_warn "可执行文件未找到，可能需要重新编译"
        echo "   运行: cd build && make -j4"
    fi
else
    check_fail "build 目录不存在"
    echo "   请先运行: mkdir build && cd build && cmake .. && make"
fi
echo ""

# 3. 检查 NeurXStandardTools 是否被编译
echo "🔍 检查 3: 工具代码编译"
if [ -d "build" ]; then
    # 查找包含 WriteTool 符号的对象文件
    if find build -name "*.o" -o -name "*.obj" 2>/dev/null | xargs strings 2>/dev/null | grep -q "WriteTool"; then
        check_pass "WriteTool 符号存在于编译产物中"
    else
        check_warn "未找到 WriteTool 符号，可能需要重新编译"
    fi
fi
echo ""

# 4. 检查系统提示词
echo "🔍 检查 4: 系统提示词配置"
if grep -q "Write: Create a new file" src/bridge/AgentController.cpp; then
    check_pass "系统提示词包含 Write 工具说明"
else
    check_warn "系统提示词可能缺少 Write 工具说明"
fi
echo ""

# 5. 检查工具注册
echo "🔍 检查 5: 工具注册代码"
if grep -q "NeurXStandardToolFactory::registerAllTools" src/bridge/AgentController.cpp; then
    check_pass "找到 NeurXStandardToolFactory::registerAllTools 调用"
else
    check_fail "未找到工具注册代码"
    echo "   请检查 AgentController::setWorkspacePath 中是否调用了 registerAllTools"
fi
echo ""

# 6. 检查 Sandbox 配置
echo "🔍 检查 6: Sandbox 配置"
if grep -q "addAllowedWritePath" src/bridge/AgentController.cpp; then
    check_pass "找到 Sandbox 写权限配置"
else
    check_fail "未找到 Sandbox 写权限配置"
    echo "   请检查 setWorkspacePath 中的 addAllowedWritePath 调用"
fi
echo ""

# 7. 生成测试代码
echo "🔍 检查 7: 生成测试工具"
cat > /tmp/test_write_tool.sh << 'TESTEOF'
#!/bin/bash
# 快速测试 Write 工具

TEST_DIR="/tmp/neurx_write_test_$$"
mkdir -p "$TEST_DIR"

echo "测试工作空间: $TEST_DIR"
echo "创建测试文件..."

# 模拟工具调用
cat > "$TEST_DIR/test.txt" << 'EOF'
Hello from NeurX Code!
This is a test file.
EOF

if [ -f "$TEST_DIR/test.txt" ]; then
    echo "✅ 文件系统写入测试通过"
    echo "文件内容:"
    cat "$TEST_DIR/test.txt"
    rm -rf "$TEST_DIR"
    exit 0
else
    echo "❌ 文件系统写入测试失败"
    exit 1
fi
TESTEOF

chmod +x /tmp/test_write_tool.sh
if /tmp/test_write_tool.sh; then
    check_pass "基本文件系统写入功能正常"
else
    check_fail "基本文件系统写入失败"
fi
echo ""

# 8. 运行建议
echo "================================================"
echo "📋 诊断建议"
echo "================================================"
echo ""

# 统计失败项
FAILED=$(grep -c "❌" /tmp/neurx_diag_$$.log 2>/dev/null || echo 0)

if [ -f /tmp/neurx_diag_$$.log ]; then
    rm /tmp/neurx_diag_$$.log
fi

echo "如果所有检查都通过，但仍然无法创建文件，请尝试："
echo ""
echo "1️⃣  确保已打开工作空间"
echo "   - 在应用中: File -> Open Workspace"
echo "   - 选择一个项目目录"
echo ""
echo "2️⃣  使用明确的文件路径"
echo "   ❌ 错误: \"创建一个文件\""
echo "   ✅ 正确: \"在 src/test.cpp 中创建一个 Hello World 程序\""
echo ""
echo "3️⃣  查看运行日志"
echo "   cd build"
echo "   ./neurx-codeApp 2>&1 | grep -i \"WriteTool\\|error\""
echo ""
echo "4️⃣  手动测试工具"
echo "   参考: docs/TROUBLESHOOTING_FILE_CREATION.md"
echo ""
echo "5️⃣  重新编译项目"
echo "   cd /Users/feifei/agent/neurx-code"
echo "   rm -rf build"
echo "   mkdir build && cd build"
echo "   cmake .."
echo "   make -j4"
echo ""

echo "================================================"
echo "📚 更多帮助"
echo "================================================"
echo "完整诊断文档: docs/TROUBLESHOOTING_FILE_CREATION.md"
echo "Bug 报告: 提供应用日志和上述诊断结果"
echo ""

exit 0
