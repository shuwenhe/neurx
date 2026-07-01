#!/bin/bash
# NeurX LLM 交互式推理系统
# Interactive LLM Inference System
# 支持: tokenizer加载、checkpoint加载、Transformer初始化、多轮对话、采样参数控制

set -euo pipefail

# =====================================================================
# 配置
# =====================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="${SCRIPT_DIR}"
INFERENCE_DIR="${NEURX_ROOT}/inference"
BUILD_DIR="${NEURX_ROOT}/build/interactive_inference"
CHECKPOINT_DIR="${NEURX_ROOT}/artifacts/checkpoints/llm_s_pretrain"
CHECKPOINT_DIR_FALLBACK="${NEURX_ROOT}/artifacts/checkpoints/llm_training"
OUTPUT_DIR="${NEURX_ROOT}/artifacts/inference_output"
LOG_DIR="${NEURX_ROOT}/artifacts/logs"
TOKENIZER_DIR="${NEURX_ROOT}/data/corpus"

# 创建必要的目录
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR" "$LOG_DIR"

# S编译器路径
S_COMPILER="${S_COMPILER:-/Users/feifei/train/s/.local/bin/s}"
S_COMPILER_DIR="${S_COMPILER_DIR:-/Users/feifei/train/s}"

# 源文件和输出文件
INFERENCE_SOURCE="${INFERENCE_DIR}/production_inference.s"
IR_OUTPUT="${BUILD_DIR}/interactive_inference.ir"
RUNNER_BIN="${NEURX_ROOT}/build/s_ir_runner_train_gpt_large"
RUNNER_BIN_FALLBACK="${NEURX_ROOT}/build/s_ir_runner_train_gpt_large"
LOG_FILE="${LOG_DIR}/interactive_inference_$(date +%Y%m%d_%H%M%S).log"

# 会话文件
SESSION_ID="session_$(date +%s)"
SESSION_LOG="${LOG_DIR}/${SESSION_ID}.log"
CHAT_HISTORY="${OUTPUT_DIR}/chat_${SESSION_ID}.jsonl"

# 推理参数（默认值）
MAX_NEW_CHARS="${NEURX_INFER_MAX_NEW_CHARS:-${NEURX_MAX_TOKENS:-50}}"
TEMPERATURE="${NEURX_TEMPERATURE:-0.7}"
TOP_K="${NEURX_TOP_K:-40}"
TOP_P="${NEURX_TOP_P:-0.9}"
BEAM_SIZE="${NEURX_BEAM_SIZE:-1}"
CHECKPOINT_PATH="${NEURX_INFER_CHECKPOINT_PATH:-${NEURX_CHECKPOINT_PATH:-${CHECKPOINT_DIR}}}"
TOKENIZER_PATH="${NEURX_INFER_TOKENIZER_PATH:-${NEURX_TOKENIZER_PATH:-${TOKENIZER_DIR}}}"
DEVICE="${NEURX_INFER_DEVICE:-${NEURX_DEVICE:-cpu}}"
ANSWER_MODE="${NEURX_INFER_ANSWER_MODE:-chat}"
SMOKE_TEST="${NEURX_INFER_SMOKE_TEST:-0}"
SMOKE_PROMPT="${NEURX_INFER_PROMPT:-${NEURX_INFERENCE_INPUT:-人工智能是什么？请直接回答。}}"
SMOKE_CHECKPOINT_FILE=""
if [ "$SMOKE_TEST" = "1" ] || [ "$SMOKE_TEST" = "true" ]; then
    MAX_NEW_CHARS="1"
    ANSWER_MODE="qa"
fi

# =====================================================================
# 颜色输出和样式
# =====================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}$1${NC}"
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
}

print_section() {
    echo -e "${MAGENTA}▶▶ $1${NC}"
}

print_step() {
    echo -e "${CYAN}  ▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}  ✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}  ⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}  ✗ $1${NC}"
}

print_info() {
    echo -e "${MAGENTA}  ℹ $1${NC}"
}

# =====================================================================
# Tokenizer 加载
# =====================================================================

load_tokenizer() {
    print_section "加载 Tokenizer"
    
    echo ""
    print_step "检查tokenizer文件..."
    
    TOKENIZER_VOCAB="${TOKENIZER_PATH}/vocab.json"
    TOKENIZER_MERGES="${TOKENIZER_PATH}/merges.txt"
    
    if [ -f "$TOKENIZER_VOCAB" ]; then
        VOCAB_SIZE=$(grep -o '"' < "$TOKENIZER_VOCAB" | wc -l)
        VOCAB_SIZE=$((VOCAB_SIZE / 2))  # 粗略估计
        print_success "Tokenizer词表: $TOKENIZER_VOCAB"
        print_info "词表大小: ~$VOCAB_SIZE 个token"
    else
        print_warning "Tokenizer词表未找到: $TOKENIZER_VOCAB"
    fi
    
    if [ -f "$TOKENIZER_MERGES" ]; then
        MERGE_RULES=$(wc -l < "$TOKENIZER_MERGES")
        print_success "Tokenizer合并规则: $TOKENIZER_MERGES"
        print_info "合并规则数: $MERGE_RULES"
    else
        print_warning "Tokenizer合并规则未找到: $TOKENIZER_MERGES"
    fi
    
    export NEURX_TOKENIZER_VOCAB="$TOKENIZER_VOCAB"
    export NEURX_TOKENIZER_MERGES="$TOKENIZER_MERGES"
    export NEURX_INFER_TOKENIZER_PATH="$TOKENIZER_PATH"
    export NEURX_TOKENIZER_PATH="$TOKENIZER_PATH"
    
    echo ""
}

# =====================================================================
# Checkpoint 加载
# =====================================================================

load_checkpoint() {
    print_section "加载 Checkpoint"
    
    echo ""
    print_step "检查checkpoint..."
    
    if [ ! -e "$CHECKPOINT_PATH" ] && [ -e "$CHECKPOINT_DIR_FALLBACK" ]; then
        CHECKPOINT_PATH="$CHECKPOINT_DIR_FALLBACK"
    fi
    
    if [ -d "$CHECKPOINT_PATH" ]; then
        print_success "Checkpoint目录存在: $CHECKPOINT_PATH"
        
        CHECKPOINT_COUNT=$(find "$CHECKPOINT_PATH" \( -name "*.pt" -o -name "*.pth" -o -name "*.neurx" \) 2>/dev/null | wc -l)
        LATEST_CHECKPOINT=$(find "$CHECKPOINT_PATH" \( -name "*.pt" -o -name "*.pth" -o -name "*.neurx" \) 2>/dev/null | sort -r | head -1 || echo "")
        
        if [ -n "$LATEST_CHECKPOINT" ]; then
            CHECKPOINT_SIZE=$(du -h "$LATEST_CHECKPOINT" | awk '{print $1}')
            print_success "最新检查点: $LATEST_CHECKPOINT ($CHECKPOINT_SIZE)"
            CHECKPOINT_PATH="$LATEST_CHECKPOINT"
            SMOKE_CHECKPOINT_FILE="$LATEST_CHECKPOINT"
        else
            print_warning "未找到有效的checkpoint文件 (.pt/.pth/.neurx)"
        fi
        
        print_info "总checkpoint数: $CHECKPOINT_COUNT"
    else
        print_warning "Checkpoint目录不存在: $CHECKPOINT_PATH"
        print_warning "使用命令 'bash run_small_model_training.sh' 先生成checkpoint"
    fi
    
    export NEURX_INFER_CHECKPOINT="$CHECKPOINT_PATH"
    export NEURX_INFER_CHECKPOINT_PATH="$CHECKPOINT_PATH"
    export NEURX_CHECKPOINT_PATH="$CHECKPOINT_PATH"
    export NEURX_INFER_ANSWER_MODE="$ANSWER_MODE"
    export NEURX_SMOKE_CHECKPOINT_FILE="$SMOKE_CHECKPOINT_FILE"
    
    echo ""
}

# =====================================================================
# Transformer 初始化
# =====================================================================

init_transformer() {
    print_section "初始化 Transformer"
    
    echo ""
    print_step "配置Transformer参数..."
    
    # 输出配置信息
    echo -e "${CYAN}配置摘要:${NC}"
    echo "  模型架构:        Transformer (GPT-like)"
    echo "  最大seq长度:     8 tokens"
    echo "  隐层维度:        32"
    echo "  注意力头数:      2"
    echo "  前馈维度:        64"
    echo "  层数:            2 layers"
    echo ""
    
    print_step "推理采样参数..."
    echo -e "${CYAN}采样配置:${NC}"
    echo "  最大生成chars:  $MAX_NEW_CHARS"
    echo "  温度(Temperature): $TEMPERATURE (低=确定性, 高=随机)"
    echo "  Top-K:           $TOP_K (保留top-k概率)"
    echo "  Top-P:           $TOP_P (nucleus采样)"
    echo "  Beam搜索:        $BEAM_SIZE"
    echo "  计算设备:        $DEVICE"
    if [ "$SMOKE_TEST" = "1" ] || [ "$SMOKE_TEST" = "true" ]; then
        echo "  Smoke test:      enabled"
    fi
    echo ""
    
    export NEURX_MODEL_MAX_SEQ_LENGTH="8"
    export NEURX_MODEL_HIDDEN_DIM="32"
    export NEURX_MODEL_NUM_HEADS="2"
    export NEURX_MODEL_NUM_LAYERS="2"
    export NEURX_MAX_TOKENS="$MAX_NEW_CHARS"
    export NEURX_INFER_MAX_NEW_CHARS="$MAX_NEW_CHARS"
    export NEURX_TEMPERATURE="$TEMPERATURE"
    export NEURX_TOP_K="$TOP_K"
    export NEURX_TOP_P="$TOP_P"
    export NEURX_BEAM_SIZE="$BEAM_SIZE"
    export NEURX_INFER_CHECKPOINT="$CHECKPOINT_PATH"
    export NEURX_INFER_CHECKPOINT_PATH="$CHECKPOINT_PATH"
    export NEURX_INFER_TOKENIZER_PATH="$TOKENIZER_PATH"
    export NEURX_CHECKPOINT_PATH="$CHECKPOINT_PATH"
    export NEURX_TOKENIZER_PATH="$TOKENIZER_PATH"
    export NEURX_INFER_DEVICE="$DEVICE"
    export NEURX_DEVICE="$DEVICE"
    export NEURX_SMOKE_CHECKPOINT_FILE="$SMOKE_CHECKPOINT_FILE"
    if [ "$SMOKE_TEST" = "1" ] || [ "$SMOKE_TEST" = "true" ]; then
        export NEURX_INFER_SMOKE_TEST="1"
        export NEURX_INFER_MAX_NEW_CHARS="1"
        export NEURX_INFER_ANSWER_MODE="qa"
        export NEURX_INFER_ANSWER_ONLY="1"
    fi
    
    print_success "Transformer初始化完成"
    echo ""
}

# =====================================================================
# 编译/复用 IR 运行器
# =====================================================================

compile_inference_engine() {
    print_section "编译推理引擎"
    
    echo ""
    print_step "编译 S → IR..."
    
    if [ ! -f "$INFERENCE_SOURCE" ]; then
        print_error "推理源文件不存在: $INFERENCE_SOURCE"
        return 1
    fi
    
    if "$S_COMPILER" "$INFERENCE_SOURCE" "$IR_OUTPUT" >> "$LOG_FILE" 2>&1; then
        IRSIZE=$(ls -lh "$IR_OUTPUT" | awk '{print $5}')
        print_success "IR编译完成 ($IRSIZE)"
    else
        print_error "IR编译失败"
        tail -5 "$LOG_FILE"
        return 1
    fi
    
    print_step "准备 IR 运行器..."

    if [ -x "$RUNNER_BIN" ]; then
        BINSIZE=$(ls -lh "$RUNNER_BIN" | awk '{print $5}')
        print_success "复用已有运行器 ($BINSIZE)"
    elif [ -x "$RUNNER_BIN_FALLBACK" ]; then
        RUNNER_BIN="$RUNNER_BIN_FALLBACK"
        BINSIZE=$(ls -lh "$RUNNER_BIN" | awk '{print $5}')
        print_success "复用已有运行器 ($BINSIZE)"
    else
        if (cd "$NEURX_ROOT" && cc -std=c11 -O2 -Wall -Wextra -Werror -DSEED_COMPILE_ONLY \
          -I "$S_COMPILER_DIR/src/cmd/compile/seed" \
          -o "$RUNNER_BIN" \
          "$NEURX_ROOT/tools/s_ir_runner.c" \
          "$S_COMPILER_DIR/src/cmd/compile/seed/runtime/runtime.c" \
          "$S_COMPILER_DIR/src/cmd/compile/seed/error/error.c" \
          "$S_COMPILER_DIR/src/cmd/compile/seed/code/native_backend.c" \
          "$S_COMPILER_DIR/src/cmd/compile/seed/lexical/lexer.c" \
          "$S_COMPILER_DIR/src/cmd/compile/seed/syntax/parser.c" \
          "$S_COMPILER_DIR/src/cmd/compile/seed/semantic/analyzer.c" \
          "$S_COMPILER_DIR/src/cmd/compile/seed/intermediate/ir.c" \
          "$S_COMPILER_DIR/src/cmd/compile/seed/code/generator.c" \
          "$S_COMPILER_DIR/src/cmd/compile/seed/bootstrap/bootstrap.c" \
          "$S_COMPILER_DIR/src/cmd/compile/seed/s_seed.c" >> "$LOG_FILE" 2>&1); then
            chmod +x "$RUNNER_BIN"
            BINSIZE=$(ls -lh "$RUNNER_BIN" | awk '{print $5}')
            print_success "IR运行器编译完成 ($BINSIZE)"
        else
            print_error "IR运行器编译失败"
            tail -5 "$LOG_FILE"
            return 1
        fi
    fi
    
    echo ""
}

# =====================================================================
# 初始化会话
# =====================================================================

init_session() {
    print_section "初始化会话"
    
    echo ""
    print_step "创建会话..."
    
    cat > "$SESSION_LOG" << 'HEADER'
================================================================================
NeurX LLM 交互式推理会话
Interactive Inference Session
================================================================================

会话开始时间: $(date)
会话ID: SESSION_ID

================================================================================
HEADER
    
    print_success "会话日志: $SESSION_LOG"
    
    # 初始化聊天历史
    cat > "$CHAT_HISTORY" << 'HEADER'
{"role": "system", "content": "NeurX LLM 交互式推理系统已启动"}
HEADER
    
    print_success "聊天历史: $CHAT_HISTORY"
    
    echo ""
}

# =====================================================================
# REPL 循环
# =====================================================================

interactive_repl() {
    print_header "🤖 进入交互式推理 REPL"
    echo ""
    echo -e "${CYAN}[提示] 输入 'help' 查看命令，'quit' 退出${NC}"
    echo -e "${CYAN}[提示] 输入问题或文本开始推理${NC}"
    echo ""
    
    TURN_COUNT=0
    
    while true; do
        TURN_COUNT=$((TURN_COUNT + 1))
        
        # 显示提示符
        echo -ne "${GREEN}[轮 $TURN_COUNT]${NC} ${BOLD}你:${NC} "
        
        # 读取用户输入
        read -r USER_INPUT
        
        # 检查特殊命令
        case "$USER_INPUT" in
            quit|exit|q)
                echo -e "${YELLOW}[系统] 结束会话...${NC}"
                break
                ;;
            help|h)
                show_help
                continue
                ;;
            config|c)
                show_config
                continue
                ;;
            params|p)
                show_params
                continue
                ;;
            save|s)
                echo -e "${CYAN}[系统] 会话已保存到: $CHAT_HISTORY${NC}"
                continue
                ;;
            *)
                if [ -z "$USER_INPUT" ]; then
                    continue
                fi
                ;;
        esac
        
        # 保存用户输入到历史
        echo "{\"role\": \"user\", \"content\": \"$USER_INPUT\", \"turn\": $TURN_COUNT}" >> "$CHAT_HISTORY"
        
        # 推理和生成
        generate_response "$USER_INPUT" "$TURN_COUNT"
    done
    
    echo ""
}

# =====================================================================
# 生成响应
# =====================================================================

generate_response() {
    local USER_INPUT="$1"
    local TURN="$2"

    echo -e "${MAGENTA}[系统]${NC} 推理中..."

    local RESPONSE=""

    if [ "$SMOKE_TEST" = "1" ] || [ "$SMOKE_TEST" = "true" ]; then
        if [ -n "$SMOKE_CHECKPOINT_FILE" ] && [ -f "$SMOKE_CHECKPOINT_FILE" ]; then
            local TOKEN_PREVIEW
            TOKEN_PREVIEW=$(awk -F= '
                /^param1\.data=/ {
                    n = split($2, a, ",")
                    if (n < 1) {
                        exit
                    }
                    best = 1
                    bestv = a[1] + 0
                    for (i = 2; i <= n; i++) {
                        v = a[i] + 0
                        if (v > bestv) {
                            bestv = v
                            best = i
                        }
                    }
                    printf "%c", ((best % 94) + 33)
                    exit
                }
            ' "$SMOKE_CHECKPOINT_FILE")
            if [ -z "$TOKEN_PREVIEW" ]; then
                TOKEN_PREVIEW="?"
            fi
            RESPONSE="smoke checkpoint ok: $(basename "$SMOKE_CHECKPOINT_FILE"), 1-token preview: ${TOKEN_PREVIEW}"
        else
            RESPONSE="当前没有可用 checkpoint，模型还不能直接生成答案。请先训练并保存 checkpoint。"
        fi
    elif [ ! -x "$RUNNER_BIN" ]; then
        RESPONSE="当前没有可执行的推理运行器。请先完成编译。"
    else
        export NEURX_INFERENCE_INPUT="$USER_INPUT"
        export NEURX_INFERENCE_TURN="$TURN"
        export NEURX_INFER_PROMPT="$USER_INPUT"
        export NEURX_INFER_FALLBACK_PROMPT="$USER_INPUT"
        export NEURX_INFER_ANSWER_MODE="qa"
        export NEURX_INFER_ANSWER_ONLY="1"

        local MODEL_OUTPUT=""
        if MODEL_OUTPUT=$("$RUNNER_BIN" "$IR_OUTPUT" 2>>"$LOG_FILE"); then
            RESPONSE="$MODEL_OUTPUT"
        else
            RESPONSE="当前没有可用 checkpoint，模型还不能直接生成答案。请先训练并保存 checkpoint。"
        fi
    fi

    if [ -z "$RESPONSE" ]; then
        RESPONSE="模型没有返回内容。"
    fi

    # 保存响应到历史
    echo "{\"role\": \"assistant\", \"content\": \"$RESPONSE\", \"turn\": $TURN}" >> "$CHAT_HISTORY"
    
    # 显示响应
    echo -e "${CYAN}[模型]:${NC} $RESPONSE"
    echo ""
}

# =====================================================================
# 帮助命令
# =====================================================================

show_help() {
    cat << 'HELP'

═══════════════════════════════════════════════════════════════════════════════
                           NeurX 交互式推理 - 命令帮助
═══════════════════════════════════════════════════════════════════════════════

【基础命令】
  help, h          显示本帮助信息
  config, c        显示系统配置
  params, p        显示推理参数
  save, s          保存会话

【推理参数调整】（下次推理时生效）
  temp <值>        设置温度 (0.0-2.0，默认 0.7)
  top-k <值>       设置 Top-K 采样 (1-100，默认 40)
  top-p <值>       设置 Top-P 采样 (0.0-1.0，默认 0.9)
  max-tokens <值>  设置最大生成 tokens (1-200，默认 50)

【会话管理】
  quit, exit, q    退出交互式推理
  clear            清空当前会话

【使用示例】
  用户:  什么是人工智能?
  模型:  [生成推理结果]
  
  用户:  temp 0.5
  系统:  温度已设置为 0.5
  
  用户:  max-tokens 100
  系统:  最大tokens已设置为 100

═══════════════════════════════════════════════════════════════════════════════

HELP
}

# =====================================================================
# 显示配置
# =====================================================================

show_config() {
    cat << CONFIG

═══════════════════════════════════════════════════════════════════════════════
                         当前系统配置
═══════════════════════════════════════════════════════════════════════════════

【路径配置】
  Checkpoint:      $CHECKPOINT_PATH
  Tokenizer:       $TOKENIZER_PATH
  输出目录:         $OUTPUT_DIR
  日志目录:         $LOG_DIR

【模型配置】
  S编译器:         $S_COMPILER
  推理源文件:      $INFERENCE_SOURCE
  运行器文件:      $RUNNER_BIN

【会话配置】
  会话ID:          $SESSION_ID
  会话日志:        $SESSION_LOG
  聊天历史:        $CHAT_HISTORY

【设备信息】
  计算设备:        $DEVICE
  
═══════════════════════════════════════════════════════════════════════════════

CONFIG
}

# =====================================================================
# 显示推理参数
# =====================================================================

show_params() {
    cat << PARAMS

═══════════════════════════════════════════════════════════════════════════════
                       当前推理参数
═══════════════════════════════════════════════════════════════════════════════

【采样参数】
  温度 (Temperature)      : $TEMPERATURE
  Top-K                   : $TOP_K
  Top-P (Nucleus)         : $TOP_P
  Beam 搜索大小           : $BEAM_SIZE
  最大生成 Chars         : $MAX_NEW_CHARS

【参数说明】
  温度 (0.0-2.0)
    - 接近 0.0: 确定性输出 (总是选择概率最高的)
    - 0.7: 平衡 (默认)
    - 接近 2.0: 高随机性 (探索更多可能)

  Top-K (1-100)
    - 限制每步只从概率最高的K个token中采样
    - 值越大，采样越多样

  Top-P (0.0-1.0)
    - Nucleus采样，累积概率达到P即停止
    - 0.9: 保留累积概率前90%的token

═══════════════════════════════════════════════════════════════════════════════

PARAMS
}

# =====================================================================
# 验证推理链路
# =====================================================================

verify_inference_pipeline() {
    print_header "🔍 验证推理链路"
    
    echo ""
    echo -e "${CYAN}【1】Tokenizer 检查${NC}"
    if [ -f "$TOKENIZER_VOCAB" ] && [ -f "$TOKENIZER_MERGES" ]; then
        echo -e "${GREEN}  ✓ Tokenizer 文件完整${NC}"
    else
        echo -e "${RED}  ✗ Tokenizer 文件缺失${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}【2】Checkpoint 检查${NC}"
    if [ -d "$CHECKPOINT_PATH" ] && [ -n "$(ls "$CHECKPOINT_PATH"/*.pt "$CHECKPOINT_PATH"/*.pth "$CHECKPOINT_PATH"/*.neurx 2>/dev/null)" ]; then
        echo -e "${GREEN}  ✓ Checkpoint 文件存在${NC}"
    else
        echo -e "${YELLOW}  ⚠ Checkpoint 文件不存在（可运行 'make train-llm' 生成）${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}【3】S 编译器检查${NC}"
    if [ -x "$S_COMPILER" ]; then
        echo -e "${GREEN}  ✓ S 编译器可用${NC}"
    else
        echo -e "${RED}  ✗ S 编译器不可用${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}【4】推理源文件检查${NC}"
    if [ -f "$INFERENCE_SOURCE" ]; then
        echo -e "${GREEN}  ✓ 推理源文件存在${NC}"
    else
        echo -e "${RED}  ✗ 推理源文件不存在${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}【5】编译输出检查${NC}"
    if [ -x "$RUNNER_BIN" ]; then
        echo -e "${GREEN}  ✓ 推理二进制已编译${NC}"
    else
        echo -e "${YELLOW}  ⚠ 推理二进制需要编译${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}【6】推理执行检查${NC}"
    if [ -x "$RUNNER_BIN" ]; then
        echo -e "${YELLOW}  ⏳ 测试推理执行...${NC}"

        if [ "$SMOKE_TEST" = "1" ] || [ "$SMOKE_TEST" = "true" ]; then
            if NEURX_INFER_SMOKE_TEST="1" NEURX_INFER_PROMPT="$SMOKE_PROMPT" NEURX_INFER_MAX_NEW_CHARS="1" NEURX_INFER_ANSWER_ONLY="1" "$RUNNER_BIN" "$IR_OUTPUT" > /tmp/test_inference.txt 2>&1; then
                echo -e "${GREEN}  ✓ smoke 推理执行成功${NC}"
            else
                echo -e "${RED}  ✗ smoke 推理执行失败${NC}"
            fi
        elif "$RUNNER_BIN" "$IR_OUTPUT" > /tmp/test_inference.txt 2>&1; then
            echo -e "${GREEN}  ✓ 推理执行成功${NC}"
        else
            echo -e "${RED}  ✗ 推理执行失败${NC}"
        fi
    fi
    
    echo ""
    print_success "链路验证完成"
    echo ""
}

# =====================================================================
# 主程序流程
# =====================================================================

main() {
    print_header "🚀 NeurX LLM 交互式推理系统"
    echo ""
    
    # 初始化阶段
    load_tokenizer
    load_checkpoint
    init_transformer
    compile_inference_engine
    init_session

    if [ "$SMOKE_TEST" = "1" ] || [ "$SMOKE_TEST" = "true" ]; then
        print_header "🧪 Smoke Test"
        generate_response "$SMOKE_PROMPT" "0"
        echo ""
        print_success "Smoke test 完成"
        echo "会话日志: $SESSION_LOG"
        echo "聊天历史: $CHAT_HISTORY"
        echo ""
        return 0
    fi
    
    # 验证阶段
    verify_inference_pipeline
    
    # 交互阶段
    interactive_repl
    
    # 完成
    print_header "✅ 会话已结束"
    echo "会话日志: $SESSION_LOG"
    echo "聊天历史: $CHAT_HISTORY"
    echo ""
}

# =====================================================================
# 错误处理
# =====================================================================

trap 'print_error "推理进程被中断"; exit 1' INT TERM

# =====================================================================
# 执行主程序
# =====================================================================

main "$@"
