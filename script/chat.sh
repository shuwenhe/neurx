#!/bin/bash

# NeurX Interactive Chat - ChatGPT-like循环聊天
# 集成真实的S语言推理引擎 (inference/production_inference.s)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$NEURX_DIR/output"
CHAT_DIR="$NEURX_DIR/chat_history"
BUILD_DIR="$NEURX_DIR/build/interactive_inference"
SESSION_ID="session_$(date +%s)"
CHAT_LOG="$CHAT_DIR/chat_${SESSION_ID}.txt"

# 推理引擎配置
S_COMPILER="${S_COMPILER:-/Users/feifei/train/s/.local/bin/s}"
CHAT_SOURCE="$NEURX_DIR/inference/production_inference.s"
RUNNER_IR="$BUILD_DIR/interactive_inference.ir"
RUNNER_BIN="$NEURX_DIR/build/s_ir_runner_train_model_large"
MODEL_BIN="$BUILD_DIR/interactive_inference.bin"
CHECKPOINT_PATH="${NEURX_INFER_CHECKPOINT:-$NEURX_DIR/artifacts/checkpoints/llm_s_pretrain}"
TOKENIZER_PATH="${NEURX_INFER_TOKENIZER_PATH:-$NEURX_DIR/data/corpus}"
DEVICE="${NEURX_INFER_DEVICE:-cpu}"

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
║         集成真实S语言推理引擎 (inference/production_inference.s)    ║
╚════════════════════════════════════════════════════════════════════╝

EOF
    echo -e "${CYAN}💬 欢迎使用 NeurX Chat！${NC}"
    echo -e "${YELLOW}🚀 推理引擎: S语言 Transformer 模型${NC}"
    echo "   输入 'exit' 或 'quit' 退出"
    echo "   输入 'history' 查看聊天历史"
    echo "   输入 'clear' 清空对话"
    echo ""
}

build_chat_prompt() {
    local user_input="$1"
    printf '你是一个认真、简洁的中文助手。请直接回答下面的问题，不要复述问题：\n%s\n答案：' "$user_input"
}

extract_model_response() {
    local raw_output="$1"
    local extracted

    extracted=$(printf '%s\n' "$raw_output" | awk '
        /^答案：$/ {capture=1; next}
        /^Answer:$/ {capture=1; next}
        /^\[phase\] generate:done$/ {capture=0}
        capture {print}
    ')

    if [ -n "$extracted" ]; then
        printf '%s\n' "$extracted" | sed '/^[[:space:]]*$/d' | tail -n 1
        return
    fi

    extracted=$(printf '%s\n' "$raw_output" | awk '
        /^Generated:$/ {capture=1; next}
        /^\[phase\] generate:done$/ {capture=0}
        capture {print}
    ')

    if [ -n "$extracted" ]; then
        printf '%s\n' "$extracted" | sed '/^[[:space:]]*$/d' | tail -n 1
        return
    fi

    printf '%s\n' "$raw_output" | tail -n 1
}

clean_model_output() {
    local user_input="$1"
    local raw_output="$2"
    local normalized

    normalized="$(extract_model_response "$raw_output")"
    normalized="${normalized//$'\r'/}"
    normalized="$(printf '%s\n' "$normalized" | sed '/^[[:space:]]*$/d')"

    if [ -z "$normalized" ]; then
        printf '%s\n' ""
        return
    fi

    normalized="$(printf '%s\n' "$normalized" | awk -v user_input="$user_input" '
        BEGIN { saw_user=0 }
        {
            if ($0 == user_input) {
                saw_user=1
                next
            }
            if ($0 ~ /^你是一个认真、简洁的中文助手。请直接回答下面的问题，不要复述问题：$/) {
                next
            }
            if ($0 ~ /^答案：$/ || $0 ~ /^Answer:$/ || $0 ~ /^Generated:$/) {
                next
            }
            print
        }
    ')"

    normalized="$(printf '%s\n' "$normalized" | sed '/^[[:space:]]*$/d')"
    if [ -n "$normalized" ]; then
        printf '%s\n' "$normalized" | tail -n 1
        return
    fi

    printf '%s\n' ""
}

generate_response() {
    local user_input="$1"
    local prompt
    prompt="$(build_chat_prompt "$user_input")"

    if [ ! -x "$RUNNER_BIN" ]; then
        printf "当前没有可执行的推理运行器，请先运行 \`bash script/run_interactive_inference.sh\` 完成编译。"
        return
    fi

    if [ ! -f "$RUNNER_IR" ]; then
        printf "当前没有找到推理 IR 文件，请先运行 \`bash script/run_interactive_inference.sh\` 生成模型运行产物。"
        return
    fi

    local raw_output
    raw_output=$(
        NEURX_INFER_CHECKPOINT="$CHECKPOINT_PATH" \
        NEURX_INFER_CHECKPOINT_PATH="$CHECKPOINT_PATH" \
        NEURX_CHECKPOINT_PATH="$CHECKPOINT_PATH" \
        NEURX_INFER_TOKENIZER_PATH="$TOKENIZER_PATH" \
        NEURX_TOKENIZER_PATH="$TOKENIZER_PATH" \
        NEURX_INFER_DEVICE="$DEVICE" \
        NEURX_DEVICE="$DEVICE" \
        NEURX_INFER_PROMPT="$prompt" \
        NEURX_INFERENCE_INPUT="$prompt" \
        NEURX_INFER_FALLBACK_PROMPT="$prompt" \
        NEURX_INFER_ANSWER_MODE="qa" \
        NEURX_INFER_ANSWER_ONLY="0" \
        NEURX_INFER_MAX_NEW_CHARS="$MAX_TOKENS" \
        NEURX_TEMPERATURE="$TEMPERATURE" \
        NEURX_TOP_P="$TOP_P" \
        "$RUNNER_BIN" "$RUNNER_IR" 2>&1 | tee -a "$BUILD_DIR/chat_inference.log" || true
    )

    local response
    response="$(clean_model_output "$user_input" "$raw_output")"

    if [ -z "$response" ]; then
        printf "模型没有返回内容，请检查 checkpoint 和推理运行器。"
        return
    fi

    printf '%s\n' "$response"
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
echo -e "   运行器: $RUNNER_BIN"
echo -e "   模型产物: $MODEL_BIN"
echo -e "   Checkpoint: $CHECKPOINT_PATH"
echo ""
echo -e "${CYAN}📌 架构:${NC}"
echo -e "   • 生产级 S 语言推理管线"
echo -e "   • Prompt -> IR runner -> checkpoint -> generation"
echo -e "   • Temperature: $TEMPERATURE, Max tokens: $MAX_TOKENS"
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
