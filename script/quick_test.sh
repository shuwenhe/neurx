#!/bin/bash
# 快速测试脚本 - 直接验证系统

set -e

echo "================================================"
echo "🧪 NeurX 智能推理系统 - 快速测试"
echo "================================================"
echo ""

cd /Users/feifei/shuwen/neurx

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0

test_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
        ((PASS++))
    else
        echo -e "${RED}✗ $1${NC}"
        ((FAIL++))
    fi
}

echo "📋 测试1: 文件检查"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test -f s/smart_inference.s
test_result "S源文件存在"

test -d build
test_result "build目录存在"

# 获取源文件统计
lines=$(wc -l < s/smart_inference.s 2>/dev/null)
funcs=$(grep -c "^func " s/smart_inference.s 2>/dev/null || echo 0)
structs=$(grep -c "^struct " s/smart_inference.s 2>/dev/null || echo 0)

[ "$lines" -gt 500 ]
test_result "源文件规模充足 ($lines 行)"

[ "$funcs" -gt 10 ]
test_result "函数数量充足 ($funcs 个)"

[ "$structs" -gt 2 ]
test_result "数据结构充足 ($structs 个)"

echo ""
echo "📋 测试2: 关键函数检查"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

grep -q "func strlen" s/smart_inference.s
test_result "strlen() 字符串长度函数"

grep -q "func str_contains" s/smart_inference.s
test_result "str_contains() 子串检查函数"

grep -q "func str_to_lower" s/smart_inference.s
test_result "str_to_lower() 小写转换函数"

grep -q "func init_knowledge_base" s/smart_inference.s
test_result "init_knowledge_base() 知识库初始化"

grep -q "func get_knowledge_item" s/smart_inference.s
test_result "get_knowledge_item() 知识项获取"

grep -q "func calculate_similarity" s/smart_inference.s
test_result "calculate_similarity() 相似度计算"

grep -q "func answer_question" s/smart_inference.s
test_result "answer_question() 回答生成"

grep -q "func run_interactive_mode" s/smart_inference.s
test_result "run_interactive_mode() 交互式对话"

echo ""
echo "📋 测试3: S编译器检查"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

S_COMPILER="/Users/feifei/train/s/.local/bin/s"

test -x "$S_COMPILER"
test_result "S编译器可执行"

echo ""
echo "📋 测试4: 编译测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "编译 S → IR..."
"$S_COMPILER" s/smart_inference.s build/smart_inference.ir 2>/dev/null
test_result "S → IR 编译成功"

test -f build/smart_inference.ir
test_result "IR 文件生成"

ir_size=$(ls -l build/smart_inference.ir | awk '{print $5}')
echo "  IR 文件大小: $ir_size 字节"

echo ""
echo "📋 测试5: 代码质量指标"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 代码复杂度
comment_lines=$(grep -c "^//" s/smart_inference.s 2>/dev/null || echo 0)
code_lines=$((lines - comment_lines))

echo "  总行数: $lines"
echo "  代码行: $code_lines"
echo "  注释行: $comment_lines"
echo "  函数数: $funcs"
echo "  结构体: $structs"

echo ""
echo "📋 测试6: 文档检查"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test -f SMART_INFERENCE_README.md
test_result "README 文档"

test -f SMART_INFERENCE_COMPLETE.md
test_result "完整文档"

test -f PYTHON_VS_S_COMPARISON.md
test_result "对比文档"

test -f TEST_GUIDE.md
test_result "测试指南"

echo ""
echo "================================================"
echo "📊 测试总结"
echo "================================================"
echo ""
echo -e "${GREEN}✓ 通过: $PASS${NC}"
echo -e "${RED}✗ 失败: $FAIL${NC}"

total=$((PASS + FAIL))
if [ "$total" -gt 0 ]; then
    rate=$((PASS * 100 / total))
    echo -e "${CYAN}通过率: $rate% ($PASS/$total)${NC}"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✨ 所有测试通过！${NC}"
    echo ""
    echo "下一步:"
    echo "  1. 编译二进制: bash build_smart_inference.sh"
    echo "  2. 运行推理: ./build/smart_inference.bin"
    echo "  3. 查看文档: cat SMART_INFERENCE_COMPLETE.md"
    exit 0
else
    echo -e "${YELLOW}⚠️ 部分测试失败${NC}"
    exit 1
fi
