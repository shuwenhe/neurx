#!/bin/bash
# Real-time shard processing monitor
# Shows live progress of shard processing with color-coded output

set -eu

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 状态文件
LOG_FIFO="${1:-.neurx-shard-log}"
STATS_FILE=".neurx-shard-stats"

# 清理 FIFO 如果存在
rm -f "$LOG_FIFO"
mkfifo "$LOG_FIFO"

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    NeurX Shard Processing - Real-time Monitor     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}[MONITOR] Waiting for shard processing to start...${NC}"
echo ""

# 统计变量
declare -i total_shards=0
declare -i shards_done=0
declare -i total_docs=0
declare -i total_tokens=0
declare -i current_step=0
declare -i max_steps=0
current_loss=0.0
current_lr=0.0
current_shard=""
start_time=$(date +%s)

# 处理日志行
while read -r line; do
    # 提取时间戳（如果有）
    timestamp=$(date '+%H:%M:%S')
    
    # STATUS 消息
    if [[ "$line" =~ \[STATUS\] ]]; then
        # 提取状态信息
        status_msg="${line#*\[STATUS\]}"
        status_msg="${status_msg## }"
        
        if [[ "$status_msg" =~ "Starting shard processing" ]]; then
            echo -e "${GREEN}[${timestamp}] ✓${NC} Starting shard processing"
        elif [[ "$status_msg" =~ "shard" ]] && [[ "$status_msg" =~ "/" ]] && [[ "$status_msg" =~ "started:" ]]; then
            # 提取 shard 编号和路径
            shard_info=$(echo "$status_msg" | sed 's/.*shard \([0-9]*\/[0-9]*\) started: //')
            shard_num=$(echo "$status_msg" | sed 's/.*shard \([0-9]*\)\/[0-9]* .*/\1/')
            total_shards=$(echo "$status_msg" | sed 's/.*shard [0-9]*\/\([0-9]*\) .*/\1/')
            
            echo ""
            echo -e "${CYAN}[${timestamp}] ▶ Processing Shard ${BOLD}${shard_num}/${total_shards}${NC}"
            echo -e "  Path: ${shard_info}"
            current_shard="$shard_info"
        elif [[ "$status_msg" =~ "complete:" ]]; then
            # shard 完成
            shards_done=$((shards_done + 1))
            echo -e "${GREEN}[${timestamp}] ✓ Shard complete:${NC} $status_msg"
        fi
    fi
    
    # 错误消息
    if [[ "$line" =~ \[ERROR\] ]]; then
        error_msg="${line#*\[ERROR\]}"
        echo -e "${RED}[${timestamp}] ✗ ERROR:${NC}${error_msg}"
    fi
    
    # 调试消息
    if [[ "$line" =~ \[DEBUG\] ]]; then
        debug_msg="${line#*\[DEBUG\]}"
        echo -e "${YELLOW}[${timestamp}] ◆${NC}${debug_msg}"
    fi
    
    # 训练消息
    if [[ "$line" =~ \[TRAIN\] ]]; then
        train_msg="${line#*\[TRAIN\]}"
        train_msg="${train_msg## }"
        
        # 提取 step、loss、lr
        if [[ "$train_msg" =~ "Step "[0-9]* ]]; then
            current_step=$(echo "$train_msg" | sed 's/.*Step \([0-9]*\).*/\1/')
            current_loss=$(echo "$train_msg" | sed 's/.*loss=\([0-9.]*\).*/\1/')
            current_lr=$(echo "$train_msg" | sed 's/.*lr=\([0-9e.-]*\).*/\1/')
            
            echo -e "${BLUE}[${timestamp}] 📊 Step: ${BOLD}${current_step}${NC}  Loss: ${current_loss}  LR: ${current_lr}"
        fi
    fi
    
    # 完成消息
    if [[ "$line" =~ \[COMPLETE\] ]]; then
        complete_msg="${line#*\[COMPLETE\]}"
        echo -e "${GREEN}[${timestamp}] ✓ COMPLETE:${NC}${complete_msg}"
        
        # 计算耗时
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        hours=$((duration / 3600))
        minutes=$(((duration % 3600) / 60))
        seconds=$((duration % 60))
        
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║           Training Completed Successfully          ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
        echo -e "  Total time: ${hours}h ${minutes}m ${seconds}s"
    fi
    
    # 信息消息
    if [[ "$line" =~ \[INFO\] ]]; then
        info_msg="${line#*\[INFO\]}"
        echo -e "${BLUE}[${timestamp}] ℹ${NC}${info_msg}"
    fi
    
done < "$LOG_FIFO"

# 清理
rm -f "$LOG_FIFO"
