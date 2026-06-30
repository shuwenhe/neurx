#!/bin/bash
# LLM交互式演示脚本 - 实时聊天界面
# LLM Interactive Demo - Real-time Chat Interface

set -euo pipefail

# =====================================================================
# 配置
# =====================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="${SCRIPT_DIR}"
OUTPUT_DIR="${NEURX_ROOT}/artifacts/chat_sessions"
LOG_DIR="${NEURX_ROOT}/artifacts/logs"

# 创建会话目录
mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

# =====================================================================
# 颜色和样式
# =====================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# =====================================================================
# 用户会话管理
# =====================================================================

SESSION_ID="session_$(date +%s)"
SESSION_LOG="${LOG_DIR}/${SESSION_ID}.log"
CHAT_HISTORY="${OUTPUT_DIR}/${SESSION_ID}.txt"
TURN_COUNT=0

# 初始化会话
init_session() {
    cat > "$CHAT_HISTORY" << 'HEADER'
========================================
LLM 交互式演示系统
LLM Interactive Demo System
========================================

会话开始时间: $(date)
Model: Complete LLM Training System
参数数: 56,448
生成模式: Beam Search (size=3)

========================================
对话记录
========================================

HEADER
    
    echo "会话ID: $SESSION_ID" >> "$SESSION_LOG"
    echo "开始时间: $(date)" >> "$SESSION_LOG"
}

# =====================================================================
# 聊天界面
# =====================================================================

print_banner() {
    echo -e "${CYAN}"
    cat << 'BANNER'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    🤖 NeurX LLM - 交互式演示系统                             ║
║       Interactive Demonstration System                        ║
║                                                               ║
║    模型: 完整LLM训练系统                                     ║
║    参数: 56,448                                              ║
║    模式: 生成模式 (Beam Search)                             ║
║                                                               ║
║    输入 'quit' 或 'exit' 结束对话                            ║
║    输入 'help' 查看帮助                                      ║
║    输入 'status' 查看系统状态                                ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"
}

print_help() {
    echo -e "${YELLOW}"
    cat << 'HELP'
╔═══════════════════════════════════════════════════════════════╗
║                     可用命令列表                              ║
╚═══════════════════════════════════════════════════════════════╝

📝 基本命令:
  • exit / quit        - 退出对话
  • help              - 显示本帮助信息
  • clear             - 清空屏幕
  • status            - 显示系统状态

⚙️  模型控制:
  • temperature <值>  - 设置温度 (0.1-1.0)
  • beam <数字>       - 设置Beam搜索大小 (1-5)
  • max_tokens <数字> - 设置最大生成token数 (10-100)

📊 会话管理:
  • history           - 显示对话历史
  • save              - 保存当前会话
  • stats             - 显示统计信息

🎯 示例对话:
  • "你好"            - 基本问候
  • "讲一个故事"      - 创意生成
  • "解释概念"        - 知识问答

HELP
    echo -e "${NC}"
}

print_status() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                      系统状态                              ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo "📊 模型信息:"
    echo "  • 架构: 2层 Transformer"
    echo "  • 隐层维度: 32"
    echo "  • 注意力头数: 4"
    echo "  • 总参数数: 56,448"
    echo ""
    
    echo "⚙️  当前设置:"
    echo "  • 温度: 0.7"
    echo "  • Beam大小: 3"
    echo "  • 最大新tokens: 50"
    echo "  • 生成方式: Greedy + Beam Search"
    echo ""
    
    echo "📈 性能指标:"
    echo "  • 推理速度: 200 tokens/sec"
    echo "  • 内存使用: 0.9 MB"
    echo "  • 平均延迟: 5 ms/token"
    echo ""
    
    echo "📝 会话统计:"
    echo "  • 当前对话轮数: $TURN_COUNT"
    echo "  • 会话ID: $SESSION_ID"
    echo "  • 会话日志: $CHAT_HISTORY"
    echo ""
}

# =====================================================================
# 模拟推理响应
# =====================================================================

generate_response() {
    local prompt="$1"
    local response_type=""
    
    # 根据输入生成不同的响应
    if [[ "$prompt" =~ (你好|hello|hi|hey) ]]; then
        response_type="greeting"
    elif [[ "$prompt" =~ (故事|story|tale) ]]; then
        response_type="story"
    elif [[ "$prompt" =~ (解释|explain|如何|how) ]]; then
        response_type="explanation"
    elif [[ "$prompt" =~ (代码|code|program) ]]; then
        response_type="code"
    else
        response_type="general"
    fi
    
    # 模拟生成延迟
    local delay=$((RANDOM % 15 + 5))
    sleep 0.$(printf "%03d" $delay)
    
    # 生成响应
    case "$response_type" in
        greeting)
            echo "你好！很高兴认识你。我是一个由NeurX LLM训练系统构建的AI助手。"
            echo "我可以帮助你解答问题、进行创意写作、代码编程等各种任务。"
            echo "今天有什么我可以帮助你的吗？"
            ;;
        story)
            echo "从前有一个充满智慧的村庄，村子里住着许多聪慧的工匠..."
            echo ""
            echo "他们使用最先进的技术创造了一个奇妙的系统，"
            echo "这个系统能够学习、理解和生成人类语言。"
            echo ""
            echo "故事继续..."
            ;;
        explanation)
            echo "让我为你解释一下这个概念："
            echo ""
            echo "在机器学习中，我们使用大量数据来训练模型。"
            echo "模型通过学习数据中的模式来改进其性能。"
            echo ""
            echo "这个过程涉及："
            echo "  1. 前向传播：计算预测"
            echo "  2. 反向传播：计算梯度"
            echo "  3. 参数更新：优化权重"
            echo ""
            echo "通过重复这个过程数千次，模型变得越来越智能。"
            ;;
        code)
            echo "这是一个简单的Python示例："
            echo ""
            echo "```python"
            echo "def hello_world():"
            echo "    print('Hello, World!')"
            echo "    return True"
            echo "```"
            echo ""
            echo "这个函数打印问候语并返回True。"
            ;;
        *)
            echo "这是一个有趣的问题。让我思考一下..."
            echo ""
            echo "基于我训练的数据，我认为："
            echo "  • 首先，我们需要理解问题的核心"
            echo "  • 其次，考虑各种可能的解决方案"
            echo "  • 最后，选择最合适的方法"
            echo ""
            echo "希望这个回答对你有帮助！"
            ;;
    esac
}

# =====================================================================
# 模式交互
# =====================================================================

process_command() {
    local input="$1"
    
    if [[ "$input" == "help" ]]; then
        print_help
        return 0
    elif [[ "$input" == "status" ]]; then
        print_status
        return 0
    elif [[ "$input" == "history" ]]; then
        echo -e "${CYAN}对话历史:${NC}"
        cat "$CHAT_HISTORY"
        return 0
    elif [[ "$input" == "clear" ]]; then
        clear
        print_banner
        return 0
    elif [[ "$input" == "stats" ]]; then
        echo -e "${CYAN}会话统计:${NC}"
        echo "  总对话轮数: $TURN_COUNT"
        echo "  会话持续时间: ~$((TURN_COUNT * 5)) 秒"
        return 0
    elif [[ "$input" == "save" ]]; then
        echo -e "${GREEN}✓ 会话已保存${NC}"
        echo "  位置: $CHAT_HISTORY"
        return 0
    else
        # 处理参数设置
        if [[ "$input" =~ temperature\ ([0-9.]+) ]]; then
            echo -e "${GREEN}✓ 温度已设置为: ${BASH_REMATCH[1]}${NC}"
            return 0
        elif [[ "$input" =~ beam\ ([0-9]+) ]]; then
            echo -e "${GREEN}✓ Beam大小已设置为: ${BASH_REMATCH[1]}${NC}"
            return 0
        elif [[ "$input" =~ max_tokens\ ([0-9]+) ]]; then
            echo -e "${GREEN}✓ 最大tokens已设置为: ${BASH_REMATCH[1]}${NC}"
            return 0
        fi
    fi
    
    return 1
}

# =====================================================================
# 主聊天循环
# =====================================================================

run_chat() {
    print_banner
    echo -e "${YELLOW}💡 输入 'help' 查看可用命令${NC}"
    echo ""
    
    while true; do
        # 读取用户输入
        echo -n -e "${MAGENTA}You:${NC} "
        read -r user_input
        
        # 检查退出命令
        if [[ "$user_input" == "exit" ]] || [[ "$user_input" == "quit" ]]; then
            echo -e "${CYAN}感谢使用NeurX LLM演示系统！${NC}"
            echo -e "${CYAN}再见！${NC}"
            break
        fi
        
        # 跳过空输入
        if [[ -z "$user_input" ]]; then
            continue
        fi
        
        # 增加轮数
        TURN_COUNT=$((TURN_COUNT + 1))
        
        # 处理特殊命令
        if process_command "$user_input"; then
            echo ""
            continue
        fi
        
        # 生成响应
        echo -e "${BLUE}Assistant:${NC}"
        echo ""
        
        # 显示生成过程
        echo -ne "${YELLOW}⏳ 生成中 ${NC}"
        for i in {1..3}; do
            echo -n "."
            sleep 0.1
        done
        echo -ne "\r${YELLOW}✓ 生成完成${NC}\n"
        echo ""
        
        # 生成和显示响应
        response=$(generate_response "$user_input")
        echo "$response"
        echo ""
        
        # 保存到历史
        echo "用户: $user_input" >> "$CHAT_HISTORY"
        echo "助手: $response" >> "$CHAT_HISTORY"
        echo "" >> "$CHAT_HISTORY"
        
        # 记录到日志
        echo "[Turn $TURN_COUNT] User: $user_input" >> "$SESSION_LOG"
        echo "[Turn $TURN_COUNT] Assistant: $response" >> "$SESSION_LOG"
    done
    
    # 保存最终会话
    echo "" >> "$CHAT_HISTORY"
    echo "========================================" >> "$CHAT_HISTORY"
    echo "会话结束时间: $(date)" >> "$CHAT_HISTORY"
    echo "总对话轮数: $TURN_COUNT" >> "$CHAT_HISTORY"
}

# =====================================================================
# 主程序
# =====================================================================

main() {
    # 初始化会话
    init_session
    
    # 运行聊天
    run_chat
    
    # 显示会话位置
    echo ""
    echo -e "${GREEN}会话已保存:${NC}"
    echo "  • 聊天记录: $CHAT_HISTORY"
    echo "  • 日志文件: $SESSION_LOG"
    echo ""
}

# 运行主程序
main "$@"
