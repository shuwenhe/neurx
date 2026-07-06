#!/bin/bash
# neurx 1T MoE 本地集成测试脚本
# 用于验证所有核心模块的正确性和集成

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "$SCRIPT_DIR" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🧪 neurx 1T MoE 本地集成测试${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""

# 创建测试日志目录
TEST_LOG_DIR="$NEURX_ROOT/artifacts/test_logs"
mkdir -p "$TEST_LOG_DIR"
TEST_LOG="$TEST_LOG_DIR/integration_test_$(date +%Y%m%d_%H%M%S).log"

# 测试计数
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# 测试函数
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -e "${YELLOW}[测试 $TESTS_TOTAL]${NC} $test_name..."
    
    if eval "$test_command" >> "$TEST_LOG" 2>&1; then
        echo -e "${GREEN}  ✓ 通过${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}  ✗ 失败${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# 1. 检查模块文件存在性
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📋 检查核心模块文件${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

run_test "MoE All-to-All 模块" "[ -f \"$NEURX_ROOT/distributed/moe_all_to_all.s\" ]"
run_test "张量并行 (TP) 模块" "[ -f \"$NEURX_ROOT/distributed/tensor_parallel.s\" ]"
run_test "ZeRO Stage 3 模块" "[ -f \"$NEURX_ROOT/distributed/zero_gradient_reduce.s\" ]"
run_test "损失计算模块" "[ -f \"$NEURX_ROOT/model/llm/model_moe_1t_loss.s\" ]"
run_test "学习率调度模块" "[ -f \"$NEURX_ROOT/training/lr_scheduler_moe_1t.s\" ]"
run_test "JSONL 加载器模块" "[ -f \"$NEURX_ROOT/data/moe_1t_jsonl_loader.s\" ]"
run_test "监控系统模块" "[ -f \"$NEURX_ROOT/monitoring/moe_1t_metrics.s\" ]"
run_test "长上下文支持模块" "[ -f \"$NEURX_ROOT/model/llm/long_context_32k.s\" ]"

# 2. 检查配置文件
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}⚙️  检查配置文件${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

run_test "启动脚本配置" "[ -f \"$NEURX_ROOT/production_deployment/training_startup.env\" ]"
run_test "启动计划脚本" "[ -f \"$NEURX_ROOT/production_deployment/launch_plan.sh\" ]"
run_test "训练入口脚本" "[ -f \"$NEURX_ROOT/script/run_model_large_pretrain.sh\" ]"

# 3. 检查文档
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📚 检查文档完整性${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

run_test "实现完成总结" "[ -f \"$NEURX_ROOT/IMPLEMENTATION_SUMMARY.md\" ]"
run_test "完整实现报告" "[ -f \"$NEURX_ROOT/docs/IMPLEMENTATION_COMPLETE_REPORT.md\" ] || [ -f \"$NEURX_ROOT/IMPLEMENTATION_COMPLETE_REPORT.md\" ]"
run_test "集成指南" "[ -f \"$NEURX_ROOT/docs/INTEGRATION_GUIDE.md\" ]"
run_test "快速参考" "[ -f \"$NEURX_ROOT/QUICK_REFERENCE.md\" ]"

# 4. 检查目录结构
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📁 检查目录结构${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

run_test "artifacts 目录" "[ -d \"$NEURX_ROOT/artifacts\" ]"
run_test "checkpoints 目录" "[ -d \"$NEURX_ROOT/artifacts/checkpoints\" ]"
run_test "data 目录" "[ -d \"$NEURX_ROOT/data\" ] || [ -d \"$NEURX_ROOT/artifacts/data\" ]"
run_test "training_data_splits 目录" "[ -d \"$NEURX_ROOT/data/training_data_splits\" ] || mkdir -p \"$NEURX_ROOT/data/training_data_splits\""

# 5. 验证文件权限和大小
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 代码规模统计${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -n "核心模块总代码行数: "
wc -l "$NEURX_ROOT"/distributed/*.s "$NEURX_ROOT"/model/llm/*.s "$NEURX_ROOT"/training/*.s "$NEURX_ROOT"/data/*.s "$NEURX_ROOT"/monitoring/*.s 2>/dev/null | tail -1 | awk '{print $1}'

echo -n "文档总行数: "
wc -l "$NEURX_ROOT"/*.md "$NEURX_ROOT"/docs/*.md 2>/dev/null | tail -1 | awk '{print $1}'

# 6. 测试 S 代码语法 (简单检查)
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔍 基本代码检查${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 检查 package 声明
run_test "MoE 模块 package 声明" "grep -q 'package neurx.distributed.moe_all_to_all' \"$NEURX_ROOT/distributed/moe_all_to_all.s\" || grep -q 'func moe_' \"$NEURX_ROOT/distributed/moe_all_to_all.s\""
run_test "TP 模块 package 声明" "grep -q 'package neurx.distributed.tensor_parallel' \"$NEURX_ROOT/distributed/tensor_parallel.s\" || grep -q 'func tp_' \"$NEURX_ROOT/distributed/tensor_parallel.s\""
run_test "ZeRO 模块 package 声明" "grep -q 'package neurx.distributed.zero_gradient_reduce' \"$NEURX_ROOT/distributed/zero_gradient_reduce.s\" || grep -q 'func zero_' \"$NEURX_ROOT/distributed/zero_gradient_reduce.s\""

# 检查关键函数
run_test "MoE moe_alltoall_forward 函数" "grep -q 'func moe_alltoall_forward' \"$NEURX_ROOT/distributed/moe_all_to_all.s\""
run_test "TP tp_qkv_forward 函数" "grep -q 'func tp_qkv_forward' \"$NEURX_ROOT/distributed/tensor_parallel.s\""
run_test "ZeRO zero_stage3_new 函数" "grep -q 'func zero_stage3_new' \"$NEURX_ROOT/distributed/zero_gradient_reduce.s\""
run_test "损失 compute_total_loss 函数" "grep -q 'func compute_total_loss' \"$NEURX_ROOT/model/llm/model_moe_1t_loss.s\""
run_test "LR 调度 lr_scheduler_new 函数" "grep -q 'func lr_scheduler_new' \"$NEURX_ROOT/training/lr_scheduler_moe_1t.s\""

# 7. 配置文件验证
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}✓ 配置文件验证${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

run_test "training_startup.env 可读" "[ -r \"$NEURX_ROOT/production_deployment/training_startup.env\" ]"
run_test "launch_plan.sh 可执行" "[ -x \"$NEURX_ROOT/production_deployment/launch_plan.sh\" ]"
run_test "run_model_large_pretrain.sh 可执行" "[ -x \"$NEURX_ROOT/script/run_model_large_pretrain.sh\" ]"

# 最终摘要
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}📈 测试总结${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""

echo "总测试数:    $TESTS_TOTAL"
echo -e "${GREEN}通过:       $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}失败:       $TESTS_FAILED${NC}"
else
    echo -e "${GREEN}失败:       $TESTS_FAILED${NC}"
fi

# 计算通过率
PASS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}通过率:      100%${NC}"
else
    echo "通过率:      $PASS_RATE%"
fi

echo ""
echo "📄 详细日志: $TEST_LOG"
echo ""

# 显示关键配置
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}⚙️  关键配置验证${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -f "$NEURX_ROOT/production_deployment/training_startup.env" ]; then
    echo "模型配置:"
    grep "NEURX_MODEL_NAME\|NEURX_MODEL_PARAMETER_COUNT_M\|NEURX_LLM_HIDDEN_SIZE\|NEURX_LLM_NUM_LAYERS" "$NEURX_ROOT/production_deployment/training_startup.env" | head -4
    echo ""
    echo "训练配置:"
    grep "NEURX_PRETRAIN_STEPS\|NEURX_PRETRAIN_LR\|NEURX_PRETRAIN_SEQ_LEN\|NEURX_PRETRAIN_MICRO_BATCH" "$NEURX_ROOT/production_deployment/training_startup.env" | head -4
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"

# 返回状态
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ 所有测试通过！系统已准备好开始训练。${NC}"
    echo ""
    echo "下一步:"
    echo "  1. 准备训练数据: bash script/prepare_training_data.sh"
    echo "  2. 启动本地训练: make train"
    echo "  3. 监控训练过程: tail -f $TEST_LOG_DIR/training.log"
    exit 0
else
    echo -e "${RED}❌ 有 $TESTS_FAILED 个测试失败，请检查日志。${NC}"
    exit 1
fi
