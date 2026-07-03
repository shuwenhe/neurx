#!/bin/bash

# ============================================================================
# NeurX Training Data Information Printer
# 打印详细的训练数据信息，显示当前加载的是哪个训练数据
# ============================================================================

set -e

NEURX_ROOT="${NEURX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# 辅助函数
print_header() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_info() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

format_size() {
    du -h "$1" 2>/dev/null | cut -f1
}

format_lines() {
    wc -l < "$1" 2>/dev/null || echo "0"
}

# 主函数
main() {
    print_header "📊 NeurX 训练数据信息统计"
    echo ""
    
    # 定义所有可能的数据路径
    SHARD_DIR="${NEURX_ROOT}/data/pretrain_dataset/shard"
    CLEANED_FILE="${NEURX_ROOT}/data/pretrain_dataset/cleaned/pretrain_data_cleaned.jsonl"
    TRAIN_FILE="${NEURX_ROOT}/data/pretrain_dataset/cleaned/train.jsonl"
    VAL_FILE="${NEURX_ROOT}/data/pretrain_dataset/cleaned/val.jsonl"
    TEST_FILE="${NEURX_ROOT}/data/pretrain_dataset/cleaned/test.jsonl"
    RAW_DIR="${NEURX_ROOT}/data/pretrain_dataset/raw"
    
    # 统计可用的数据源
    AVAILABLE_SOURCES=()
    
    print_header "1️⃣  数据源检测"
    echo ""
    
    # 检查分片数据
    if [ -d "$SHARD_DIR" ] && [ "$(ls -1 "$SHARD_DIR"/shard_*.jsonl 2>/dev/null | wc -l)" -gt 0 ]; then
        print_info "分片数据集 (Shard Dataset) - $SHARD_DIR"
        SHARD_COUNT=$(ls -1 "$SHARD_DIR"/shard_*.jsonl 2>/dev/null | wc -l)
        TOTAL_LINES=0
        for shard in "$SHARD_DIR"/shard_*.jsonl; do
            TOTAL_LINES=$((TOTAL_LINES + $(format_lines "$shard")))
        done
        echo "    分片数量: $SHARD_COUNT"
        echo "    样本总数: $TOTAL_LINES 条"
        AVAILABLE_SOURCES+=("shard:$TOTAL_LINES")
    else
        print_warning "分片数据集未找到或为空"
    fi
    
    # 检查训练集
    if [ -f "$TRAIN_FILE" ]; then
        print_info "训练集 (Train Split) - $TRAIN_FILE"
        TRAIN_LINES=$(format_lines "$TRAIN_FILE")
        TRAIN_SIZE=$(format_size "$TRAIN_FILE")
        echo "    样本数量: $TRAIN_LINES 条"
        echo "    文件大小: $TRAIN_SIZE"
        AVAILABLE_SOURCES+=("train:$TRAIN_LINES")
    else
        print_warning "训练集未找到"
    fi
    
    # 检查验证集
    if [ -f "$VAL_FILE" ]; then
        print_info "验证集 (Validation Split) - $VAL_FILE"
        VAL_LINES=$(format_lines "$VAL_FILE")
        VAL_SIZE=$(format_size "$VAL_FILE")
        echo "    样本数量: $VAL_LINES 条"
        echo "    文件大小: $VAL_SIZE"
        AVAILABLE_SOURCES+=("val:$VAL_LINES")
    else
        print_warning "验证集未找到"
    fi
    
    # 检查测试集
    if [ -f "$TEST_FILE" ]; then
        print_info "测试集 (Test Split) - $TEST_FILE"
        TEST_LINES=$(format_lines "$TEST_FILE")
        TEST_SIZE=$(format_size "$TEST_FILE")
        echo "    样本数量: $TEST_LINES 条"
        echo "    文件大小: $TEST_SIZE"
        AVAILABLE_SOURCES+=("test:$TEST_LINES")
    else
        print_warning "测试集未找到"
    fi
    
    # 检查清洁数据
    if [ -f "$CLEANED_FILE" ]; then
        print_info "清洁数据集 (Cleaned Dataset) - $CLEANED_FILE"
        CLEANED_LINES=$(format_lines "$CLEANED_FILE")
        CLEANED_SIZE=$(format_size "$CLEANED_FILE")
        echo "    样本数量: $CLEANED_LINES 条"
        echo "    文件大小: $CLEANED_SIZE"
        AVAILABLE_SOURCES+=("cleaned:$CLEANED_LINES")
    else
        print_warning "清洁数据集未找到"
    fi
    
    # 检查原始数据
    if [ -d "$RAW_DIR" ]; then
        RAW_FILES=$(ls -1 "$RAW_DIR"/*.jsonl 2>/dev/null | wc -l)
        RAW_SIZE=$(du -sh "$RAW_DIR" 2>/dev/null | cut -f1)
        if [ "$RAW_FILES" -gt 0 ]; then
            print_info "原始数据 (Raw Dataset) - $RAW_DIR"
            echo "    原始文件: $RAW_FILES 个"
            echo "    总大小: $RAW_SIZE"
            AVAILABLE_SOURCES+=("raw:$RAW_FILES")
        fi
    fi
    
    echo ""
    print_header "2️⃣  数据文件详细列表"
    echo ""
    
    # 列出分片文件
    if [ -d "$SHARD_DIR" ] && [ "$(ls -1 "$SHARD_DIR"/shard_*.jsonl 2>/dev/null | wc -l)" -gt 0 ]; then
        echo -e "${BLUE}分片文件 (Shard Files):${NC}"
        SHARD_COUNT=0
        for shard in "$SHARD_DIR"/shard_*.jsonl; do
            if [ $SHARD_COUNT -lt 10 ]; then
                SHARD_NAME=$(basename "$shard")
                SHARD_LINES=$(format_lines "$shard")
                SHARD_SIZE=$(format_size "$shard")
                printf "  [%03d] %-25s  %8d 条  %6s\n" "$SHARD_COUNT" "$SHARD_NAME" "$SHARD_LINES" "$SHARD_SIZE"
            fi
            SHARD_COUNT=$((SHARD_COUNT + 1))
        done
        if [ "$SHARD_COUNT" -gt 10 ]; then
            echo "  ... 以及 $((SHARD_COUNT - 10)) 个其他分片"
        fi
        echo ""
    fi
    
    # 列出训练/验证/测试集
    if [ -f "$TRAIN_FILE" ]; then
        echo -e "${BLUE}训练/验证/测试集文件:${NC}"
        for split_name in train val test; do
            case "$split_name" in
                train) split_file="$TRAIN_FILE" ;;
                val) split_file="$VAL_FILE" ;;
                test) split_file="$TEST_FILE" ;;
            esac
            if [ -f "$split_file" ]; then
                SPLIT_NAME=$(basename "$split_file")
                SPLIT_LINES=$(format_lines "$split_file")
                SPLIT_SIZE=$(format_size "$split_file")
                printf "  %-25s  %8d 条  %6s\n" "$SPLIT_NAME" "$SPLIT_LINES" "$SPLIT_SIZE"
            fi
        done
        echo ""
    fi
    
    # 列出原始数据
    if [ -d "$RAW_DIR" ]; then
        RAW_FILES=$(ls -1 "$RAW_DIR"/*.jsonl 2>/dev/null)
        if [ -n "$RAW_FILES" ]; then
            echo -e "${BLUE}原始数据文件 (Raw Files):${NC}"
            RAW_COUNT=0
            for raw_file in $RAW_FILES; do
                if [ $RAW_COUNT -lt 10 ]; then
                    RAW_NAME=$(basename "$raw_file")
                    RAW_LINES=$(format_lines "$raw_file")
                    RAW_SIZE=$(format_size "$raw_file")
                    printf "  %-40s  %8d 条  %6s\n" "$RAW_NAME" "$RAW_LINES" "$RAW_SIZE"
                fi
                RAW_COUNT=$((RAW_COUNT + 1))
            done
            if [ "$RAW_COUNT" -gt 10 ]; then
                echo "  ... 以及 $((RAW_COUNT - 10)) 个其他文件"
            fi
            echo ""
        fi
    fi
    
    print_header "3️⃣  训练优先级和数据源选择"
    echo ""
    echo -e "${BLUE}训练数据加载优先级:${NC}"
    echo "  [1] 分片数据集 (Shard Dataset) - $SHARD_DIR"
    echo "  [2] 训练集切分 (Train Split) - $TRAIN_FILE"
    echo "  [3] 清洁数据集 (Cleaned Dataset) - $CLEANED_FILE"
    echo "  [4] 原始数据 (Raw Dataset) - $RAW_DIR"
    echo ""
    
    # 确定将使用哪个数据源
    SELECTED_SOURCE="NONE"
    if [ -d "$SHARD_DIR" ] && [ "$(ls -1 "$SHARD_DIR"/shard_*.jsonl 2>/dev/null | wc -l)" -gt 0 ]; then
        SELECTED_SOURCE="分片数据集 (Shard Dataset)"
    elif [ -f "$TRAIN_FILE" ]; then
        SELECTED_SOURCE="训练集切分 (Train Split)"
    elif [ -f "$CLEANED_FILE" ]; then
        SELECTED_SOURCE="清洁数据集 (Cleaned Dataset)"
    elif [ -d "$RAW_DIR" ]; then
        SELECTED_SOURCE="原始数据 (Raw Dataset)"
    fi
    
    print_header "4️⃣  最终选择"
    echo ""
    if [ "$SELECTED_SOURCE" = "NONE" ]; then
        print_error "未找到任何可用的训练数据!"
        echo ""
        echo "请确保已执行:"
        echo "  1. make train (自动执行清洁和分片)"
        echo "  或"
        echo "  2. bash clean_data.sh && bash generate_shards.sh"
    else
        print_info "将使用: $SELECTED_SOURCE"
        echo ""
        echo "这意味着:"
        echo "  - 训练时将从此数据源加载数据"
        echo "  - 所有训练步骤都会使用此路径的数据"
        echo "  - 日志文件会记录具体加载的文件名"
    fi
    
    echo ""
    print_header "📝 日志和输出"
    echo ""
    echo "训练日志将写入:"
    echo "  📁 ${NEURX_ROOT}/artifacts/logs/"
    echo ""
    echo "检查点将保存至:"
    echo "  📁 ${NEURX_ROOT}/artifacts/checkpoints/"
    echo ""
    echo "运行训练命令:"
    echo "  ${CYAN}make train${NC}"
    echo ""
}

main "$@"
