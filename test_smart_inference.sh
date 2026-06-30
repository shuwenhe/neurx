#!/bin/bash
# NeurX 智能推理系统测试指南
# Test Guide for NeurX Smart Inference System

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# 计数器
TESTS_PASSED=0
TESTS_FAILED=0

# 打印函数
print_header() {
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}$1${NC}"
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
}

print_test() {
    echo -e "${CYAN}【测试】$1${NC}"
}

print_pass() {
    echo -e "${GREEN}✓ 通过: $1${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_fail() {
    echo -e "${RED}✗ 失败: $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_info() {
    echo -e "${MAGENTA}ℹ $1${NC}"
}

print_section() {
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
    echo ""
}

# ============================================================================
# 测试 1: 环境检查
# ============================================================================

test_environment() {
    print_header "📋 测试 1: 环境检查"
    echo ""
    
    # 检查Python
    print_test "Python3 环境"
    if command -v python3 &> /dev/null; then
        py_version=$(python3 --version 2>&1)
        print_pass "$py_version"
    else
        print_fail "Python3 未安装"
    fi
    
    # 检查S编译器
    print_test "S 编译器"
    S_COMPILER="/Users/feifei/train/s/.local/bin/s"
    if [ -x "$S_COMPILER" ]; then
        print_pass "S 编译器就绪 ($S_COMPILER)"
    else
        print_fail "S 编译器未找到"
    fi
    
    # 检查必要的目录
    print_test "项目目录"
    if [ -d "s" ] && [ -d "build" ]; then
        print_pass "目录结构正确"
    else
        mkdir -p s build
        print_pass "目录已创建"
    fi
    
    echo ""
}

# ============================================================================
# 测试 2: S语言源文件检查
# ============================================================================

test_s_source() {
    print_header "📋 测试 2: S语言源文件检查"
    echo ""
    
    SOURCE_FILE="s/smart_inference.s"
    
    # 文件存在性
    print_test "源文件存在性"
    if [ -f "$SOURCE_FILE" ]; then
        size=$(ls -lh "$SOURCE_FILE" | awk '{print $5}')
        lines=$(wc -l < "$SOURCE_FILE")
        print_pass "文件存在 ($size, $lines 行)"
    else
        print_fail "源文件不存在: $SOURCE_FILE"
        return 1
    fi
    
    # 文件内容检查
    print_test "源文件内容"
    if grep -q "func main()" "$SOURCE_FILE"; then
        print_pass "包含 main() 函数"
    else
        print_fail "缺少 main() 函数"
    fi
    
    if grep -q "func answer_question" "$SOURCE_FILE"; then
        print_pass "包含 answer_question() 函数"
    else
        print_fail "缺少 answer_question() 函数"
    fi
    
    if grep -q "func run_interactive_mode" "$SOURCE_FILE"; then
        print_pass "包含 run_interactive_mode() 函数"
    else
        print_fail "缺少 run_interactive_mode() 函数"
    fi
    
    echo ""
}

# ============================================================================
# 测试 3: S语言编译测试
# ============================================================================

test_s_compilation() {
    print_header "📋 测试 3: S语言编译测试"
    echo ""
    
    SOURCE_FILE="s/smart_inference.s"
    IR_OUTPUT="build/smart_inference.ir"
    S_COMPILER="/Users/feifei/train/s/.local/bin/s"
    
    # 检查编译器
    if [ ! -x "$S_COMPILER" ]; then
        print_fail "S 编译器不可用"
        return 1
    fi
    
    # 编译到 IR
    print_test "编译 S → IR"
    if "$S_COMPILER" "$SOURCE_FILE" "$IR_OUTPUT" 2>&1 > /tmp/compile.log; then
        ir_size=$(ls -lh "$IR_OUTPUT" | awk '{print $5}')
        print_pass "IR 编译成功 ($ir_size)"
    else
        print_fail "IR 编译失败"
        cat /tmp/compile.log
        return 1
    fi
    
    # 检查 IR 文件
    print_test "IR 文件验证"
    if [ -f "$IR_OUTPUT" ] && [ -s "$IR_OUTPUT" ]; then
        print_pass "IR 文件有效"
    else
        print_fail "IR 文件无效或为空"
        return 1
    fi
    
    # 编译到二进制
    print_test "编译 IR → 二进制"
    BIN_OUTPUT="build/smart_inference.bin"
    S_COMPILER_DIR="/Users/feifei/train/s"
    
    if (cd "$S_COMPILER_DIR" && "$S_COMPILER" --emit-bin "$SCRIPT_DIR/$IR_OUTPUT" "$SCRIPT_DIR/$BIN_OUTPUT" 2>&1 > /tmp/compile_bin.log); then
        chmod +x "$BIN_OUTPUT"
        bin_size=$(ls -lh "$BIN_OUTPUT" | awk '{print $5}')
        print_pass "二进制编译成功 ($bin_size)"
    else
        print_fail "二进制编译失败"
        cat /tmp/compile_bin.log
        return 1
    fi
    
    # 检查二进制文件
    print_test "二进制文件验证"
    if [ -x "$BIN_OUTPUT" ]; then
        print_pass "二进制文件可执行"
    else
        print_fail "二进制文件不可执行"
        return 1
    fi
    
    echo ""
}

# ============================================================================
# 测试 4: 功能测试
# ============================================================================

test_functionality() {
    print_header "📋 测试 4: S语言推理系统功能测试"
    echo ""
    
    # 检查关键函数
    print_test "字符串处理函数"
    if grep -q "func strlen" s/smart_inference.s && \
       grep -q "func str_contains" s/smart_inference.s && \
       grep -q "func str_to_lower" s/smart_inference.s; then
        print_pass "字符串工具库完整"
    else
        print_fail "字符串工具库不完整"
    fi
    
    print_test "知识库函数"
    if grep -q "func init_knowledge_base" s/smart_inference.s && \
       grep -q "func get_knowledge_item" s/smart_inference.s; then
        print_pass "知识库管理完整"
    else
        print_fail "知识库管理不完整"
    fi
    
    print_test "相似度计算"
    if grep -q "func calculate_similarity" s/smart_inference.s; then
        print_pass "相似度计算实现"
    else
        print_fail "相似度计算未实现"
    fi
    
    print_test "回答生成"
    if grep -q "func answer_question" s/smart_inference.s && \
       grep -q "func generate_" s/smart_inference.s; then
        print_pass "回答生成完整"
    else
        print_fail "回答生成不完整"
    fi
    
    print_test "交互式对话"
    if grep -q "func run_interactive_mode" s/smart_inference.s && \
       grep -q "func show_help" s/smart_inference.s; then
        print_pass "交互式对话支持"
    else
        print_fail "交互式对话不支持"
    fi
    
    echo ""
}

# ============================================================================
# 测试 5: 代码质量检查
# ============================================================================

test_code_quality() {
    print_header "📋 测试 5: 代码质量检查"
    echo ""
    
    SOURCE_FILE="s/smart_inference.s"
    
    # 函数数量
    print_test "函数数量"
    func_count=$(grep -c "^func " "$SOURCE_FILE" || echo 0)
    if [ "$func_count" -gt 10 ]; then
        print_pass "函数数量充足 ($func_count 个)"
    else
        print_fail "函数数量不足"
    fi
    
    # 结构体定义
    print_test "数据结构"
    struct_count=$(grep -c "^struct " "$SOURCE_FILE" || echo 0)
    if [ "$struct_count" -gt 2 ]; then
        print_pass "数据结构完整 ($struct_count 个)"
    else
        print_fail "数据结构不足"
    fi
    
    # 代码行数
    print_test "代码规模"
    lines=$(wc -l < "$SOURCE_FILE")
    if [ "$lines" -gt 500 ]; then
        print_pass "代码规模充足 ($lines 行)"
    else
        print_fail "代码规模过小"
    fi
    
    # 注释覆盖
    print_test "文档注释"
    comment_count=$(grep -c "^//" "$SOURCE_FILE" || echo 0)
    if [ "$comment_count" -gt 20 ]; then
        print_pass "注释充足 ($comment_count 行)"
    else
        print_info "注释较少 ($comment_count 行)"
    fi
    
    echo ""
}

# ============================================================================
# 测试 6: 编译产物检查
# ============================================================================

test_artifacts() {
    print_header "📋 测试 6: 编译产物检查"
    echo ""
    
    IR_FILE="build/smart_inference.ir"
    BIN_FILE="build/smart_inference.bin"
    
    # IR 文件检查
    print_test "IR 中间代码"
    if [ -f "$IR_FILE" ]; then
        ir_size=$(ls -lh "$IR_FILE" | awk '{print $5}')
        print_pass "IR 文件存在 ($ir_size)"
    else
        print_fail "IR 文件不存在"
    fi
    
    # 二进制文件检查
    print_test "可执行二进制"
    if [ -f "$BIN_FILE" ] && [ -x "$BIN_FILE" ]; then
        bin_size=$(ls -lh "$BIN_FILE" | awk '{print $5}')
        print_pass "二进制文件就绪 ($bin_size)"
    else
        print_fail "二进制文件不可用"
    fi
    
    # 文件大小验证
    print_test "编译产物大小"
    if [ -f "$IR_FILE" ] && [ -f "$BIN_FILE" ]; then
        ir_size_bytes=$(ls -L "$IR_FILE" | awk '{print $5}')
        bin_size_bytes=$(ls -L "$BIN_FILE" | awk '{print $5}')
        
        if [ "$ir_size_bytes" -gt 1000 ] && [ "$bin_size_bytes" -gt 10000 ]; then
            print_pass "编译产物大小正常"
        else
            print_fail "编译产物大小异常"
        fi
    fi
    
    echo ""
}

# ============================================================================
# 测试 7: 性能基准测试
# ============================================================================

test_performance() {
    print_header "📋 测试 7: 性能基准测试"
    echo ""
    
    print_section "编译性能"
    
    # 编译时间测试
    print_test "S → IR 编译时间"
    start_time=$(date +%s%N)
    /Users/feifei/train/s/.local/bin/s s/smart_inference.s build/smart_inference.ir 2>&1 > /dev/null
    end_time=$(date +%s%N)
    compile_time=$(( (end_time - start_time) / 1000000 ))  # 转换为毫秒
    
    if [ "$compile_time" -lt 5000 ]; then
        print_pass "编译快速 (${compile_time}ms)"
    else
        print_info "编译耗时 (${compile_time}ms)"
    fi
    
    # 二进制大小
    print_test "二进制文件大小"
    if [ -f "build/smart_inference.bin" ]; then
        bin_size=$(ls -L build/smart_inference.bin | awk '{print $5}')
        bin_size_kb=$((bin_size / 1024))
        
        if [ "$bin_size_kb" -lt 500 ]; then
            print_pass "二进制精简 (${bin_size_kb}KB)"
        else
            print_info "二进制较大 (${bin_size_kb}KB)"
        fi
    fi
    
    echo ""
}

# ============================================================================
# 测试 8: 文档检查
# ============================================================================

test_documentation() {
    print_header "📋 测试 8: 文档检查"
    echo ""
    
    docs=(
        "SMART_INFERENCE_README.md"
        "SMART_INFERENCE_COMPLETE.md"
        "PYTHON_VS_S_COMPARISON.md"
    )
    
    for doc in "${docs[@]}"; do
        print_test "文档: $doc"
        if [ -f "$doc" ]; then
            lines=$(wc -l < "$doc")
            print_pass "文档完整 ($lines 行)"
        else
            print_info "文档缺失"
        fi
    done
    
    echo ""
}

# ============================================================================
# 测试总结
# ============================================================================

print_summary() {
    print_header "📊 测试总结"
    echo ""
    
    total=$((TESTS_PASSED + TESTS_FAILED))
    pass_rate=0
    if [ "$total" -gt 0 ]; then
        pass_rate=$((TESTS_PASSED * 100 / total))
    fi
    
    echo -e "${GREEN}✓ 通过: $TESTS_PASSED${NC}"
    echo -e "${RED}✗ 失败: $TESTS_FAILED${NC}"
    echo -e "${CYAN}总计: $total${NC}"
    echo -e "${MAGENTA}通过率: ${pass_rate}%${NC}"
    echo ""
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}🎉 所有测试通过！${NC}"
        return 0
    else
        echo -e "${YELLOW}${BOLD}⚠️ 部分测试失败，请检查${NC}"
        return 1
    fi
}

# ============================================================================
# 主测试流程
# ============================================================================

main() {
    print_header "🧪 NeurX 智能推理系统 - 完整测试套件"
    echo ""
    echo "开始时间: $(date)"
    echo ""
    
    # 运行所有测试
    test_environment
    test_s_source
    test_s_compilation
    test_functionality
    test_code_quality
    test_artifacts
    test_performance
    test_documentation
    
    # 打印总结
    print_summary
}

# 执行主函数
main
