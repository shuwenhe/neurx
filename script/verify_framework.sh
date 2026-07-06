#!/bin/bash
# neurx 1T MoE 快速验证脚本

set -euo pipefail

NEURX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ neurx 1T MoE 训练框架完整性验证"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 计数
FOUND=0
MISSING=0

# 核心模块验证
echo "🔍 核心模块检查:"
for module in \
    "distributed/moe_all_to_all.s" \
    "distributed/tensor_parallel.s" \
    "distributed/zero_gradient_reduce.s" \
    "model/llm/model_moe_1t_loss.s" \
    "training/lr_scheduler_moe_1t.s" \
    "data/moe_1t_jsonl_loader.s" \
    "monitoring/moe_1t_metrics.s" \
    "model/llm/long_context_32k.s"; do
    if [ -f "$NEURX_ROOT/$module" ]; then
        lines=$(wc -l < "$NEURX_ROOT/$module")
        echo "  ✓ $module ($lines 行)"
        FOUND=$((FOUND + 1))
    else
        echo "  ✗ $module 缺失"
        MISSING=$((MISSING + 1))
    fi
done

echo ""
echo "📋 配置文件检查:"
for config in \
    "production_deployment/training_startup.env" \
    "production_deployment/launch_plan.sh" \
    "script/run_model_large_pretrain.sh"; do
    if [ -f "$NEURX_ROOT/$config" ]; then
        size=$(wc -l < "$NEURX_ROOT/$config")
        echo "  ✓ $config ($size 行)"
        FOUND=$((FOUND + 1))
    else
        echo "  ✗ $config 缺失"
        MISSING=$((MISSING + 1))
    fi
done

echo ""
echo "📚 文档检查:"
for doc in \
    "IMPLEMENTATION_SUMMARY.md" \
    "QUICK_REFERENCE.md" \
    "docs/INTEGRATION_GUIDE.md"; do
    if [ -f "$NEURX_ROOT/$doc" ]; then
        size=$(wc -l < "$NEURX_ROOT/$doc")
        echo "  ✓ $doc ($size 行)"
        FOUND=$((FOUND + 1))
    else
        echo "  ✗ $doc 缺失"
        MISSING=$((MISSING + 1))
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 代码统计:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 统计总行数
total_s=$(find "$NEURX_ROOT"/distributed "$NEURX_ROOT"/model/llm "$NEURX_ROOT"/training "$NEURX_ROOT"/data "$NEURX_ROOT"/monitoring -name "*.s" -type f 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
total_md=$(find "$NEURX_ROOT" -maxdepth 1 -name "*.md" -type f 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
total_docs=$(find "$NEURX_ROOT"/docs -name "*.md" -type f 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")

echo "核心模块 (.s 文件):        ${total_s:-0} 行"
echo "主文档 (.md 文件):         ${total_md:-0} 行"
echo "文档子目录:                ${total_docs:-0} 行"

echo ""
echo "✅ 验证完成:"
echo "  找到:  $FOUND 个文件/模块"
if [ $MISSING -gt 0 ]; then
    echo "  缺失:  $MISSING 个文件/模块"
    exit 1
else
    echo "  缺失:  0 个文件/模块"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚙️  关键配置:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f "$NEURX_ROOT/production_deployment/training_startup.env" ]; then
    echo "模型规模:"
    grep "NEURX_MODEL_NAME\|NEURX_MODEL_PARAMETER_COUNT_M" "$NEURX_ROOT/production_deployment/training_startup.env" | sed 's/^/  /'
    echo ""
    echo "分布式策略:"
    grep "NEURX_TENSOR_PARALLEL_SIZE\|NEURX_PIPELINE_PARALLEL_SIZE\|NEURX_MOE_EXPERT_PARALLEL_SIZE\|NEURX_ZERO_STAGE" "$NEURX_ROOT/production_deployment/training_startup.env" | sed 's/^/  /'
    echo ""
    echo "训练超参数:"
    grep "NEURX_PRETRAIN_LR\|NEURX_PRETRAIN_WARMUP_STEPS\|NEURX_PRETRAIN_STEPS\|NEURX_PRETRAIN_SEQ_LEN" "$NEURX_ROOT/production_deployment/training_startup.env" | sed 's/^/  /'
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 下一步:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1️⃣  查看快速参考: less QUICK_REFERENCE.md"
echo "2️⃣  阅读集成指南: less docs/INTEGRATION_GUIDE.md"
echo "3️⃣  启动训练:     make train"
echo "4️⃣  监控日志:     tail -f artifacts/logs/*.log"
echo ""

exit 0
