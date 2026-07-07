#!/bin/bash
# NeurX 训练进度监控脚本
# 监控make train的执行进度

set -euo pipefail

NEURX_HOME="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$NEURX_HOME/artifacts/logs"
CHECKPOINT_DIR="$NEURX_HOME/artifacts/checkpoints"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
}

print_status() {
    echo -e "${CYAN}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

monitor_training() {
    print_header "NeurX 训练进度监控"
    
    # 查找最新的训练日志
    LATEST_LOG=$(ls -t "$LOG_DIR"/train_*.log 2>/dev/null | head -1)
    
    if [ -z "$LATEST_LOG" ]; then
        print_error "未找到训练日志文件"
        return 1
    fi
    
    print_status "最新日志: $LATEST_LOG"
    echo ""
    
    # 显示日志文件大小和修改时间
    LOG_SIZE=$(du -h "$LATEST_LOG" | cut -f1)
    LOG_MTIME=$(date -d @$(stat -c%Y "$LATEST_LOG") '+%Y-%m-%d %H:%M:%S')
    echo "日志大小: $LOG_SIZE"
    echo "最后修改: $LOG_MTIME"
    echo ""
    
    # 检查进程状态
    print_status "检查进程..."
    
    if pgrep -f "clean_data" > /dev/null 2>&1; then
        print_success "✓ 数据清洁进程运行中"
    else
        print_warning "✗ 数据清洁进程未运行"
    fi
    
    if pgrep -f "neurx.*train" > /dev/null 2>&1; then
        print_success "✓ 训练进程运行中"
    else
        print_warning "✗ 训练进程未运行"
    fi
    
    if pgrep -f "s.*ir\|s.*build" > /dev/null 2>&1; then
        print_success "✓ S编译进程运行中"
    else
        print_warning "✗ S编译进程未运行"
    fi
    
    echo ""
    print_status "数据准备进度..."
    
    # 检查各个阶段的完成情况
    if [ -s "$NEURX_HOME/dataset/pretrain/cleaned/pretrain_data_cleaned.jsonl" ]; then
        SIZE=$(du -h "$NEURX_HOME/dataset/pretrain/cleaned/pretrain_data_cleaned.jsonl" | cut -f1)
        print_success "✓ 数据清洁: 完成 ($SIZE)"
    else
        print_warning "✗ 数据清洁: 未完成或进行中"
    fi
    
    if [ -d "$NEURX_HOME/dataset/pretrain/shard" ]; then
        SHARD_COUNT=$(ls -1 "$NEURX_HOME/dataset/pretrain/shard"/shard_*.jsonl 2>/dev/null | wc -l)
        if [ "$SHARD_COUNT" -gt 0 ]; then
            SHARD_SIZE=$(du -sh "$NEURX_HOME/dataset/pretrain/shard" 2>/dev/null | cut -f1)
            print_success "✓ 数据分片: 完成 ($SHARD_COUNT 个分片, $SHARD_SIZE)"
        else
            print_warning "✗ 数据分片: 未完成"
        fi
    fi
    
    if [ -f "$NEURX_HOME/dataset/pretrain/manifest.json" ]; then
        DOCS=$(grep -o '"total_documents": [0-9]*' "$NEURX_HOME/dataset/pretrain/manifest.json" | cut -d' ' -f2)
        print_success "✓ Manifest: 完成 ($DOCS 个文档)"
    else
        print_warning "✗ Manifest: 未生成"
    fi
    
    echo ""
    print_status "训练输出..."
    
    if [ -d "$CHECKPOINT_DIR" ]; then
        CKPT_COUNT=$(ls -1 "$CHECKPOINT_DIR" 2>/dev/null | wc -l)
        if [ "$CKPT_COUNT" -gt 0 ]; then
            print_success "✓ Checkpoints: $CKPT_COUNT 个文件"
            ls -lh "$CHECKPOINT_DIR" | head -5
        else
            print_warning "✗ Checkpoints: 尚无输出"
        fi
    else
        print_warning "✗ Checkpoints: 目录未创建"
    fi
    
    echo ""
    print_status "最新日志内容 (最后20行):"
    echo "─────────────────────────────────────────────────────────────────"
    tail -20 "$LATEST_LOG"
    echo "─────────────────────────────────────────────────────────────────"
    echo ""
    
    # 检查是否有错误
    if grep -q "error\|Error\|ERROR" "$LATEST_LOG"; then
        print_error "检测到错误日志！"
        grep "error\|Error\|ERROR" "$LATEST_LOG" | tail -5
    fi
}

# 实时监控模式
monitor_realtime() {
    LATEST_LOG=$(ls -t "$LOG_DIR"/train_*.log 2>/dev/null | head -1)
    
    if [ -z "$LATEST_LOG" ]; then
        print_error "未找到训练日志文件"
        return 1
    fi
    
    print_header "实时日志监控 - $LATEST_LOG"
    print_warning "按 Ctrl+C 停止监控（不会停止训练）"
    echo ""
    
    tail -f "$LATEST_LOG"
}

# 主菜单
show_menu() {
    echo ""
    echo -e "${BLUE}选择监控模式：${NC}"
    echo "  1) 查看当前状态"
    echo "  2) 实时监控日志"
    echo "  3) 查看错误"
    echo "  4) 重新运行训练"
    echo "  5) 退出"
    echo ""
    read -p "请选择 [1-5]: " choice
}

show_errors() {
    LATEST_LOG=$(ls -t "$LOG_DIR"/train_*.log 2>/dev/null | head -1)
    
    if [ -z "$LATEST_LOG" ]; then
        print_error "未找到日志文件"
        return
    fi
    
    print_header "错误日志"
    
    if grep -q "error\|Error\|ERROR" "$LATEST_LOG"; then
        echo "找到错误："
        grep -n "error\|Error\|ERROR" "$LATEST_LOG" | tail -20
    else
        print_success "未检测到错误"
    fi
}

# 主程序
main() {
    case "${1:-}" in
        "status")
            monitor_training
            ;;
        "realtime")
            monitor_realtime
            ;;
        "errors")
            show_errors
            ;;
        "restart")
            echo "启动训练..."
            cd "$NEURX_HOME"
            make train &
            sleep 2
            monitor_realtime
            ;;
        *)
            while true; do
                monitor_training
                echo ""
                show_menu
                
                case "$choice" in
                    1)
                        monitor_training
                        ;;
                    2)
                        monitor_realtime
                        ;;
                    3)
                        show_errors
                        ;;
                    4)
                        echo "启动训练..."
                        cd "$NEURX_HOME"
                        make train &
                        sleep 2
                        monitor_realtime
                        ;;
                    5)
                        echo "退出监控"
                        break
                        ;;
                    *)
                        print_error "无效选择"
                        ;;
                esac
                
                echo ""
                read -p "按 Enter 继续..."
            done
            ;;
    esac
}

main "$@"
