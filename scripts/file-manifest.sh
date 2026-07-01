#!/bin/bash
# 📋 NeurX 智能推理系统 - 文件清单和快速链接
# File Manifest and Quick Links

set -e

PROJECT_DIR="/Users/feifei/shuwen/neurx"
cd "$PROJECT_DIR"

# 颜色定义
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}"
echo "════════════════════════════════════════════════════════════════"
echo "  📋 NeurX 智能推理系统 - 文件清单和快速链接"
echo "════════════════════════════════════════════════════════════════"
echo -e "${NC}"
echo ""

# ============================================================================
# 第一部分: 测试文档概览
# ============================================================================

echo -e "${YELLOW}${BOLD}【测试文档】${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 统计测试文档
test_docs=(
    "START_TESTING.md:快速启动指南 ⭐"
    "TEST_SUMMARY.md:完整总结和快速开始 ⭐"
    "TEST_INDEX.md:文档导航地图"
    "TESTING_CHECKLIST.md:分步骤检查清单 ⭐"
    "TEST_GUIDE.md:详细测试教程"
    "TESTING_COMPLETE.md:测试基础设施完成总结"
)

for doc_info in "${test_docs[@]}"; do
    IFS=':' read -r filename description <<< "$doc_info"
    if [ -f "$filename" ]; then
        size=$(ls -lh "$filename" | awk '{print $5}')
        lines=$(wc -l < "$filename" 2>/dev/null || echo "0")
        printf "%-30s %6s  %6s行  %s\n" \
            "✓ $filename" "$size" "$lines" "$description"
    fi
done

echo ""

# ============================================================================
# 第二部分: 项目文档概览
# ============================================================================

echo -e "${YELLOW}${BOLD}【项目文档】${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

project_docs=(
    "SMART_INFERENCE_COMPLETE.md:项目完成总结"
    "SMART_INFERENCE_README.md:S版本使用指南"
    "PYTHON_VS_S_COMPARISON.md:Python vs S 性能对比"
)

for doc_info in "${project_docs[@]}"; do
    IFS=':' read -r filename description <<< "$doc_info"
    if [ -f "$filename" ]; then
        size=$(ls -lh "$filename" | awk '{print $5}')
        lines=$(wc -l < "$filename" 2>/dev/null || echo "0")
        printf "%-35s %6s  %6s行  %s\n" \
            "✓ $filename" "$size" "$lines" "$description"
    fi
done

echo ""

# ============================================================================
# 第三部分: 脚本文件概览
# ============================================================================

echo -e "${YELLOW}${BOLD}【脚本文件】${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

scripts=(
    "test_smart_inference.sh:自动化测试套件"
    "quick_test.sh:快速验证脚本"
    "build_smart_inference.sh:编译编排脚本"
    "launch_smart_inference.sh:交互启动器"
    "demo_smart_inference.sh:演示脚本"
)

for script_info in "${scripts[@]}"; do
    IFS=':' read -r filename description <<< "$script_info"
    if [ -f "$filename" ]; then
        size=$(ls -lh "$filename" | awk '{print $5}')
        lines=$(wc -l < "$filename" 2>/dev/null || echo "0")
        printf "%-35s %6s  %6s行  %s\n" \
            "✓ $filename" "$size" "$lines" "$description"
    fi
done

echo ""

# ============================================================================
# 第四部分: 源代码和编译产物
# ============================================================================

echo -e "${YELLOW}${BOLD}【源代码和编译产物】${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 源代码
if [ -f "s/smart_inference.s" ]; then
    size=$(ls -lh "s/smart_inference.s" | awk '{print $5}')
    lines=$(wc -l < "s/smart_inference.s")
    funcs=$(grep -c "^func " "s/smart_inference.s" || echo "0")
    structs=$(grep -c "^struct " "s/smart_inference.s" || echo "0")
    echo "✓ s/smart_inference.s ($size, $lines 行, $funcs 函数, $structs 结构体)"
else
    echo "✗ s/smart_inference.s (缺失)"
fi

# 编译产物
if [ -f "build/smart_inference.ir" ]; then
    size=$(ls -lh "build/smart_inference.ir" | awk '{print $5}')
    echo "✓ build/smart_inference.ir ($size)"
else
    echo "⏳ build/smart_inference.ir (待编译)"
fi

if [ -f "build/smart_inference.bin" ]; then
    size=$(ls -lh "build/smart_inference.bin" | awk '{print $5}')
    if [ -x "build/smart_inference.bin" ]; then
        echo "✓ build/smart_inference.bin ($size, 可执行)"
    else
        echo "⚠ build/smart_inference.bin ($size, 需要权限)"
    fi
else
    echo "⏳ build/smart_inference.bin (待编译)"
fi

echo ""

# ============================================================================
# 第五部分: 推荐的文档阅读顺序
# ============================================================================

echo -e "${MAGENTA}${BOLD}【推荐阅读顺序】${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -e "${CYAN}快速入门 (5分钟):${NC}"
echo "  1. cat START_TESTING.md | head -50"
echo "  2. bash quick_test.sh"
echo ""

echo -e "${CYAN}标准学习 (20分钟):${NC}"
echo "  1. cat TEST_SUMMARY.md | head -100"
echo "  2. 按照编译命令进行编译"
echo "  3. 查看编译结果"
echo ""

echo -e "${CYAN}深入学习 (1小时):${NC}"
echo "  1. cat START_TESTING.md"
echo "  2. cat TEST_INDEX.md"
echo "  3. cat TEST_SUMMARY.md"
echo "  4. cat TESTING_CHECKLIST.md"
echo "  5. 运行完整测试"
echo ""

# ============================================================================
# 第六部分: 快速命令
# ============================================================================

echo -e "${MAGENTA}${BOLD}【快速命令参考】${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -e "${CYAN}验证系统 (2分钟):${NC}"
echo "  wc -l s/smart_inference.s"
echo "  grep '^func ' s/smart_inference.s | wc -l"
echo ""

echo -e "${CYAN}编译系统 (2分钟):${NC}"
echo "  # 编译 S → IR"
echo "  /Users/feifei/train/s/.local/bin/s s/smart_inference.s build/smart_inference.ir"
echo ""
echo "  # 编译 IR → BIN"
echo "  cd /Users/feifei/train/s"
echo "  /Users/feifei/train/s/.local/bin/s --emit-bin \\"
echo "      /Users/feifei/shuwen/neurx/build/smart_inference.ir \\"
echo "      /Users/feifei/shuwen/neurx/build/smart_inference.bin"
echo ""

echo -e "${CYAN}查看文档 (任时):${NC}"
echo "  cat START_TESTING.md        # 快速启动"
echo "  cat TEST_SUMMARY.md         # 完整总结"
echo "  cat TEST_INDEX.md           # 文档导航"
echo "  cat TESTING_CHECKLIST.md    # 检查清单"
echo ""

# ============================================================================
# 第七部分: 统计信息
# ============================================================================

echo -e "${MAGENTA}${BOLD}【统计信息】${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 统计文档总大小
total_size=0
total_lines=0

for f in TEST_*.md START_*.md TESTING_COMPLETE.md SMART_INFERENCE*.md; do
    if [ -f "$f" ]; then
        size=$(ls -l "$f" | awk '{print $5}')
        lines=$(wc -l < "$f" 2>/dev/null || echo "0")
        total_size=$((total_size + size))
        total_lines=$((total_lines + lines))
    fi
done

echo "测试文档:"
echo "  文档数量: 10+ 个"
echo "  总大小: $((total_size / 1024))KB"
echo "  总行数: ${total_lines}+ 行"
echo ""

echo "脚本文件:"
echo "  脚本数量: 5+ 个"
echo "  功能: 编译、测试、演示、启动"
echo ""

echo "源代码:"
echo "  S语言源代码: $(wc -l < s/smart_inference.s) 行"
echo "  函数数量: $(grep -c '^func ' s/smart_inference.s || echo "0") 个"
echo "  结构体数量: $(grep -c '^struct ' s/smart_inference.s || echo "0") 个"
echo ""

# ============================================================================
# 第八部分: 系统状态
# ============================================================================

echo -e "${MAGENTA}${BOLD}【系统状态】${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -e "${GREEN}✅ 已完成:${NC}"
echo "  [✓] 源代码完整"
echo "  [✓] 文档齐全"
echo "  [✓] 脚本工具"
echo "  [✓] 编译环境"
echo ""

echo -e "${YELLOW}⏳ 待验证 (需手动编译):${NC}"
echo "  [ ] S → IR 编译"
echo "  [ ] IR → BIN 编译"
echo "  [ ] 二进制可执行"
echo ""

echo -e "${BLUE}📋 建议:${NC}"
echo "  1. 阅读 START_TESTING.md 了解整体流程"
echo "  2. 按照 TEST_SUMMARY.md 进行编译"
echo "  3. 使用 TESTING_CHECKLIST.md 验证系统"
echo "  4. 查看 PYTHON_VS_S_COMPARISON.md 了解性能"
echo ""

# ============================================================================
# 结尾
# ============================================================================

echo -e "${BLUE}${BOLD}"
echo "════════════════════════════════════════════════════════════════"
echo "  🚀 准备好了吗？立即开始测试吧！"
echo "════════════════════════════════════════════════════════════════"
echo -e "${NC}"
echo ""
echo "💡 首先阅读: cat /Users/feifei/shuwen/neurx/START_TESTING.md"
echo ""
