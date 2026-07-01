#!/bin/bash
# LLM推理启动脚本 - S编译器集成版本
# LLM Inference Launcher - S Compiler Integration Version
# 使用真实的S编译器编译和运行 checkpoint 推理流程

set -euo pipefail

# =====================================================================
# 配置
# =====================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="${SCRIPT_DIR}"
INFERENCE_DIR="${NEURX_ROOT}/inference"
BUILD_DIR="${NEURX_ROOT}/build/inference"
CHECKPOINT_DIR="${NEURX_ROOT}/artifacts/checkpoints/llm_s_pretrain"
OUTPUT_DIR="${NEURX_ROOT}/artifacts/inference_output"
LOG_DIR="${NEURX_ROOT}/artifacts/logs"

# 创建必要的目录
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR" "$LOG_DIR"

# S编译器路径
S_COMPILER="${S_COMPILER:-/Users/feifei/train/s/.local/bin/s}"
S_COMPILER_DIR="${S_COMPILER_DIR:-/Users/feifei/train/s}"

# 源文件和输出文件
INFERENCE_SOURCE="${INFERENCE_DIR}/production_inference.s"
IR_OUTPUT="${BUILD_DIR}/inference.ir"
RUNNER_BIN="${BUILD_DIR}/inference_runner"
RUNNER_BIN_FALLBACK="${NEURX_ROOT}/build/s_ir_runner_train_gpt_large"
LOG_FILE="${LOG_DIR}/inference_$(date +%Y%m%d_%H%M%S).log"

# 推理参数 (可通过环境变量覆盖)
MODEL_CHECKPOINT="${NEURX_INFER_CHECKPOINT_PATH:-${NEURX_INFER_CHECKPOINT:-$CHECKPOINT_DIR}}"
SEED="${NEURX_INFER_SEED:-neurx }"
MAX_NEW_CHARS="${NEURX_INFER_MAX_NEW_CHARS:-120}"
VALIDATE_ONLY="${NEURX_INFER_VALIDATE_ONLY:-}"
MODEL_NAME="${NEURX_INFER_MODEL_NAME:-llm_s}"
DEVICE="${NEURX_INFER_DEVICE:-${NEURX_DEVICE:-cpu}}"
QUESTION="${NEURX_INFER_QUESTION:-${NEURX_INFER_PROMPT:-${NEURX_INFERENCE_INPUT:-人工智能是什么？请直接回答。}}}"
ANSWER_MODE="${NEURX_INFER_ANSWER_MODE:-qa}"
FALLBACK_PROMPT="${NEURX_INFER_FALLBACK_PROMPT:-$QUESTION}"

# =====================================================================
# 颜色输出
# =====================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
}

print_step() {
    echo -e "${CYAN}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${MAGENTA}ℹ $1${NC}"
}

# =====================================================================
# 环境检查
# =====================================================================

check_environment() {
    print_step "检查推理环境..."
    
    # 检查S编译器
    if [ ! -f "$S_COMPILER" ]; then
        print_error "S编译器未找到: $S_COMPILER"
        echo "请确保S编译器已安装，或设置 S_COMPILER 环境变量"
        exit 1
    fi
    print_success "S编译器: $S_COMPILER"
    
    # 检查推理源文件
    if [ ! -f "$INFERENCE_SOURCE" ]; then
        print_error "推理源文件未找到: $INFERENCE_SOURCE"
        exit 1
    fi
    print_success "推理源文件: $INFERENCE_SOURCE"
    
    # 检查 checkpoint 配置
    if [ -z "$MODEL_CHECKPOINT" ]; then
        print_error "未配置推理 checkpoint"
        exit 1
    fi

    if [ -e "$MODEL_CHECKPOINT" ]; then
        print_success "推理 checkpoint: $MODEL_CHECKPOINT"
        if [ -d "$MODEL_CHECKPOINT" ]; then
            LATEST_CHECKPOINT=$(find "$MODEL_CHECKPOINT" \( -name "*.pt" -o -name "*.pth" -o -name "*.neurx" \) 2>/dev/null | sort -r | head -1 || echo "")
            if [ -n "$LATEST_CHECKPOINT" ]; then
                MODEL_CHECKPOINT="$LATEST_CHECKPOINT"
                print_info "解析到最新 checkpoint 文件: $MODEL_CHECKPOINT"
            fi
        fi
    else
        print_warning "推理 checkpoint 不存在: $MODEL_CHECKPOINT"
        print_warning "如果这是目录，确保其中包含 latest_checkpoint.txt 或有效模型文件"
    fi

    # 创建输出目录
    mkdir -p "$BUILD_DIR" "$OUTPUT_DIR" "$LOG_DIR"
    print_success "输出目录已创建"
    
    echo ""
}

# =====================================================================
# 编译推理引擎 (S → IR)
# =====================================================================

compile_to_ir() {
    print_step "编译推理引擎 (S → IR)..."
    
    if [ -f "$IR_OUTPUT" ]; then
        print_warning "IR文件已存在，覆盖: $IR_OUTPUT"
        rm -f "$IR_OUTPUT"
    fi
    
    echo "  源文件: $INFERENCE_SOURCE"
    echo "  输出: $IR_OUTPUT"
    echo "  编译器: $S_COMPILER"
    echo ""
    
    if "$S_COMPILER" "$INFERENCE_SOURCE" "$IR_OUTPUT" >> "$LOG_FILE" 2>&1; then
        print_success "IR编译完成"
        echo "  生成文件: $(ls -lh "$IR_OUTPUT" | awk '{print $9, "(" $5 ")"}' )"
    else
        print_error "IR编译失败，查看日志: $LOG_FILE"
        tail -20 "$LOG_FILE"
        exit 1
    fi
    echo ""
}

# =====================================================================
# 编译/复用 IR 运行器
# =====================================================================

compile_to_binary() {
    print_step "准备 IR 运行器..."

    if [ -x "$RUNNER_BIN" ]; then
        print_success "复用已有运行器: $RUNNER_BIN"
        echo ""
        return 0
    fi

    if [ -x "$RUNNER_BIN_FALLBACK" ]; then
        RUNNER_BIN="$RUNNER_BIN_FALLBACK"
        print_success "复用已有运行器: $RUNNER_BIN"
        echo ""
        return 0
    fi

    print_step "编译 IR 运行器..."
    echo "  输出: $RUNNER_BIN"
    echo ""

    if (cd "$NEURX_ROOT" && cc -std=c11 -O2 -Wall -Wextra -Werror -DSEED_COMPILE_ONLY \
      -I "$S_ROOT/src/cmd/compile/seed" \
      -o "$RUNNER_BIN" \
      "$NEURX_ROOT/tools/s_ir_runner.c" \
      "$S_ROOT/src/cmd/compile/seed/runtime/runtime.c" \
      "$S_ROOT/src/cmd/compile/seed/error/error.c" \
      "$S_ROOT/src/cmd/compile/seed/code/native_backend.c" \
      "$S_ROOT/src/cmd/compile/seed/lexical/lexer.c" \
      "$S_ROOT/src/cmd/compile/seed/syntax/parser.c" \
      "$S_ROOT/src/cmd/compile/seed/semantic/analyzer.c" \
      "$S_ROOT/src/cmd/compile/seed/intermediate/ir.c" \
      "$S_ROOT/src/cmd/compile/seed/code/generator.c" \
      "$S_ROOT/src/cmd/compile/seed/bootstrap/bootstrap.c" \
      "$S_ROOT/src/cmd/compile/seed/s_seed.c" >> "$LOG_FILE" 2>&1); then
        chmod +x "$RUNNER_BIN"
        print_success "IR运行器编译完成"
        echo "  生成文件: $(ls -lh "$RUNNER_BIN" | awk '{print $9, "(" $5 ")"}')"
    else
        print_error "IR运行器编译失败，查看日志: $LOG_FILE"
        tail -20 "$LOG_FILE"
        exit 1
    fi
    echo ""
}

# =====================================================================
# 运行推理
# =====================================================================

run_inference() {
    print_step "运行推理引擎..."
    
    echo "推理参数:"
    echo "  模型名: $MODEL_NAME"
    echo "  checkpoint: $MODEL_CHECKPOINT"
    echo "  seed: $SEED"
    echo "  max new chars: $MAX_NEW_CHARS"
    echo "  validate only: ${VALIDATE_ONLY:-0}"
    echo "  设备: $DEVICE"
    echo "  问题: $QUESTION"
    echo ""
    
    INFERENCE_OUTPUT="${OUTPUT_DIR}/inference_$(date +%Y%m%d_%H%M%S).txt"
    
    if [ -x "$RUNNER_BIN" ]; then
        print_step "执行推理运行器..."
        
        # 导出推理参数给二进制程序
        export NEURX_INFER_MODEL_NAME="$MODEL_NAME"
        export NEURX_INFER_CHECKPOINT="$MODEL_CHECKPOINT"
        export NEURX_INFER_CHECKPOINT_PATH="$MODEL_CHECKPOINT"
        export NEURX_INFER_SEED="$SEED"
        export NEURX_INFER_MAX_NEW_CHARS="$MAX_NEW_CHARS"
        export NEURX_INFER_VALIDATE_ONLY="$VALIDATE_ONLY"
        export NEURX_INFER_DEVICE="$DEVICE"
        export NEURX_INFER_QUESTION="$QUESTION"
        export NEURX_INFER_PROMPT="$QUESTION"
        export NEURX_INFERENCE_INPUT="$QUESTION"
        export NEURX_INFER_ANSWER_MODE="$ANSWER_MODE"
        export NEURX_INFER_FALLBACK_PROMPT="$FALLBACK_PROMPT"
        export NEURX_DEVICE="$DEVICE"
        
        if "$RUNNER_BIN" "$IR_OUTPUT" > "$INFERENCE_OUTPUT" 2>> "$LOG_FILE"; then
            print_success "推理完成"
            echo ""
            echo "════════════════════════════════════════════════════════════════"
            echo "推理结果:"
            echo "════════════════════════════════════════════════════════════════"
            cat "$INFERENCE_OUTPUT"
            echo ""
            echo "════════════════════════════════════════════════════════════════"
            echo "输出保存到: $INFERENCE_OUTPUT"
        else
            print_error "推理执行失败，查看日志: $LOG_FILE"
            tail -20 "$LOG_FILE"
            exit 1
        fi
    else
        print_error "推理运行器不可执行: $RUNNER_BIN"
        exit 1
    fi
    echo ""
}

# =====================================================================
# 主程序流程
# =====================================================================

main() {
    print_header "🚀 NeurX LLM 推理启动系统"
    
    print_info "推理工作流程"
    echo "  1. 环境检查"
    echo "  2. S → IR 编译"
    echo "  3. IR 运行器准备"
    echo "  4. 执行推理"
    echo ""
    
    check_environment
    
    START_TIME=$(date +%s)
    
    compile_to_ir
    compile_to_binary
    run_inference
    
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    
    print_header "✅ 推理流程完成"
    echo "总耗时: ${ELAPSED}s"
    echo "日志文件: $LOG_FILE"
    echo ""
}

# =====================================================================
# 错误处理
# =====================================================================

trap 'print_error "推理流程被中断"; exit 1' INT TERM

# =====================================================================
# 执行主程序
# =====================================================================

main "$@"
