#!/bin/bash
# NeurX S语言智能推理系统 - 编译和运行脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色定义
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}${BOLD}🚀 NeurX S语言智能推理系统${NC}"
echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
echo ""

# 设置编译器
S_COMPILER="${S_COMPILER:-/Users/feifei/shuwen/train/s/.local/bin/s}"
S_COMPILER_DIR="${S_COMPILER_DIR:-$SCRIPT_DIR/../../s}"

echo -e "${CYAN}【步骤 1】检查S编译器${NC}"
if [ -x "$S_COMPILER" ]; then
    echo -e "${GREEN}✓ S编译器就绪${NC}"
else
    echo -e "${YELLOW}✗ S编译器未找到${NC}"
    exit 1
fi
echo ""

echo -e "${CYAN}【步骤 2】编译 S → IR${NC}"
SOURCE="s/smart_inference.s"
IR_OUTPUT="build/smart_inference.ir"

if [ -f "$SOURCE" ]; then
    echo -e "  编译: $SOURCE"
    if "$S_COMPILER" "$SOURCE" "$IR_OUTPUT" 2>&1; then
        IR_SIZE=$(ls -lh "$IR_OUTPUT" 2>/dev/null | awk '{print $5}')
        echo -e "${GREEN}✓ IR编译成功${NC} (大小: $IR_SIZE)"
    else
        echo -e "${YELLOW}✗ IR编译失败${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}✗ 源文件不存在: $SOURCE${NC}"
    exit 1
fi
echo ""

echo -e "${CYAN}【步骤 3】编译 IR → 二进制${NC}"
BIN_OUTPUT="build/smart_inference.bin"

if [ -f "$IR_OUTPUT" ]; then
    echo -e "  编译: $IR_OUTPUT → $BIN_OUTPUT"
    if (cd "$S_COMPILER_DIR" && "$S_COMPILER" --emit-bin "$SCRIPT_DIR/$IR_OUTPUT" "$SCRIPT_DIR/$BIN_OUTPUT" 2>&1); then
        chmod +x "$BIN_OUTPUT"
        BIN_SIZE=$(ls -lh "$BIN_OUTPUT" 2>/dev/null | awk '{print $5}')
        echo -e "${GREEN}✓ 二进制编译成功${NC} (大小: $BIN_SIZE)"
    else
        echo -e "${YELLOW}⚠ 二进制编译可能有问题${NC}"
    fi
else
    echo -e "${YELLOW}✗ IR文件不存在${NC}"
    exit 1
fi
echo ""

echo -e "${CYAN}【步骤 4】显示编译产物${NC}"
echo -e "${GREEN}✓ 源文件:${NC} $(ls -lh s/smart_inference.s | awk '{print $5, $9}')"
echo -e "${GREEN}✓ IR文件:${NC} $(ls -lh build/smart_inference.ir 2>/dev/null | awk '{print $5, $9}' || echo 'N/A')"
echo -e "${GREEN}✓ 二进制:${NC} $(ls -lh build/smart_inference.bin 2>/dev/null | awk '{print $5, $9}' || echo 'N/A')"
echo ""

echo -e "${MAGENTA}【步骤 5】系统信息${NC}"
cat << INFO
📊 智能推理系统特性:
  ✓ 知识库检索 (6个核心知识点)
  ✓ 关键词提取和匹配
  ✓ 相似度计算
  ✓ 智能回答生成
  ✓ 交互式对话
  ✓ 多语言支持 (中文/英文)

🎯 支持的问题:
  • 人工智能和深度学习
  • Transformer 架构
  • 优化器和训练技巧
  • NeurX 框架功能
  • 推理和部署

📈 核心功能:
  • 相似度匹配 (Jaccard + 子串)
  • 关键词自动提取
  • 智能响应生成
  • 交互式 REPL

INFO

echo ""
echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}✨ S语言智能推理系统已编译完成！${NC}"
echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}【快速开始】${NC}"
echo "  # 查看编译结果"
echo "  ls -lh build/smart_inference.*"
echo ""
echo "  # 运行演示文档"
echo "  cat SMART_INFERENCE_README.md"
echo ""
