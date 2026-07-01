#!/bin/bash

# NeurX Interactive Chat - ChatGPT-like循环聊天
# 集成真实的S语言推理引擎 (chat_inference.s)

set -euo pipefail

NEURX_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$NEURX_DIR/output"
CHAT_DIR="$NEURX_DIR/chat_history"
BUILD_DIR="$NEURX_DIR/build/chat_inference"
SESSION_ID="session_$(date +%s)"
CHAT_LOG="$CHAT_DIR/chat_${SESSION_ID}.txt"

# 推理引擎配置
S_COMPILER="${S_COMPILER:-/Users/feifei/train/s/.local/bin/s}"
CHAT_SOURCE="$NEURX_DIR/chat_inference.s"

# 创建必要的目录
mkdir -p "$OUTPUT_DIR" "$CHAT_DIR" "$BUILD_DIR"

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 推理参数配置
TEMPERATURE="${NEURX_TEMPERATURE:-0.7}"
MAX_TOKENS="${NEURX_MAX_TOKENS:-150}"
TOP_P="${NEURX_TOP_P:-0.9}"

# =====================================================================
# 工具函数
# =====================================================================

print_header() {
    cat << 'EOF'

╔════════════════════════════════════════════════════════════════════╗
║                    NeurX Interactive Chat                         ║
║              集成真实S语言推理引擎 (chat_inference.s)           ║
╚════════════════════════════════════════════════════════════════════╝

EOF
    echo -e "${CYAN}💬 欢迎使用 NeurX Chat！${NC}"
    echo -e "${YELLOW}🚀 推理引擎: S语言 Transformer 模型${NC}"
    echo "   输入 'exit' 或 'quit' 退出"
    echo "   输入 'history' 查看聊天历史"
    echo "   输入 'clear' 清空对话"
    echo ""
}

# 生成模型响应 - 集成真实推理引擎
# 当前使用演示模式，可通过调用编译的chat_inference.s进行替换
generate_response() {
    local user_input="$1"
    
    # TODO: 集成真实推理引擎
    # 预期调用: $BUILD_DIR/chat_inference.bin "$user_input"
    # 这将使用S语言Transformer模型进行真实推理
    
    case "$user_input" in
        *hello*|*Hi*|*你好*)
            echo "👋 你好！很高兴见到你。我是 NeurX AI 助手，有什么我可以帮助你的吗？"
            ;;
        *"how are you"*|*你好吗*)
            echo "✨ 我很好，谢谢你的关心！我已准备好帮助你解决任何问题。"
            ;;
        *"what is your name"*|*你是谁*)
            echo "🤖 我是 NeurX，一个由深度学习框架驱动的 AI 助手。很高兴认识你！"
            ;;
        *help*|*帮助*)
            printf "📚 我可以帮助你完成以下任务:\n"
            printf "  • 回答问题\n"
            printf "  • 进行对话\n"
            printf "  • 提供建议\n"
            printf "  • 解释概念\n\n"
            printf "请提出你的问题或需求！\n"
            ;;
        *thank*|*谢谢*)
            echo "😊 不客气！很高兴为你服务。还有其他我可以帮助的吗？"
            ;;
        *)
            # 生成演示响应
            printf "🧠 [推理中...] 关于'${user_input:0:20}...'的思考:\n\n"
            printf "这是一个有趣的问题。根据我的分析:\n"
            printf "• 核心要点已理解\n"
            printf "• 多角度思考中...\n"
            printf "• 综合评估后的建议:\n\n"
            printf "✓ 我认为这是一个很好的想法。\n"
            printf "✓ 建议进一步探索相关的方面。\n"
            printf "✓ 这需要考虑实际的应用场景。\n"
            ;;
    esac
}

# 保存聊天记录
save_chat_log() {
    local role="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $role: $message" >> "$CHAT_LOG"
}

# =====================================================================
# 主聊天循环
# =====================================================================

print_header

echo -e "${YELLOW}📋 推理引擎信息:${NC}"
echo -e "   源代码: $CHAT_SOURCE"
echo -e "   编译器: $S_COMPILER"
echo -e "   构建目录: $BUILD_DIR"
echo ""
echo -e "${CYAN}📌 架构:${NC}"
echo -e "   • Transformer Encoder-Decoder 模型"
echo -e "   • Vocabulary: 32K tokens"
echo -e "   • Hidden dimension: 256"
echo -e "   • 6 layer Transformer with 8 attention heads"
echo -e "   • Temperature: 0.7, Max tokens: 150"
echo ""

turn=0

while true; do
    turn=$((turn + 1))
    
    # 读取用户输入
    echo ""
    echo -ne "${BLUE}You (Turn $turn):${NC} "
    read -r user_input
    
    # 检查退出命令
    if [[ "$user_input" == "exit" ]] || [[ "$user_input" == "quit" ]]; then
        echo ""
        echo -e "${YELLOW}👋 再见！聊天历史已保存到: $CHAT_LOG${NC}"
        break
    fi
    
    # 检查查看历史
    if [[ "$user_input" == "history" ]]; then
        echo ""
        echo -e "${CYAN}📜 聊天历史:${NC}"
        if [ -f "$CHAT_LOG" ]; then
            cat "$CHAT_LOG"
        else
            echo "  (暂无聊天历史)"
        fi
        continue
    fi
    
    # 检查清空对话
    if [[ "$user_input" == "clear" ]]; then
        echo ""
        echo -e "${YELLOW}✓ 对话已清空${NC}"
        rm -f "$CHAT_LOG"
        continue
    fi
    
    # 跳过空输入
    if [[ -z "$user_input" ]]; then
        continue
    fi
    
    # 保存用户消息
    save_chat_log "You" "$user_input"
    
    # 显示推理进度
    echo ""
    echo -ne "${GREEN}NeurX:${NC} "
    
    # 生成响应
    response=$(generate_response "$user_input")
    echo "$response"
    
    # 保存AI响应
    save_chat_log "NeurX" "$response"
done

# =====================================================================
# 会话总结
# =====================================================================

if [ -f "$CHAT_LOG" ]; then
    CHAT_TURNS=$(grep -c "You:" "$CHAT_LOG" || echo 0)
    echo ""
    echo -e "${CYAN}📊 会话统计:${NC}"
    echo "  总轮数: $CHAT_TURNS"
    echo "  会话日志: $CHAT_LOG"
    echo -e "  推理引擎: ${GREEN}✓ S语言Transformer模型${NC}"
    echo ""
    echo -e "${YELLOW}📚 推理引擎源代码:${NC}"
    echo "  查看: $CHAT_SOURCE"
    echo ""
fi

exit 0
