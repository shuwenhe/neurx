#!/bin/bash
#SBATCH --job-name=neurx-1t-moe
#SBATCH --nodes=128
#SBATCH --gpus-per-node=8
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=12
#SBATCH --time=7-00:00:00
#SBATCH --partition=gpu
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
#SBATCH --mail-type=NONE

# neurx 1T MoE 分布式训练 SLURM 提交脚本
# 使用: sbatch neurx/script/submit_training_job.sh

set -euo pipefail

# 获取节点列表和排名信息
nodes=$(scontrol show hostname $SLURM_NODELIST)
nodes_array=($nodes)
head_node=${nodes_array[0]}
head_node_ip=$(srun --nodes=1 --ntasks=1 -w "$head_node" hostname --ip-address | head -n 1)

echo "Head node: $head_node (IP: $head_node_ip)"
echo "Nodes: $SLURM_NODELIST"
echo "Number of nodes: $SLURM_NNODES"
echo "Tasks per node: $SLURM_NTASKS_PER_NODE"
echo ""

# 设置分布式训练环境
export MASTER_ADDR=$head_node_ip
export MASTER_PORT=29500
export RANK=$SLURM_PROCID
export LOCAL_RANK=$SLURM_LOCALID
export WORLD_SIZE=$((SLURM_NNODES * SLURM_NTASKS_PER_NODE))

# neurx 配置
export NEURX_ALLOW_FULL_1T_LOCAL=1

# 计算并行维度
export DP_SIZE=8           # 8 个数据并行
export TP_SIZE=8           # 8 个张量并行
export PP_SIZE=8           # 8 个管道并行
export EP_SIZE=16          # 16 个专家并行
# Total: 8*8*8*16 = 1024 GPUs

# 路径配置
export NEURX_ROOT="/opt/neurx"
export CHECKPOINT_DIR="$NEURX_ROOT/artifacts/checkpoints"
export LOG_DIR="$NEURX_ROOT/artifacts/logs"
export DATA_DIR="$NEURX_ROOT/dataset/pretrain"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 进程 0 显示信息
if [ "$RANK" -eq 0 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 neurx 1T MoE SLURM 分布式训练启动"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "SLURM Job ID: $SLURM_JOB_ID"
    echo "SLURM Job Name: $SLURM_JOB_NAME"
    echo "Start Time: $(date)"
    echo ""
    echo "集群配置:"
    echo "  节点数:         $SLURM_NNODES"
    echo "  每节点 GPU:     $SLURM_GPUS_PER_NODE"
    echo "  总 GPU 数:      $WORLD_SIZE"
    echo "  Master:         $MASTER_ADDR:$MASTER_PORT"
    echo ""
    echo "并行配置:"
    echo "  DP×TP×PP×EP:   8×8×8×16"
    echo ""
fi

# 启动训练
cd "$NEURX_ROOT"

# 使用 srun 在所有节点启动训练
srun --nodes=$SLURM_NNODES \
     --ntasks=$WORLD_SIZE \
     --cpus-per-task=$SLURM_CPUS_PER_TASK \
     --gpus-per-task=1 \
     --gpu-bind=closest \
     bash script/cluster_launch.sh

# 作业完成
if [ "$RANK" -eq 0 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ neurx 1T MoE 训练完成"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "End Time: $(date)"
    echo ""
    echo "结果保存在:"
    echo "  检查点: $CHECKPOINT_DIR"
    echo "  日志:   $LOG_DIR"
fi

exit 0
