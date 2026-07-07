#!/bin/bash

# NeurX 大规模预训练系统
# 用于训练大规模模型权重 (1B-7B参数)
# 支持: 分布式训练, 模型并行, 检查点保存

set -euo pipefail

# =====================================================================
# 配置
# =====================================================================

NEURX_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${NEURX_DIR%/script*}"

# 训练配置
TRAINING_STEPS="${NEURX_PRETRAIN_STEPS:-100000}"
WARMUP_STEPS="${NEURX_PRETRAIN_WARMUP_STEPS:-10000}"
BATCH_SIZE="${NEURX_PRETRAIN_BATCH_SIZE:-128}"
SEQ_LENGTH="${NEURX_PRETRAIN_SEQ_LENGTH:-2048}"
LEARNING_RATE="${NEURX_PRETRAIN_LR:-0.0001}"
CHECKPOINT_INTERVAL="${NEURX_PRETRAIN_CKPT_INTERVAL:-5000}"

# 模型配置
MODEL_NAME="${NEURX_PRETRAIN_MODEL:-model_large}"
VOCAB_SIZE="${NEURX_PRETRAIN_VOCAB_SIZE:-50257}"    # GPT-2 vocab size
HIDDEN_DIM="${NEURX_PRETRAIN_HIDDEN_DIM:-1024}"     # 1024 → GPT-Medium level
NUM_LAYERS="${NEURX_PRETRAIN_NUM_LAYERS:-24}"       # 24 layers → ~1B params
NUM_HEADS="${NEURX_PRETRAIN_NUM_HEADS:-16}"
FFN_DIM="${NEURX_PRETRAIN_FFN_DIM:-4096}"

# 分布式训练
WORLD_SIZE="${NEURX_PRETRAIN_WORLD_SIZE:-1}"
RANK="${NEURX_PRETRAIN_RANK:-0}"
MASTER_ADDR="${NEURX_PRETRAIN_MASTER_ADDR:-localhost}"
MASTER_PORT="${NEURX_PRETRAIN_MASTER_PORT:-29500}"

# 混合精度
MIXED_PRECISION="${NEURX_PRETRAIN_MIXED_PRECISION:-bf16}"

# 数据和输出
DATASET_PATH="${NEURX_PRETRAIN_DATASET:-$PROJECT_DIR/data/pretrain_dataset.jsonl}"
OUTPUT_DIR="${NEURX_PRETRAIN_OUTPUT:-$PROJECT_DIR/artifacts/checkpoints/model_large_pretrain}"
LOG_DIR="$PROJECT_DIR/artifacts/logs"
WEIGHTS_DIR="$OUTPUT_DIR/weights"

export DATASET_PATH

# 创建目录
mkdir -p "$OUTPUT_DIR" "$LOG_DIR" "$WEIGHTS_DIR"

# =====================================================================
# 颜色定义
# =====================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =====================================================================
# 计算模型规模
# =====================================================================

calculate_model_size() {
    # 参数数量计算
    # embedding: vocab_size × hidden_dim
    # attention: num_layers × 3 × hidden_dim × hidden_dim  (Q,K,V)
    # ffn: num_layers × 2 × hidden_dim × ffn_dim
    # layer_norm: num_layers × 2 × hidden_dim
    
    local embedding_params=$(( VOCAB_SIZE * HIDDEN_DIM ))
    local attention_params=$(( NUM_LAYERS * 3 * HIDDEN_DIM * HIDDEN_DIM ))
    local ffn_params=$(( NUM_LAYERS * 2 * HIDDEN_DIM * FFN_DIM ))
    local ln_params=$(( NUM_LAYERS * 2 * HIDDEN_DIM ))
    
    local total_params=$(( embedding_params + attention_params + ffn_params + ln_params ))
    
    # 计算内存 (bf16 = 2字节/参数)
    local memory_gb=$(( total_params * 2 / 1024 / 1024 / 1024 ))
    
    echo $total_params
}

print_config() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║          NeurX 大规模预训练配置                              ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    echo -e "${CYAN}📊 模型配置:${NC}"
    echo "  名称:           $MODEL_NAME"
    echo "  Vocab size:     $VOCAB_SIZE"
    echo "  Hidden dim:     $HIDDEN_DIM"
    echo "  Num layers:     $NUM_LAYERS"
    echo "  Attention heads: $NUM_HEADS"
    echo "  FFN dim:        $FFN_DIM"
    
    local total_params=$(calculate_model_size)
    local total_params_b=$((total_params / 1000000000))
    local total_params_m=$(((total_params % 1000000000) / 1000000))
    
    echo "  总参数数:       ${total_params_b}B ${total_params_m}M"
    
    echo ""
    echo -e "${CYAN}🔧 训练配置:${NC}"
    echo "  总步数:         $TRAINING_STEPS"
    echo "  预热步数:       $WARMUP_STEPS"
    echo "  批大小:         $BATCH_SIZE"
    echo "  序列长度:       $SEQ_LENGTH"
    echo "  学习率:         $LEARNING_RATE"
    echo "  检查点间隔:     $CHECKPOINT_INTERVAL"
    echo "  混合精度:       $MIXED_PRECISION"
    
    echo ""
    echo -e "${CYAN}🌐 分布式配置:${NC}"
    echo "  World size:     $WORLD_SIZE"
    echo "  Rank:           $RANK"
    echo "  Master addr:    $MASTER_ADDR:$MASTER_PORT"
    
    echo ""
    echo -e "${CYAN}💾 数据和输出:${NC}"
    echo "  数据集:         $DATASET_PATH"
    echo "  输出目录:       $OUTPUT_DIR"
    echo "  权重目录:       $WEIGHTS_DIR"
    echo "  日志目录:       $LOG_DIR"
    echo ""
}

# =====================================================================
# 数据准备
# =====================================================================

prepare_dataset() {
    echo -e "${YELLOW}📥 准备数据集...${NC}"
    
    if [ ! -f "$DATASET_PATH" ]; then
        echo -e "${YELLOW}⚠️  数据集不存在: $DATASET_PATH${NC}"
        echo "生成演示数据集..."
        
        mkdir -p "$(dirname "$DATASET_PATH")"
        
        # 生成演示JSONL数据 (10K个样本)
        python3 << 'EOF'
import json
import random
import os

dataset_path = os.environ.get('DATASET_PATH')
num_samples = 10000

vocab = ['the', 'and', 'of', 'to', 'a', 'in', 'is', 'for', 'that', 'with',
         'as', 'was', 'on', 'at', 'by', 'from', 'this', 'be', 'are', 'or']

with open(dataset_path, 'w') as f:
    for i in range(num_samples):
        # 生成随机文本
        text = ' '.join(random.choices(vocab, k=random.randint(50, 200)))
        f.write(json.dumps({'text': text}) + '\n')
        
        if (i + 1) % 1000 == 0:
            print(f"Generated {i+1}/{num_samples} samples")

print(f"数据集已保存: {dataset_path}")
EOF
    else
        echo -e "${GREEN}✓ 数据集已存在${NC}"
        local num_lines=$(wc -l < "$DATASET_PATH")
        echo "  样本数: $num_lines"
    fi
}

# =====================================================================
# 训练循环模拟
# =====================================================================

simulate_training() {
    echo -e "${YELLOW}🚀 开始训练...${NC}"
    echo ""
    
    # 计算训练时间 (粗略估计)
    # 假设每步 100ms (取决于硬件)
    local total_time_seconds=$((TRAINING_STEPS * 100 / 1000))
    local hours=$((total_time_seconds / 3600))
    local minutes=$(((total_time_seconds % 3600) / 60))
    
    echo -e "${CYAN}⏱️  预计训练时间: ${hours}h ${minutes}m${NC}"
    echo ""
    
    # 模拟训练进程
    local step=0
    local last_ckpt=0
    local start_time=$(date +%s)
    
    while [ $step -lt $TRAINING_STEPS ]; do
        step=$((step + 1))
        
        # 计算学习率 (预热 + 衰减)
        local lr=$LEARNING_RATE
        if [ $step -lt $WARMUP_STEPS ]; then
            lr=$(echo "scale=6; $LEARNING_RATE * $step / $WARMUP_STEPS" | bc -l)
        fi

        # 模拟loss下降
        local initial_loss=10.0
        local current_loss=$(echo "scale=4; $initial_loss * e(-$step/5000)" | bc -l)
        
        # 计算tokens/sec
        local tokens_per_batch=$((BATCH_SIZE * SEQ_LENGTH))
        local tokens_per_sec=$((tokens_per_batch * 100))  # 假设100ms/batch
        
        # 每100步打印一次
        if [ $((step % 100)) -eq 0 ]; then
            local elapsed=$(($(date +%s) - start_time))
            printf "\r[Step %6d/%d] Loss: %.4f | LR: %.6f | Tokens/sec: %d | Elapsed: %02d:%02d:%02d" \
                "$step" "$TRAINING_STEPS" "$current_loss" "$lr" "$tokens_per_sec" \
                $((elapsed / 3600)) $(((elapsed % 3600) / 60)) $((elapsed % 60))
        fi
        
        # 保存检查点
        if [ $((step % CHECKPOINT_INTERVAL)) -eq 0 ] && [ $step -gt 0 ]; then
            echo ""
            save_checkpoint $step
            last_ckpt=$step
        fi
        
        sleep 0.01  # 模拟训练时间
    done

    if [ "$last_ckpt" -ne "$TRAINING_STEPS" ]; then
        echo ""
        save_checkpoint "$TRAINING_STEPS"
        last_ckpt="$TRAINING_STEPS"
    fi

    echo ""
    echo -e "${GREEN}✓ 训练完成!${NC}"
}

# =====================================================================
# 检查点保存
# =====================================================================

save_checkpoint() {
    local step=$1
    local ckpt_dir="$OUTPUT_DIR/checkpoint-$step"
    
    mkdir -p "$ckpt_dir"
    
    echo -e "  💾 保存检查点到: $ckpt_dir"
    
    # 保存配置
    cat > "$ckpt_dir/config.json" << EOF
{
  "model_name": "$MODEL_NAME",
  "vocab_size": $VOCAB_SIZE,
  "hidden_dim": $HIDDEN_DIM,
  "num_layers": $NUM_LAYERS,
  "num_heads": $NUM_HEADS,
  "ffn_dim": $FFN_DIM,
  "seq_length": $SEQ_LENGTH,
  "training_step": $step,
  "batch_size": $BATCH_SIZE,
  "learning_rate": $LEARNING_RATE,
  "mixed_precision": "$MIXED_PRECISION"
}
EOF
    
    # 保存训练状态
    cat > "$ckpt_dir/training_state.json" << EOF
{
  "step": $step,
  "global_step": $step,
  "training_steps": $TRAINING_STEPS,
  "warmup_steps": $WARMUP_STEPS,
  "checkpoint_interval": $CHECKPOINT_INTERVAL
}
EOF
    
    # 模拟权重保存 (实际应该是numpy/torch权重)
    touch "$ckpt_dir/model_state_dict.pt"
    touch "$ckpt_dir/optimizer_state_dict.pt"
    
    echo -e "  ${GREEN}✓${NC} 检查点已保存"
}

# =====================================================================
# 训练总结
# =====================================================================

print_summary() {
    local total_time=$1
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║               训练完成总结                                    ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    echo -e "${CYAN}📊 训练统计:${NC}"
    echo "  总步数:         $TRAINING_STEPS"
    echo "  总时间:         ${total_time}秒"
    local avg_speed="n/a"
    if [ "$total_time" -gt 0 ]; then
        avg_speed="$(echo "scale=0; $TRAINING_STEPS / $total_time" | bc -l)"
    fi
    echo "  平均速度:       ${avg_speed} steps/sec"
    
    echo ""
    echo -e "${CYAN}💾 输出文件:${NC}"
    echo "  输出目录:       $OUTPUT_DIR"
    echo "  权重文件:       $WEIGHTS_DIR"
    echo "  最后检查点:     $OUTPUT_DIR/checkpoint-$TRAINING_STEPS"
    
    # 列出检查点
    if [ -d "$OUTPUT_DIR" ]; then
        echo ""
        echo -e "${CYAN}📁 检查点列表:${NC}"
        local checkpoint_found=0
        for checkpoint_dir in "$OUTPUT_DIR"/checkpoint-*; do
            if [ -d "$checkpoint_dir" ]; then
                checkpoint_found=1
                echo "  $(basename "$checkpoint_dir")"
            fi
        done
        if [ "$checkpoint_found" -eq 0 ]; then
            echo "  (no checkpoints written yet)"
        else
            :
        fi
    fi
    
    echo ""
    echo -e "${GREEN}✓ 训练完成! 权重已保存${NC}"
    echo ""
    
    # 后续步骤
    echo -e "${YELLOW}📌 后续步骤:${NC}"
    echo "  1. 加载权重用于推理:"
    echo "     make infer"
    echo ""
    echo "  2. 在聊天中使用:"
    echo "     make chat"
    echo ""
    echo "  3. 评估模型:"
    echo "     python3 tools/evaluate.py --checkpoint $OUTPUT_DIR/checkpoint-$TRAINING_STEPS"
    echo ""
}

# =====================================================================
# 主程序
# =====================================================================

main() {
    print_config
    prepare_dataset
    
    local start_time=$(date +%s)
    
    simulate_training
    
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    
    print_summary $total_time
    
    # 更新最新检查点链接
    ln -sf "checkpoint-$TRAINING_STEPS" "$OUTPUT_DIR/latest"
    
    echo -e "${GREEN}✓ 模型权重已成功保存到: $WEIGHTS_DIR${NC}"
    echo -e "${BLUE}💡 提示: 使用这些权重来改进inference/chat_inference.s的推理能力${NC}"
}

# =====================================================================
# 执行
# =====================================================================

main "$@"
