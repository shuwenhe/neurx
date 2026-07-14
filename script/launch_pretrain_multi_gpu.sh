#!/bin/bash

# ============================================
# NeurX Multi-GPU Distributed Pretraining Launcher
# 多GPU分布式预训练启动脚本
# 功能: 启动多个进程，分别在不同GPU上运行
# ============================================

set -e

# ============================================
# 配置参数
# ============================================

# GPU配置
NUM_GPUS=${1:-1}  # 默认1块GPU，可通过参数指定
MASTER_ADDR=${MASTER_ADDR:-"localhost"}
MASTER_PORT=${MASTER_PORT:-29500}

# 模型配置
CONFIG_PATH="./pretrain/pretrain_config.toml"
MODEL_PATH="./checkpoint/NeurX-1.3/NeurX-1.3.neurx"
DATASET_PATH="./dataset/pretrain/shard"

# 训练配置
MICRO_BATCH_SIZE=8
GRADIENT_ACCUM_STEPS=8
EPOCHS=1

# 日志配置
LOG_DIR="./artifacts/logs/distributed_pretrain"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/pretrain_${TIMESTAMP}.log"

# ============================================
# 创建日志目录
# ============================================

mkdir -p "${LOG_DIR}"
mkdir -p "checkpoint/NeurX-1.3"

echo "=================================="
echo "NeurX Distributed Pretraining"
echo "=================================="
echo "NUM_GPUS: $NUM_GPUS"
echo "MASTER_ADDR: $MASTER_ADDR"
echo "MASTER_PORT: $MASTER_PORT"
echo "CONFIG: $CONFIG_PATH"
echo "DATASET: $DATASET_PATH"
echo "LOG_FILE: $LOG_FILE"
echo "=================================="

# ============================================
# 验证GPU可用性
# ============================================

echo "[INFO] Checking GPU availability..."

GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader | head -1)
echo "[INFO] Total GPUs available: $GPU_COUNT"

if [ "$NUM_GPUS" -gt "$GPU_COUNT" ]; then
    echo "[ERROR] Requested $NUM_GPUS GPUs but only $GPU_COUNT available"
    exit 1
fi

# ============================================
# 启动分布式训练进程
# ============================================

echo "[INFO] Starting $NUM_GPUS training processes..."

# 使用torch.distributed.launch启动多进程
# 或使用torchrun (PyTorch 1.10+)

if command -v torchrun &> /dev/null; then
    # 方案1: 使用torchrun (推荐)
    echo "[INFO] Using torchrun for distributed training"
    
    TORCHRUN_CMD="torchrun \
        --nproc_per_node=$NUM_GPUS \
        --nnodes=1 \
        --master_addr=$MASTER_ADDR \
        --master_port=$MASTER_PORT \
        ./pretrain/distributed_pretrain_entry.s \
        --config=$CONFIG_PATH \
        --model_path=$MODEL_PATH \
        --dataset_path=$DATASET_PATH \
        --micro_batch_size=$MICRO_BATCH_SIZE \
        --gradient_accum_steps=$GRADIENT_ACCUM_STEPS \
        --epochs=$EPOCHS \
        --log_dir=$LOG_DIR"
    
    eval "$TORCHRUN_CMD" 2>&1 | tee -a "$LOG_FILE"
    
else
    # 方案2: 使用torch.distributed.launch (旧版本)
    echo "[INFO] Using torch.distributed.launch for distributed training"
    
    python -m torch.distributed.launch \
        --nproc_per_node=$NUM_GPUS \
        --nnodes=1 \
        --master_addr=$MASTER_ADDR \
        --master_port=$MASTER_PORT \
        ./pretrain/distributed_pretrain_entry.py \
        --config=$CONFIG_PATH \
        --model_path=$MODEL_PATH \
        --dataset_path=$DATASET_PATH \
        --micro_batch_size=$MICRO_BATCH_SIZE \
        --gradient_accum_steps=$GRADIENT_ACCUM_STEPS \
        --epochs=$EPOCHS \
        --log_dir=$LOG_DIR 2>&1 | tee -a "$LOG_FILE"
fi

EXIT_CODE=$?

# ============================================
# 训练完成处理
# ============================================

echo "[INFO] Training finished with exit code: $EXIT_CODE"

if [ $EXIT_CODE -eq 0 ]; then
    echo "[SUCCESS] Distributed pretraining completed successfully!"
    echo "[INFO] Model saved to: $MODEL_PATH"
    echo "[INFO] Logs saved to: $LOG_FILE"
else
    echo "[ERROR] Distributed pretraining failed with exit code: $EXIT_CODE"
    echo "[INFO] Check logs for details: $LOG_FILE"
fi

# ============================================
# 多进程启动方案（手动方式）
# ============================================

# 以下是手动启动多个进程的另一种方式
# 仅用于参考，不会自动执行

: << 'EOF'

# 手动启动方案 (如果torchrun不可用)
echo "Manual multi-process startup (reference only):"

for RANK in $(seq 0 $((NUM_GPUS-1))); do
    LOCAL_RANK=$RANK
    
    # 设置环境变量
    export RANK=$RANK
    export LOCAL_RANK=$LOCAL_RANK
    export WORLD_SIZE=$NUM_GPUS
    export MASTER_ADDR=$MASTER_ADDR
    export MASTER_PORT=$MASTER_PORT
    
    # 后台启动训练进程
    ./pretrain/distributed_pretrain_entry.s \
        --config=$CONFIG_PATH \
        --model_path=$MODEL_PATH \
        --dataset_path=$DATASET_PATH \
        --micro_batch_size=$MICRO_BATCH_SIZE \
        --gradient_accum_steps=$GRADIENT_ACCUM_STEPS \
        --epochs=$EPOCHS \
        --rank=$RANK \
        --local_rank=$LOCAL_RANK \
        --world_size=$NUM_GPUS \
        > "${LOG_DIR}/rank_${RANK}.log" 2>&1 &
done

# 等待所有进程完成
wait

EOF

exit $EXIT_CODE
