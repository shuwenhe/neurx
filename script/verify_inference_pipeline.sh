#!/bin/bash
# NeurX 推理链路验证脚本
# Inference Pipeline Verification Script
# 验证整个推理系统是否正常工作

set -euo pipefail

# =====================================================================
# 配置
# =====================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="${SCRIPT_DIR}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# =====================================================================
# 辅助函数
# =====================================================================

print_header() {
    echo ""
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}$1${NC}"
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_test() {
    echo -e "${CYAN}【$1】${NC} $2"
}

print_pass() {
    echo -e "${GREEN}  ✓ 通过${NC}"
}

print_fail() {
    echo -e "${RED}  ✗ 失败${NC}"
}

print_warn() {
    echo -e "${YELLOW}  ⚠ 警告${NC}"
}

print_info() {
    echo -e "${MAGENTA}  ℹ 信息: $1${NC}"
}

# =====================================================================
# 测试组件
# =====================================================================

TEST_PASS=0
TEST_FAIL=0
TEST_WARN=0

add_pass() { ((TEST_PASS++)); }
add_fail() { ((TEST_FAIL++)); }
add_warn() { ((TEST_WARN++)); }

resolve_checkpoint_root() {
    local CHECKPOINT_DIR="$NEURX_ROOT/artifacts/checkpoints/llm_training"
    if [ -f "$CHECKPOINT_DIR/latest_checkpoint.txt" ]; then
        local RESOLVED
        RESOLVED="$(tr -d '[:space:]' < "$CHECKPOINT_DIR/latest_checkpoint.txt")"
        if [ -n "$RESOLVED" ]; then
            echo "$RESOLVED"
            return 0
        fi
    fi

    echo "$CHECKPOINT_DIR"
}

# =====================================================================
# 测试 1: 检查目录结构
# =====================================================================

test_directory_structure() {
    print_header "【TEST 1】 目录结构验证"
    
    local DIRS=("inference" "data" "artifacts" "data/corpus" "build")
    local ALL_EXIST=1
    
    for dir in "${DIRS[@]}"; do
        local FULL_PATH="$NEURX_ROOT/$dir"
        print_test "目录" "$FULL_PATH"
        
        if [ -d "$FULL_PATH" ]; then
            print_pass
            add_pass
        else
            print_fail
            add_fail
            ALL_EXIST=0
        fi
    done
    
    return $((1 - ALL_EXIST))
}

# =====================================================================
# 测试 2: 检查 Tokenizer 文件
# =====================================================================

test_tokenizer() {
    print_header "【TEST 2】 Tokenizer 文件验证"
    
    local TOKENIZER_DIR="$NEURX_ROOT/data/corpus"
    local VOCAB_FILE="$TOKENIZER_DIR/vocab.json"
    local MERGES_FILE="$TOKENIZER_DIR/merges.txt"
    
    print_test "文件" "$VOCAB_FILE"
    if [ -f "$VOCAB_FILE" ]; then
        print_pass
        add_pass
        local SIZE=$(wc -c < "$VOCAB_FILE" | numfmt --to=iec-i --suffix=B 2>/dev/null || echo "$(wc -c < "$VOCAB_FILE") bytes")
        print_info "文件大小: $SIZE"
    else
        print_warn
        add_warn
    fi
    
    print_test "文件" "$MERGES_FILE"
    if [ -f "$MERGES_FILE" ]; then
        print_pass
        add_pass
        local LINES=$(wc -l < "$MERGES_FILE")
        print_info "合并规则数: $LINES"
    else
        print_warn
        add_warn
    fi
}

# =====================================================================
# 测试 3: 检查 Checkpoint 文件
# =====================================================================

test_checkpoint() {
    print_header "【TEST 3】 Checkpoint 文件验证"
    
    local CHECKPOINT_DIR="$NEURX_ROOT/artifacts/checkpoints/llm_training"
    
    print_test "目录" "$CHECKPOINT_DIR"
    if [ -d "$CHECKPOINT_DIR" ]; then
        print_pass
        add_pass
        
        local PT_COUNT=$(find "$CHECKPOINT_DIR" \( -name "*.pt" -o -name "*.pth" -o -name "*.neurx" \) 2>/dev/null | wc -l)
        local META_COUNT=$(find "$CHECKPOINT_DIR" -name "latest_checkpoint.txt" 2>/dev/null | wc -l)
        local TOTAL=$((PT_COUNT + META_COUNT))
        
        if [ $TOTAL -gt 0 ]; then
            print_info "Checkpoint 文件数: $TOTAL"
            
            # 显示最新的checkpoint
            local LATEST
            LATEST="$(find "$CHECKPOINT_DIR" \( -name "*.pt" -o -name "*.pth" -o -name "*.neurx" \) 2>/dev/null | sort -r | head -1)"
            if [ -n "$LATEST" ]; then
                local SIZE=$(ls -lh "$LATEST" | awk '{print $5}')
                print_info "最新 checkpoint: $(basename "$LATEST") ($SIZE)"
            elif [ -f "$CHECKPOINT_DIR/latest_checkpoint.txt" ]; then
                print_info "最新 checkpoint 指针: latest_checkpoint.txt"
            fi
        else
            print_warn
            add_warn
            print_info "提示: 运行 'make train-llm' 生成 checkpoint"
        fi
    else
        print_warn
        add_warn
        print_info "Checkpoint 目录不存在，需要先训练模型"
    fi
}

# =====================================================================
# 测试 4: 检查 S 编译器
# =====================================================================

test_s_compiler() {
    print_header "【TEST 4】 S 编译器验证"
    
    local S_COMPILER="${S_COMPILER:-/Users/feifei/shuwen/train/s/.local/bin/s}"
    
    print_test "可执行文件" "$S_COMPILER"
    if [ -x "$S_COMPILER" ]; then
        print_pass
        add_pass
        
        local VERSION=$("$S_COMPILER" --version 2>/dev/null || echo "unknown")
        print_info "版本: $VERSION"
    else
        print_fail
        add_fail
        print_info "S编译器不可用或无执行权限"
    fi
}

# =====================================================================
# 测试 5: 检查推理源文件
# =====================================================================

test_inference_sources() {
    print_header "【TEST 5】 推理源文件验证"
    
    local FILES=(
        "$NEURX_ROOT/inference/production_inference.s"
        "$NEURX_ROOT/inference/inference_engine.s"
        "$NEURX_ROOT/inference/sampling_core.s"
    )
    
    local ALL_EXIST=1
    
    for file in "${FILES[@]}"; do
        print_test "文件" "$file"
        
        if [ -f "$file" ]; then
            print_pass
            add_pass
            local LINES=$(wc -l < "$file")
            print_info "代码行数: $LINES"
        else
            print_warn
            add_warn
            ALL_EXIST=0
        fi
    done
    
    return $((1 - ALL_EXIST))
}

# =====================================================================
# 测试 6: 检查推理脚本
# =====================================================================

test_inference_scripts() {
    print_header "【TEST 6】 推理脚本验证"
    
    local SCRIPTS=(
        "$NEURX_ROOT/run_inference_llm.sh"
        "$NEURX_ROOT/run_interactive_inference.sh"
    )
    
    local ALL_EXECUTABLE=1
    
    for script in "${SCRIPTS[@]}"; do
        print_test "脚本" "$script"
        
        if [ -x "$script" ]; then
            print_pass
            add_pass
            local SIZE=$(du -h "$script" | awk '{print $1}')
            print_info "文件大小: $SIZE"
        else
            print_fail
            add_fail
            ALL_EXECUTABLE=0
        fi
    done
    
    return $((1 - ALL_EXECUTABLE))
}

# =====================================================================
# 测试 7: 检查 Makefile 命令
# =====================================================================

test_makefile_commands() {
    print_header "【TEST 7】 Makefile 命令验证"
    
    local COMMANDS=("infer" "infer-watch" "infer-interactive")
    local MAKEFILE="$NEURX_ROOT/Makefile"
    
    local ALL_FOUND=1
    
    for cmd in "${COMMANDS[@]}"; do
        print_test "命令" "make $cmd"
        
        if grep -q "^$cmd:" "$MAKEFILE"; then
            print_pass
            add_pass
        else
            print_fail
            add_fail
            ALL_FOUND=0
        fi
    done
    
    return $((1 - ALL_FOUND))
}

# =====================================================================
# 测试 8: 检查编译输出
# =====================================================================

test_build_artifacts() {
    print_header "【TEST 8】 编译输出验证"
    
    local BUILD_DIR="$NEURX_ROOT/build/inference"
    local BUILD_INTERACTIVE_DIR="$NEURX_ROOT/build/interactive_inference"
    
    print_test "目录" "$BUILD_DIR"
    if [ -d "$BUILD_DIR" ]; then
        print_pass
        add_pass
        
        local IR_FILES=$(find "$BUILD_DIR" -name "*.ir" 2>/dev/null | wc -l)
        local BIN_FILES=$(find "$BUILD_DIR" -name "*.bin" 2>/dev/null | wc -l)
        
        if [ $IR_FILES -gt 0 ] || [ $BIN_FILES -gt 0 ]; then
            print_info "编译产物: $IR_FILES IR 文件, $BIN_FILES 二进制文件"
        else
            print_info "还未编译（首次运行会自动编译）"
        fi
    else
        print_warn
        add_warn
        print_info "build 目录还未创建（首次运行会自动创建）"
    fi
    
    print_test "目录" "$BUILD_INTERACTIVE_DIR"
    if [ -d "$BUILD_INTERACTIVE_DIR" ]; then
        print_pass
        add_pass
    else
        print_warn
        add_warn
    fi
}

# =====================================================================
# 测试 9: 检查输出目录
# =====================================================================

test_output_directories() {
    print_header "【TEST 9】 输出目录验证"
    
    local DIRS=(
        "$NEURX_ROOT/artifacts/inference_output"
        "$NEURX_ROOT/artifacts/logs"
    )
    
    local ALL_CREATED=1
    
    for dir in "${DIRS[@]}"; do
        print_test "目录" "$dir"
        
        if [ -d "$dir" ]; then
            print_pass
            add_pass
            
            local FILE_COUNT=$(find "$dir" -type f 2>/dev/null | wc -l)
            print_info "文件数: $FILE_COUNT"
        else
            mkdir -p "$dir" 2>/dev/null
            print_pass
            add_pass
            print_info "已创建目录"
        fi
    done
}

# =====================================================================
# 测试 10: 完整链路测试
# =====================================================================

test_full_pipeline() {
    print_header "【TEST 10】 完整推理链路测试"
    
    print_test "步骤 1/4" "验证必要组件"
    
    local S_COMPILER="${S_COMPILER:-/Users/feifei/shuwen/train/s/.local/bin/s}"
    local INFERENCE_SOURCE="$NEURX_ROOT/inference/production_inference.s"
    
    if [ ! -x "$S_COMPILER" ]; then
        print_fail
        add_fail
        print_info "S编译器不可用，跳过编译测试"
        return
    fi
    
    if [ ! -f "$INFERENCE_SOURCE" ]; then
        print_fail
        add_fail
        print_info "推理源文件不存在，跳过编译测试"
        return
    fi
    
    print_pass
    add_pass
    
    # 验证编译流程（检查编译器可执行性）
    print_test "步骤 2/4" "S编译器可用性检查"
    if command -v "$S_COMPILER" >/dev/null 2>&1 || [ -x "$S_COMPILER" ]; then
        print_pass
        add_pass
        print_info "S编译器已配置正确"
    else
        print_warn
        add_warn
        print_info "S编译器路径检查失败但不严重"
    fi
    
    print_test "步骤 3/4" "推理脚本可执行性"
    local INFER_SCRIPT="$NEURX_ROOT/run_inference_llm.sh"
    if [ -x "$INFER_SCRIPT" ]; then
        print_pass
        add_pass
        print_info "基础推理脚本可以执行"
    else
        print_fail
        add_fail
        print_info "基础推理脚本不可执行"
    fi
    
    print_test "步骤 4/4" "交互式推理脚本可执行性"
    local INTERACTIVE_SCRIPT="$NEURX_ROOT/run_interactive_inference.sh"
    if [ -x "$INTERACTIVE_SCRIPT" ]; then
        print_pass
        add_pass
        print_info "交互式推理REPL脚本可以执行"
    else
        print_fail
        add_fail
        print_info "交互式推理REPL脚本不可执行"
    fi

    print_test "步骤 5/5" "validate-only 推理执行"
    local CHECKPOINT_PATH
    CHECKPOINT_PATH="$(resolve_checkpoint_root)"
    if [ -d "$CHECKPOINT_PATH" ] && { [ -f "$CHECKPOINT_PATH/latest_checkpoint.txt" ] || [ -n "$(find "$CHECKPOINT_PATH" \( -name "*.pt" -o -name "*.pth" -o -name "*.neurx" \) 2>/dev/null)" ]; }; then
        local VERIFY_LOG="/tmp/neurx_verify_inference.log"
        if NEURX_INFER_VALIDATE_ONLY=1 \
            NEURX_INFER_CHECKPOINT_PATH="$CHECKPOINT_PATH" \
            NEURX_INFER_CHECKPOINT="$CHECKPOINT_PATH" \
            NEURX_INFER_DEVICE="${NEURX_INFER_DEVICE:-cpu}" \
            bash "$INFER_SCRIPT" >"$VERIFY_LOG" 2>&1; then
            print_pass
            add_pass
            print_info "验证输出: $VERIFY_LOG"
        else
            print_fail
            add_fail
            print_info "验证日志: $VERIFY_LOG"
        fi
    else
        print_warn
        add_warn
        print_info "Checkpoint 不存在，跳过 validate-only 执行"
    fi
}

# =====================================================================
# 生成报告
# =====================================================================

generate_report() {
    print_header "✅ 推理链路验证报告"
    
    local TOTAL=$((TEST_PASS + TEST_FAIL + TEST_WARN))
    
    echo -e "${BOLD}测试统计:${NC}"
    echo -e "  ${GREEN}通过: $TEST_PASS${NC}"
    echo -e "  ${RED}失败: $TEST_FAIL${NC}"
    echo -e "  ${YELLOW}警告: $TEST_WARN${NC}"
    echo -e "  ${BOLD}总计: $TOTAL${NC}"
    echo ""
    
    # 确定状态
    if [ $TEST_FAIL -eq 0 ]; then
        if [ $TEST_WARN -eq 0 ]; then
            echo -e "${GREEN}${BOLD}[✓] 所有检查通过！推理系统可以正常使用。${NC}"
        else
            echo -e "${YELLOW}${BOLD}[⚠] 大部分检查通过，但有 $TEST_WARN 项警告。${NC}"
        fi
    else
        echo -e "${RED}${BOLD}[✗] 有 $TEST_FAIL 项检查失败。${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}${BOLD}推荐的后续步骤:${NC}"
    echo ""
    
    if [ ! -d "$NEURX_ROOT/artifacts/checkpoints/llm_training" ] || [ -z "$(find "$NEURX_ROOT/artifacts/checkpoints/llm_training" \( -name "*.pt" -o -name "*.pth" -o -name "*.neurx" \) 2>/dev/null)" ]; then
        echo "  1. 生成训练检查点:"
        echo "     ${BOLD}make train-llm NEURX_TOTAL_STEPS=500${NC}"
        echo ""
    fi
    
    echo "  2. 运行基础推理:"
    echo "     ${BOLD}make infer${NC}"
    echo ""
    
    echo "  3. 运行实时监控推理:"
    echo "     ${BOLD}make infer-watch${NC}"
    echo ""
    
    echo "  4. 进入交互式推理模式:"
    echo "     ${BOLD}make infer-interactive${NC}"
    echo ""
}

# =====================================================================
# 主程序
# =====================================================================

main() {
    print_header "🔍 NeurX 推理系统链路验证"
    echo "验证时间: $(date)"
    echo "系统路径: $NEURX_ROOT"
    echo ""
    
    # 运行所有测试
    test_directory_structure || true
    test_tokenizer || true
    test_checkpoint || true
    test_s_compiler || true
    test_inference_sources || true
    test_inference_scripts || true
    test_makefile_commands || true
    test_build_artifacts || true
    test_output_directories || true
    test_full_pipeline || true
    
    # 生成报告
    generate_report
}

# =====================================================================
# 执行
# =====================================================================

main "$@"
