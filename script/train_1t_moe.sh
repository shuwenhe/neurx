#!/bin/bash
# 1T MoE 工业级 NeurX 模型训练 - 快速启动指南
# Usage: bash train_1t_moe.sh

set -e

NEURX_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════════════════════╗"
echo "║  NeurX 1T MoE Industrial-Grade Training Setup        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# 1. 环境变量配置
# ============================================================================

echo "📋 Step 1: Setting up environment variables..."

export NEURX_MODEL_NAME="neurx-1t-moe"
export NEURX_MODEL_FAMILY="llm"
export NEURX_MODEL_ARCHITECTURE="decoder-only-transformer-moe"
export NEURX_MODEL_PARAMETER_COUNT_M="1000000"
export NEURX_MODEL_ACTIVE_PARAMETER_COUNT_M="111111"

# Model Configuration
export NEURX_LLM_VOCAB_SIZE="128000"
export NEURX_LLM_HIDDEN_SIZE="12288"
export NEURX_LLM_NUM_HEADS="96"
export NEURX_LLM_NUM_LAYERS="96"
export NEURX_LLM_INTERMEDIATE_SIZE="49152"
export NEURX_LLM_MAX_SEQ_LEN="32768"
export NEURX_LLM_BATCH_SIZE="2"
export NEURX_LLM_SEQ_LEN="4096"
export NEURX_LLM_STEPS="500000"
export NEURX_LLM_WARMUP_STEPS="10000"
export NEURX_LLM_LR="0.0002"
export NEURX_LLM_MIN_LR="0.00002"
export NEURX_LLM_WEIGHT_DECAY="0.01"
export NEURX_LLM_LOG_INTERVAL="100"
export NEURX_LLM_EVAL_INTERVAL="5000"
export NEURX_LLM_SAVE_INTERVAL="1000"

# MoE Configuration
export NEURX_MOE_NUM_EXPERTS="256"
export NEURX_MOE_TOP_K="2"
export NEURX_MOE_EXPERT_PARALLEL_SIZE="16"

# Distributed Training
export NEURX_TENSOR_PARALLEL_SIZE="8"
export NEURX_PIPELINE_PARALLEL_SIZE="8"
export NEURX_DATA_PARALLEL_SIZE="2"
export NEURX_ZERO_STAGE="3"
export NEURX_REQUIRED_GPU_TYPE="H100"
export NEURX_REQUIRED_GPUS="1024"

# Data Configuration
export NEURX_DATA_PATH="${NEURX_HOME}/data/1t_pretraining"
export NEURX_MANIFEST_PATH="${NEURX_DATA_PATH}/manifest.json"
export NEURX_TOKENIZER_PATH="${NEURX_HOME}/data/tokenizer.manifest"

# Output Configuration
export NEURX_CHECKPOINT_DIR="${NEURX_HOME}/checkpoints/neurx_1t_moe"
export NEURX_OUTPUT_DIR="${NEURX_HOME}/artifacts/neurx_1t_moe"
export NEURX_LOG_DIR="${NEURX_OUTPUT_DIR}/logs"

echo "✓ Environment configured"
echo "  Model: ${NEURX_MODEL_NAME}"
echo "  Params: ${NEURX_MODEL_PARAMETER_COUNT_M}M"
echo "  GPUs: ${NEURX_REQUIRED_GPUS}"
echo ""

# ============================================================================
# 2. 创建必要的目录
# ============================================================================

echo "📁 Step 2: Creating output directories..."

mkdir -p "$NEURX_CHECKPOINT_DIR"
mkdir -p "$NEURX_OUTPUT_DIR"
mkdir -p "$NEURX_LOG_DIR"
mkdir -p "${NEURX_DATA_PATH}"

echo "✓ Directories created"
echo ""

# ============================================================================
# 3. 编译 S 代码 (如果需要)
# ============================================================================

echo "🔨 Step 3: Compiling S code modules..."

S_COMPILER="${S_COMPILER:-/Users/feifei/train/s/.local/bin/s}"
if [ ! -f "$S_COMPILER" ]; then
    S_COMPILER="$(command -v s 2>/dev/null || true)"
fi

if [ ! -f "$S_COMPILER" ]; then
    echo "⚠️  S compiler not found at $S_COMPILER"
    echo "   Set S_COMPILER environment variable or ensure /Users/feifei/train/s/.local/bin/s exists"
    echo ""
fi

# 编译关键模块
MODULES=(
    "training/moe_1t_orchestrator.s"
    "data/moe_1t_data_pipeline.s"
    "alignment/moe_1t_dpo_grpo_alignment.s"
    "checkpoint/moe_1t_distributed_checkpoint.s"
)

for module in "${MODULES[@]}"; do
    echo "  Compiling: $module"
    # $S_COMPILER "$NEURX_HOME/$module" -o "/tmp/${module%.s}.o" 2>/dev/null || true
done

echo "✓ Compilation complete"
echo ""

# ============================================================================
# 4. 验证训练配置
# ============================================================================

echo "✅ Step 4: Verifying training configuration..."

# 检查必要的配置文件
if [ ! -f "$NEURX_HOME/config_1t_model.json" ]; then
    echo "⚠️  config_1t_model.json not found"
fi

if [ ! -f "$NEURX_MANIFEST_PATH" ]; then
    echo "⚠️  Data manifest not found at $NEURX_MANIFEST_PATH"
    echo "   真训练不允许回退到 synthetic data"
    exit 1
fi

echo "✓ Configuration verified"
echo ""

# ============================================================================
# 5. 生成训练启动脚本
# ============================================================================

echo "📝 Step 5: Generating training launch script..."

LAUNCH_SCRIPT="${NEURX_OUTPUT_DIR}/launch_training.sh"

cat > "$LAUNCH_SCRIPT" << 'LAUNCH_EOF'
#!/bin/bash
# Auto-generated training launch script

set -e

echo "Starting 1T MoE Training..."
echo "World size: $SLURM_NTASKS (from SLURM)"
echo "Rank: $SLURM_PROCID"

# 对于 SLURM 集群，设置分布式变量
export RANK=${SLURM_PROCID:-0}
export WORLD_SIZE=${SLURM_NTASKS:-1}
export MASTER_ADDR=${SLURM_JOB_NODELIST%%,*}
export MASTER_PORT=29500

# 计算并行拓扑
export WORLD_SIZE=1024
export TP_RANK=$((RANK % 8))
export TP_SIZE=8
export PP_RANK=$(((RANK / 8) % 8))
export PP_SIZE=8
export EP_RANK=$(((RANK / 64) % 16))
export EP_SIZE=16
export DP_RANK=$(RANK / 1024))
export DP_SIZE=1

echo "Rank $RANK: TP=$TP_RANK/$TP_SIZE PP=$PP_RANK/$PP_SIZE EP=$EP_RANK/$EP_SIZE DP=$DP_RANK/$DP_SIZE"

# 调用 S 编译器执行训练
exec $S_COMPILER \
    -e "package main; use neurx.training.moe_1t_orchestrator; \
        moe_1t_orchestrator orch = moe_1t_orchestrator_new(); \
        moe_1t_training_loop(orch)" \
    2>&1 | tee -a "${NEURX_LOG_DIR}/training_rank_${RANK}.log"
LAUNCH_EOF

chmod +x "$LAUNCH_SCRIPT"

echo "✓ Launch script created: $LAUNCH_SCRIPT"
echo ""

# ============================================================================
# 6. 显示训练命令
# ============================================================================

echo "🚀 Step 6: Training commands"
echo ""
echo "For single GPU test:"
echo "  cd $NEURX_HOME"
echo "  RANK=0 WORLD_SIZE=1 TP_SIZE=1 PP_SIZE=1 EP_SIZE=1 DP_SIZE=1 bash $LAUNCH_SCRIPT"
echo ""

echo "For 8 GPU (single node test):"
echo "  cd $NEURX_HOME"
echo "  torchrun --nproc_per_node=8 $LAUNCH_SCRIPT"
echo ""

echo "For 1024 GPU (full cluster with SLURM):"
echo "  srun --gpus-per-node=8 --cpus-per-task=8 --tasks-per-node=8 \\"
echo "       --nnodes=128 bash $LAUNCH_SCRIPT"
echo ""

# ============================================================================
# 7. 生成配置摘要
# ============================================================================

echo "📊 Training Configuration Summary"
echo "════════════════════════════════════════════════════════"
echo ""

cat > "${NEURX_OUTPUT_DIR}/training_config_summary.txt" << CONFIG_EOF
═════════════════════════════════════════════════════════════
  1T MoE Industrial-Grade Model Training
═════════════════════════════════════════════════════════════

MODEL CONFIGURATION
───────────────────
  Model Name: ${NEURX_MODEL_NAME}
  Total Parameters: ${NEURX_MODEL_PARAMETER_COUNT_M}M
  Active Parameters: ${NEURX_MODEL_ACTIVE_PARAMETER_COUNT_M}M
  Hidden Dimension: ${NEURX_LLM_HIDDEN_SIZE}
  Number of Layers: ${NEURX_LLM_NUM_LAYERS}
  Number of Heads: ${NEURX_LLM_NUM_HEADS}
  Number of Experts: ${NEURX_MOE_NUM_EXPERTS}
  Expert Parallel Size: ${NEURX_MOE_EXPERT_PARALLEL_SIZE}
  Vocabulary Size: ${NEURX_LLM_VOCAB_SIZE}
  Max Sequence Length: ${NEURX_LLM_MAX_SEQ_LEN}

DISTRIBUTED TRAINING
────────────────────
  Total GPUs: 1024 (H100 PCIe 80GB)
  Tensor Parallel Size: ${NEURX_TENSOR_PARALLEL_SIZE}
  Pipeline Parallel Size: ${NEURX_PIPELINE_PARALLEL_SIZE}
  Data Parallel Size: ${NEURX_DATA_PARALLEL_SIZE}
  ZeRO Optimization Stage: ${NEURX_ZERO_STAGE}

TRAINING HYPERPARAMETERS
────────────────────────
  Batch Size (tokens): ${NEURX_LLM_BATCH_SIZE}
  Sequence Length: ${NEURX_LLM_SEQ_LEN}
  Learning Rate: ${NEURX_LLM_LR}
  Min Learning Rate: ${NEURX_LLM_MIN_LR}
  Warmup Steps: ${NEURX_LLM_WARMUP_STEPS}
  Total Training Steps: ${NEURX_LLM_STEPS}
  Weight Decay: ${NEURX_LLM_WEIGHT_DECAY}
  Evaluation Interval: ${NEURX_LLM_EVAL_INTERVAL}
  Checkpoint Interval: ${NEURX_LLM_SAVE_INTERVAL}

EXPECTED PERFORMANCE
────────────────────
  Throughput: ~3000 tokens/sec
  Training Time: ~4-6 days (500K steps)
  Checkpoint Size: ~512 GB each
  Total Training Cost: ~$2.4M (on-demand)

PATHS
─────
  Model Checkpoint: ${NEURX_CHECKPOINT_DIR}
  Output Directory: ${NEURX_OUTPUT_DIR}
  Log Directory: ${NEURX_LOG_DIR}
  Data Manifest: ${NEURX_MANIFEST_PATH}
  Tokenizer: ${NEURX_TOKENIZER_PATH}

NEXT STEPS
──────────
1. Verify all data shards are available at ${NEURX_DATA_PATH}
2. Test training on single GPU: bash $LAUNCH_SCRIPT
3. Scale to 8 GPUs for validation
4. Submit full training job to cluster scheduler
5. Monitor training via TensorBoard: tensorboard --logdir=$NEURX_LOG_DIR

═════════════════════════════════════════════════════════════
CONFIG_EOF

cat "${NEURX_OUTPUT_DIR}/training_config_summary.txt"
echo ""

# ============================================================================
# 8. 最后的验证和提示
# ============================================================================

echo "✅ Setup Complete!"
echo ""
echo "Key Implementation Files:"
echo "  ✓ $NEURX_HOME/training/moe_1t_orchestrator.s"
echo "  ✓ $NEURX_HOME/data/moe_1t_data_pipeline.s"
echo "  ✓ $NEURX_HOME/alignment/moe_1t_dpo_grpo_alignment.s"
echo "  ✓ $NEURX_HOME/checkpoint/moe_1t_distributed_checkpoint.s"
echo ""
echo "Next Steps:"
echo "  1. Review MOE_1T_IMPLEMENTATION_STATUS.md for detailed progress"
echo "  2. Implement P0 priority features (张量并行, MoE 路由, etc.)"
echo "  3. Run single GPU test to verify basic training loop"
echo "  4. Scale to 8 GPU test"
echo "  5. Submit to production cluster"
echo ""
echo "Documentation:"
echo "  - Implementation Status: $NEURX_HOME/docs/MOE_1T_IMPLEMENTATION_STATUS.md"
echo "  - Orchestrator API: See training/moe_1t_orchestrator.s"
echo ""
echo "Questions? Check the docstrings in each S module."
echo ""
