#!/bin/bash

# ============================================================================
# NeurX Make Commands Launcher - 大模型训练与推理交互式启动器
# ============================================================================

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_MAKEFILE="$PROJECT_DIR/Makefile"
LARGE_MAKEFILE="$PROJECT_DIR/Makefile.large_models"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ============================================================================
# 工具函数
# ============================================================================

print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} $1"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
}

print_menu() {
    echo -e "${YELLOW}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${MAGENTA}⚠${NC} $1"
}

# ============================================================================
# 检查环境
# ============================================================================

check_environment() {
    print_header "环境检查"
    echo ""
    
    cd "$PROJECT_DIR"
    
    # 检查 GPU
    if ! command -v nvidia-smi &> /dev/null; then
        print_warning "nvidia-smi not found (GPU may not be available)"
    else
        print_success "NVIDIA GPU detected"
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | head -3
        echo ""
    fi
    
    # 检查 Make
    if ! command -v make &> /dev/null; then
        print_warning "make not found"
    else
        print_success "make available"
    fi
    
    # 检查目录结构
    if [ -d "artifacts" ]; then
        print_success "artifacts directory exists"
    else
        print_info "Creating artifacts directory..."
        mkdir -p artifacts/checkpoints artifacts/logs
    fi
    echo ""
}

run_make_base() {
    make -C "$PROJECT_DIR" "$@"
}

run_make_large() {
    make -C "$PROJECT_DIR" -f "$LARGE_MAKEFILE" "$@"
}

# ============================================================================
# 训练菜单
# ============================================================================

menu_training() {
    while true; do
        print_header "训练菜单"
        echo ""
        echo -e "${CYAN}快速测试:${NC}"
        echo "  1. 快速原型 (5 min, 1 GPU)         make train-llm NEURX_TOTAL_STEPS=10"
        echo "  2. 模型验证 (30 min, 1 GPU)       make train-llm NEURX_TOTAL_STEPS=100"
        echo ""
        echo -e "${CYAN}规模化训练:${NC}"
        echo "  3. 单 GPU (2-4 h, 1 GPU)          make train-llm NEURX_TOTAL_STEPS=1000"
        echo "  4. 数据并行 (1-2 h, 4 GPU)        make train-dp"
        echo "  5. 大模型 (1-2 days, 8 GPU)       make train-large"
        echo "  6. 超大模型 (1-4 weeks, 32 GPU)   make train-xlarge"
        echo ""
        echo -e "${CYAN}并行策略:${NC}"
        echo "  7. 张量并行 (8-16 GPU)             make train-tensor"
        echo "  8. 管道并行 (16+ GPU)              make train-pipeline"
        echo "  9. 分布式训练 (多节点)             make train-dist"
        echo ""
        echo -e "${CYAN}其他:${NC}"
        echo "  10. 自定义配置                      输入参数"
        echo "  11. 返回主菜单"
        echo "  0. 退出"
        echo ""
        read -p "请选择 (0-11): " choice
        
        case $choice in
            1)
                print_info "运行快速原型..."
                make train-llm NEURX_TOTAL_STEPS=10
                ;;
            2)
                print_info "运行模型验证..."
                make train-llm NEURX_TOTAL_STEPS=100 NEURX_BATCH_SIZE=4
                ;;
            3)
                print_info "运行单 GPU 训练..."
                make train-llm \
                    NEURX_TOTAL_STEPS=1000 \
                    NEURX_BATCH_SIZE=32 \
                    NEURX_SEQ_LENGTH=512 \
                    NEURX_MIXED_PRECISION_MODE=bf16
                ;;
            4)
                print_info "运行 4 GPU 数据并行..."
                make train-dp \
                    NEURX_WORLD_SIZE=4 \
                    NEURX_DATA_PARALLEL_SIZE=4
                ;;
            5)
                print_info "运行大模型训练 (8 GPU)..."
                run_make_large train-large
                ;;
            6)
                read -p "运行超大模型训练需要 32 GPU，确认? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    print_info "运行超大模型训练..."
                    run_make_large train-xlarge
                else
                    print_warning "已取消"
                fi
                ;;
            7)
                print_info "运行张量并行训练..."
                run_make_large train-tensor
                ;;
            8)
                print_info "运行管道并行训练..."
                run_make_large train-pipeline
                ;;
            9)
                read -p "请输入节点数 (默认 4): " num_nodes
                num_nodes=${num_nodes:-4}
                read -p "请输入 Master 地址 (默认 localhost): " master_addr
                master_addr=${master_addr:-localhost}
                print_info "运行分布式训练..."
                run_make_large train-dist \
                    NEURX_NUM_NODES=$num_nodes \
                    NEURX_MASTER_ADDR=$master_addr
                ;;
            10)
                echo ""
                echo "自定义训练配置:"
                read -p "  总步数 (默认 1000): " steps
                read -p "  批大小 (默认 32): " batch_size
                read -p "  学习率 (默认 0.0001): " lr
                read -p "  序列长度 (默认 512): " seq_len
                read -p "  GPU 数 (默认 1): " gpus
                read -p "  混合精度 [bf16/fp16/fp32] (默认 bf16): " precision
                
                steps=${steps:-1000}
                batch_size=${batch_size:-32}
                lr=${lr:-0.0001}
                seq_len=${seq_len:-512}
                gpus=${gpus:-1}
                precision=${precision:-bf16}
                
                echo ""
                print_info "运行自定义训练..."
                run_make_base train-llm \
                    NEURX_TOTAL_STEPS=$steps \
                    NEURX_BATCH_SIZE=$batch_size \
                    NEURX_LR=$lr \
                    NEURX_SEQ_LENGTH=$seq_len \
                    NEURX_WORLD_SIZE=$gpus \
                    NEURX_MIXED_PRECISION_MODE=$precision
                ;;
            11)
                break
                ;;
            0)
                print_success "退出"
                exit 0
                ;;
            *)
                print_warning "无效选择"
                ;;
        esac
        
        echo ""
        read -p "按 Enter 继续..."
    done
}

# ============================================================================
# 推理菜单
# ============================================================================

menu_inference() {
    while true; do
        print_header "推理菜单"
        echo ""
        echo -e "${CYAN}推理模式:${NC}"
        echo "  1. 交互式 REPL (多轮对话)         make infer-interactive"
        echo "  2. 批量推理 (处理文件)             make infer-batch"
        echo "  3. 流式推理 (实时生成)             make infer-stream"
        echo "  4. 推理服务器 (API)                make infer-serving"
        echo ""
        echo -e "${CYAN}其他:${NC}"
        echo "  5. 自定义推理配置"
        echo "  6. 返回主菜单"
        echo "  0. 退出"
        echo ""
        read -p "请选择 (0-6): " choice
        
        case $choice in
            1)
                print_info "启动交互式推理..."
                run_make_base infer-interactive
                ;;
            2)
                print_info "运行批量推理..."
                run_make_large infer-batch
                ;;
            3)
                print_info "运行流式推理..."
                run_make_large infer-stream
                ;;
            4)
                read -p "请输入服务器端口 (默认 8000): " port
                port=${port:-8000}
                print_info "启动推理服务器 (端口 $port)..."
                run_make_large infer-serving NEURX_SERVE_PORT=$port
                ;;
            5)
                echo ""
                echo "自定义推理配置:"
                read -p "  温度 (默认 0.7): " temp
                read -p "  Top-K (默认 40): " topk
                read -p "  Top-P (默认 0.9): " topp
                read -p "  最大令牌 (默认 256): " max_tokens
                read -p "  批大小 (默认 32): " batch
                
                temp=${temp:-0.7}
                topk=${topk:-40}
                topp=${topp:-0.9}
                max_tokens=${max_tokens:-256}
                batch=${batch:-32}
                
                echo ""
                print_info "运行自定义推理..."
                run_make_large infer-batch \
                    NEURX_TEMPERATURE=$temp \
                    NEURX_TOP_K=$topk \
                    NEURX_TOP_P=$topp \
                    NEURX_MAX_TOKENS=$max_tokens \
                    NEURX_BATCH_SIZE=$batch
                ;;
            6)
                break
                ;;
            0)
                print_success "退出"
                exit 0
                ;;
            *)
                print_warning "无效选择"
                ;;
        esac
        
        echo ""
        read -p "按 Enter 继续..."
    done
}

# ============================================================================
# 监控菜单
# ============================================================================

menu_monitoring() {
    while true; do
        print_header "监控和调试"
        echo ""
        echo -e "${CYAN}监控:${NC}"
        echo "  1. 查看当前训练状态              make monitor"
        echo "  2. 列出所有日志文件              make logs"
        echo "  3. 查看最新日志 (tail -f)        tail -f /tmp/neurx_llm_train.log"
        echo ""
        echo -e "${CYAN}清理:${NC}"
        echo "  4. 清理日志文件                  make clean-logs"
        echo "  5. 清理所有产物                  make clean"
        echo ""
        echo -e "${CYAN}帮助:${NC}"
        echo "  6. 训练命令帮助                  make train-help"
        echo "  7. 推理命令帮助                  make infer-help"
        echo ""
        echo -e "${CYAN}其他:${NC}"
        echo "  8. 返回主菜单"
        echo "  0. 退出"
        echo ""
        read -p "请选择 (0-8): " choice
        
        case $choice in
            1)
                run_make_large monitor || true
                ;;
            2)
                run_make_large logs || true
                ;;
            3)
                echo "查看最新日志（Ctrl+C 退出）:"
                tail -f /tmp/neurx_llm_train.log 2>/dev/null || echo "未找到日志文件"
                ;;
            4)
                run_make_large clean-logs
                ;;
            5)
                read -p "确认清理所有产物? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    run_make_base clean
                fi
                ;;
            6)
                run_make_large train-help
                ;;
            7)
                run_make_large infer-help
                ;;
            8)
                break
                ;;
            0)
                print_success "退出"
                exit 0
                ;;
            *)
                print_warning "无效选择"
                ;;
        esac
        
        echo ""
        read -p "按 Enter 继续..."
    done
}

# ============================================================================
# 快速命令菜单
# ============================================================================

menu_quick_commands() {
    while true; do
        print_header "快速命令"
        echo ""
        echo -e "${CYAN}最常用的 5 个命令:${NC}"
        echo "  1. 快速测试 (5 min)               make train-llm NEURX_TOTAL_STEPS=10"
        echo "  2. 大模型训练 (1-2 days, 8 GPU)   make train-large"
        echo "  3. 超大模型 (1-4 weeks, 32 GPU)   make train-xlarge"
        echo "  4. 交互式推理                     make infer-interactive"
        echo "  5. 批量推理                       make infer-batch"
        echo ""
        echo -e "${CYAN}其他快速命令:${NC}"
        echo "  6. 实时查看训练日志               make train-llm-watch"
        echo "  7. 多 GPU 训练                    make train-dp"
        echo "  8. 微调                          make finetune"
        echo "  9. 性能基准测试                  make benchmark"
        echo ""
        echo -e "${CYAN}其他:${NC}"
        echo "  10. 返回主菜单"
        echo "  0. 退出"
        echo ""
        read -p "请选择 (0-10): " choice
        
        case $choice in
            1) run_make_base train-llm NEURX_TOTAL_STEPS=10 ;;
            2) run_make_large train-large ;;
            3) 
                read -p "运行超大模型需要 32 GPU，确认? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    run_make_large train-xlarge
                fi
                ;;
            4) run_make_base infer-interactive ;;
            5) run_make_large infer-batch ;;
            6) run_make_base train-llm-watch ;;
            7) run_make_base train-dp ;;
            8) run_make_large finetune ;;
            9) run_make_large benchmark ;;
            10) break ;;
            0) 
                print_success "退出"
                exit 0
                ;;
            *)
                print_warning "无效选择"
                ;;
        esac
        
        echo ""
        read -p "按 Enter 继续..."
    done
}

# ============================================================================
# 主菜单
# ============================================================================

main() {
    check_environment
    
    while true; do
        print_header "NeurX 大模型训练与推理 - Make 命令启动器"
        echo ""
        echo -e "${CYAN}主菜单:${NC}"
        echo "  1. 📚 快速命令                    最常用的 5 个命令"
        echo "  2. 🚀 训练菜单                    各种规模的训练配置"
        echo "  3. 🔮 推理菜单                    各种推理模式"
        echo "  4. 📊 监控和调试                  日志和监控工具"
        echo ""
        echo -e "${CYAN}其他:${NC}"
        echo "  5. 📖 查看完整指南                打开 LARGE_MODEL_MAKE_GUIDE.md"
        echo "  6. 🔧 检查环境                    检查 GPU 和依赖"
        echo "  0. 退出"
        echo ""
        read -p "请选择 (0-6): " choice
        
        case $choice in
            1) menu_quick_commands ;;
            2) menu_training ;;
            3) menu_inference ;;
            4) menu_monitoring ;;
            5) 
                if command -v less &> /dev/null; then
                    less LARGE_MODEL_MAKE_GUIDE.md
                else
                    cat LARGE_MODEL_MAKE_GUIDE.md | head -100
                fi
                ;;
            6) check_environment ;;
            0) 
                print_success "谢谢使用 NeurX!"
                exit 0
                ;;
            *)
                print_warning "无效选择"
                ;;
        esac
        
        echo ""
    done
}

# ============================================================================
# 入口点
# ============================================================================

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "NeurX Make Commands Launcher"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --help, -h          显示此帮助信息"
    echo "  --quick             快速训练 (10 步)"
    echo "  --large             大模型训练"
    echo "  --infer             交互式推理"
    echo "  --batch             批量推理"
    echo ""
    exit 0
fi

if [ "$1" == "--quick" ]; then
    run_make_base train-llm NEURX_TOTAL_STEPS=10
    exit 0
fi

if [ "$1" == "--large" ]; then
    run_make_large train-large
    exit 0
fi

if [ "$1" == "--infer" ]; then
    run_make_base infer-interactive
    exit 0
fi

if [ "$1" == "--batch" ]; then
    run_make_large infer-batch
    exit 0
fi

# 运行交互式菜单
main
