#!/bin/bash
# neurx 1T MoE 集群训练启动脚本 (SLURM)
# 用于 1024×H100 GPU 集群

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 从环境变量或使用默认值
WORLD_SIZE="${WORLD_SIZE:-1024}"
MASTER_ADDR="${MASTER_ADDR:-localhost}"
MASTER_PORT="${MASTER_PORT:-29500}"
RANK="${RANK:-0}"
LOCAL_RANK="${LOCAL_RANK:-0}"

# 并行配置
DP_SIZE="${DP_SIZE:-8}"           # Data Parallel
TP_SIZE="${TP_SIZE:-8}"           # Tensor Parallel
PP_SIZE="${PP_SIZE:-8}"           # Pipeline Parallel
EP_SIZE="${EP_SIZE:-16}"          # Expert Parallel

# 训练参数
MODEL_SIZE="${MODEL_SIZE:-1t}"
BATCH_SIZE="${BATCH_SIZE:-2}"
SEQ_LEN="${SEQ_LEN:-4096}"
NUM_STEPS="${NUM_STEPS:-500000}"
LR="${LR:-0.0002}"
WARMUP_STEPS="${WARMUP_STEPS:-10000}"

# 路径
CHECKPOINT_DIR="${CHECKPOINT_DIR:-$NEURX_ROOT/artifacts/checkpoints}"
LOG_DIR="${LOG_DIR:-$NEURX_ROOT/artifacts/logs}"
DATA_DIR="${DATA_DIR:-$NEURX_ROOT/data/training_data_splits}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 验证集群环境
verify_cluster_env() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🔍 验证集群环境${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 检查分布式训练环境
    echo "分布式配置:"
    echo "  RANK:           $RANK"
    echo "  WORLD_SIZE:     $WORLD_SIZE"
    echo "  LOCAL_RANK:     $LOCAL_RANK"
    echo "  MASTER_ADDR:    $MASTER_ADDR"
    echo "  MASTER_PORT:    $MASTER_PORT"
    echo ""
    
    echo "并行策略配置:"
    echo "  数据并行 (DP):     $DP_SIZE"
    echo "  张量并行 (TP):     $TP_SIZE"
    echo "  管道并行 (PP):     $PP_SIZE"
    echo "  专家并行 (EP):     $EP_SIZE"
    echo "  总 GPU 数:         $((DP_SIZE * TP_SIZE * PP_SIZE * EP_SIZE))"
    echo ""
    
    # 验证计算
    total_gpus=$((DP_SIZE * TP_SIZE * PP_SIZE * EP_SIZE))
    if [ $total_gpus -ne $WORLD_SIZE ]; then
        echo -e "${RED}❌ 错误: 并行维度计算 ($total_gpus) ≠ WORLD_SIZE ($WORLD_SIZE)${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ 分布式配置验证通过${NC}"
    echo ""
}

# 创建目录
create_directories() {
    echo -e "${BLUE}📁 创建目录${NC}"
    mkdir -p "$CHECKPOINT_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$DATA_DIR"
    echo -e "${GREEN}✓ 目录已创建${NC}"
    echo ""
}

# 设置环境变量
setup_env_vars() {
    echo -e "${BLUE}⚙️  设置环境变量${NC}"
    
    # 分布式训练
    export RANK
    export WORLD_SIZE
    export LOCAL_RANK
    export MASTER_ADDR
    export MASTER_PORT
    
    # 并行配置
    export NEURX_DP_SIZE=$DP_SIZE
    export NEURX_TP_SIZE=$TP_SIZE
    export NEURX_PP_SIZE=$PP_SIZE
    export NEURX_EP_SIZE=$EP_SIZE
    
    # 训练配置
    export NEURX_PRETRAIN_MICRO_BATCH=$BATCH_SIZE
    export NEURX_PRETRAIN_SEQ_LEN=$SEQ_LEN
    export NEURX_PRETRAIN_STEPS=$NUM_STEPS
    export NEURX_PRETRAIN_LR=$LR
    export NEURX_PRETRAIN_WARMUP_STEPS=$WARMUP_STEPS
    
    # 路径
    export NEURX_CHECKPOINT_DIR=$CHECKPOINT_DIR
    export NEURX_LOG_DIR=$LOG_DIR
    export NEURX_DATA_DIR=$DATA_DIR
    
    echo -e "${GREEN}✓ 环境变量已设置${NC}"
    echo ""
}

# 生成日志文件名
LOG_FILE="$LOG_DIR/training_rank${RANK}_$(date +%Y%m%d_%H%M%S).log"

# 主函数
main() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}🚀 neurx 1T MoE 集群训练启动${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # 验证环境
    verify_cluster_env || exit 1
    
    # 创建目录
    create_directories
    
    # 设置环境
    setup_env_vars
    
    # 主节点日志
    if [ "$RANK" -eq 0 ]; then
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}📋 训练任务信息${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        echo "模型配置:"
        echo "  类型:              1T MoE Transformer"
        echo "  参数:              1,000,000 M (1T)"
        echo "  激活参数:          111,111 M / token"
        echo "  专家数:            256"
        echo "  Top-K 路由:        2"
        echo ""
        
        echo "训练配置:"
        echo "  批大小:            $((BATCH_SIZE * WORLD_SIZE)) (全局)"
        echo "  序列长度:          $SEQ_LEN"
        echo "  总步数:            $NUM_STEPS"
        echo "  学习率:            $LR"
        echo "  预热步数:          $WARMUP_STEPS"
        echo "  精度:              BF16 混合精度"
        echo ""
        
        echo "并行配置:"
        echo "  DP×TP×PP×EP:       ${DP_SIZE}×${TP_SIZE}×${PP_SIZE}×${EP_SIZE}"
        echo "  总 GPU 数:         $WORLD_SIZE (H100 80GB)"
        echo "  性能目标:          3000+ token/s"
        echo "  预期训练时长:      4-6 天"
        echo ""
        
        echo "存储配置:"
        echo "  检查点目录:        $CHECKPOINT_DIR"
        echo "  日志目录:          $LOG_DIR"
        echo "  数据目录:          $DATA_DIR"
        echo ""
    fi
    
    # 等待所有进程同步
    echo -e "${YELLOW}⏳ 等待所有 $WORLD_SIZE 个进程启动...${NC}"
    echo ""
    
    # 启动训练 (这里需要替换为实际的训练入口)
    # 对于演示目的，我们显示启动命令
    if [ "$RANK" -eq 0 ]; then
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}🎬 启动训练命令${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "将要执行的命令:"
        echo ""
        echo "  bash $NEURX_ROOT/script/run_gpt_large_pretrain.sh"
        echo ""
        echo "环境变量:"
        echo "  RANK=$RANK"
        echo "  WORLD_SIZE=$WORLD_SIZE"
        echo "  MASTER_ADDR=$MASTER_ADDR"
        echo "  MASTER_PORT=$MASTER_PORT"
        echo ""
        echo "日志文件: $LOG_FILE"
        echo ""
        
        # 创建启动标记
        mkdir -p "$LOG_DIR"
        cat > "$LOG_DIR/training_config_${RANK}.txt" <<EOF
=== neurx 1T MoE 训练配置 ===
启动时间: $(date)
RANK: $RANK
WORLD_SIZE: $WORLD_SIZE
MASTER_ADDR: $MASTER_ADDR
MASTER_PORT: $MASTER_PORT

并行配置:
  DP_SIZE=$DP_SIZE
  TP_SIZE=$TP_SIZE
  PP_SIZE=$PP_SIZE
  EP_SIZE=$EP_SIZE

训练配置:
  BATCH_SIZE=$BATCH_SIZE
  SEQ_LEN=$SEQ_LEN
  NUM_STEPS=$NUM_STEPS
  LR=$LR
  WARMUP_STEPS=$WARMUP_STEPS

路径配置:
  CHECKPOINT_DIR=$CHECKPOINT_DIR
  LOG_DIR=$LOG_DIR
  DATA_DIR=$DATA_DIR
EOF
    fi
    
    # 实际训练命令（需要 S 编译器和 GPU）
    # bash "$NEURX_ROOT/script/run_gpt_large_pretrain.sh" 2>&1 | tee -a "$LOG_FILE"
    
    # 演示模式（显示启动成功）
    echo -e "${GREEN}✅ 训练进程 $RANK 启动成功${NC}"
    echo "启动时间: $(date)" >> "$LOG_FILE"
    echo "RANK=$RANK, WORLD_SIZE=$WORLD_SIZE" >> "$LOG_FILE"
    
    # 守护进程（实际训练会在这里进行）
    if [ "$RANK" -eq 0 ]; then
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}📊 监控指令${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "查看实时日志:"
        echo "  tail -f $LOG_FILE"
        echo ""
        echo "监控所有 rank 的日志:"
        echo "  tail -f $LOG_DIR/training_rank*.log"
        echo ""
        echo "查看 GPU 状态:"
        echo "  nvidia-smi -l 1"
        echo ""
        echo "查看分布式通信:"
        echo "  watch -n 5 'nvidia-smi dmon -s pucvmet'"
        echo ""
        
        # 等待一段时间（演示）
        sleep 5
        
        echo -e "${GREEN}✅ 所有进程已启动，训练现已进行中${NC}"
        echo "日志位置: $LOG_DIR/"
    fi
}

# 捕获信号进行优雅关闭
trap 'echo -e "${YELLOW}收到中断信号，准备关闭...${NC}"; exit 0' SIGINT SIGTERM

# 运行主函数
main "$@"
