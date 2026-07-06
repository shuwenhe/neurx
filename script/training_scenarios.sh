#!/bin/bash

# ============================================================================
# NeurX LLM 训练场景脚本模板
# 快速开始各种训练场景，直接复制粘贴即可运行
# ============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# 打印函数
# ============================================================================

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} $1"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# ============================================================================
# 检查依赖
# ============================================================================

check_dependencies() {
    print_header "检查依赖"
    echo ""
    
    # 检查 make
    if ! command -v make &> /dev/null; then
        print_warning "make not found, installing..."
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt-get install -y make
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            brew install make
        fi
    fi
    print_success "make available"
    
    # 检查 GPU
    if ! command -v nvidia-smi &> /dev/null; then
        print_warning "nvidia-smi not found (GPU may not be available)"
    else
        print_success "NVIDIA GPU detected"
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    fi
    echo ""
}

# ============================================================================
# 训练场景
# ============================================================================

scenario_quick_test() {
    print_header "场景 1: 快速测试 (5 分钟)"
    echo ""
    echo "此场景用于快速验证环境设置"
    echo ""
    echo -e "${YELLOW}配置:${NC}"
    echo "  - 步数: 10"
    echo "  - 批大小: 1"
    echo "  - 序列长度: 8"
    echo ""
    
    read -p "是否运行此场景? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "开始快速测试..."
        make train-llm \
            NEURX_TOTAL_STEPS=10 \
            NEURX_BATCH_SIZE=1 \
            NEURX_SEQ_LENGTH=8
        print_success "快速测试完成！"
    fi
    echo ""
}

scenario_model_validation() {
    print_header "场景 2: 模型验证 (30 分钟)"
    echo ""
    echo "此场景用于验证模型是否能正确训练"
    echo ""
    echo -e "${YELLOW}配置:${NC}"
    echo "  - 步数: 100"
    echo "  - 批大小: 4"
    echo "  - 序列长度: 128"
    echo "  - 学习率: 0.001"
    echo ""
    
    read -p "是否运行此场景? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "开始模型验证..."
        make train-llm \
            NEURX_TOTAL_STEPS=100 \
            NEURX_BATCH_SIZE=4 \
            NEURX_SEQ_LENGTH=128 \
            NEURX_LR=0.001
        print_success "模型验证完成！"
    fi
    echo ""
}

scenario_single_gpu() {
    print_header "场景 3: 单 GPU 训练 (2-4 小时)"
    echo ""
    echo "此场景用于完整的单 GPU 模型训练"
    echo ""
    echo -e "${YELLOW}配置:${NC}"
    echo "  - 步数: 1000"
    echo "  - 批大小: 16"
    echo "  - 序列长度: 512"
    echo "  - 学习率: 0.0001"
    echo "  - 混合精度: BF16"
    echo ""
    
    read -p "是否运行此场景? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "开始单 GPU 训练..."
        make train-llm \
            NEURX_TOTAL_STEPS=1000 \
            NEURX_BATCH_SIZE=16 \
            NEURX_SEQ_LENGTH=512 \
            NEURX_LR=0.0001 \
            NEURX_WARMUP_STEPS=50 \
            NEURX_MIXED_PRECISION_MODE=bf16
        print_success "单 GPU 训练完成！"
    fi
    echo ""
}

scenario_multi_gpu_dp() {
    print_header "场景 4: 多 GPU 数据并行 (1-2 天)"
    echo ""
    echo "此场景用于多 GPU 数据并行训练"
    echo ""
    echo -e "${YELLOW}配置:${NC}"
    echo "  - GPU 数: 4"
    echo "  - 步数: 5000"
    echo "  - 批大小: 32"
    echo "  - 序列长度: 2048"
    echo "  - 混合精度: BF16"
    echo ""
    
    read -p "是否运行此场景? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "开始多 GPU 数据并行训练..."
        make train-dp \
            NEURX_WORLD_SIZE=4 \
            NEURX_DATA_PARALLEL_SIZE=4 \
            NEURX_TOTAL_STEPS=5000 \
            NEURX_BATCH_SIZE=32 \
            NEURX_SEQ_LENGTH=2048 \
            NEURX_LR=0.00005 \
            NEURX_WARMUP_STEPS=100 \
            NEURX_MIXED_PRECISION_MODE=bf16
        print_success "多 GPU 数据并行训练完成！"
    fi
    echo ""
}

scenario_tensor_parallel() {
    print_header "场景 5: 张量并行 (大模型) (多天)"
    echo ""
    echo "此场景用于大模型张量并行训练"
    echo ""
    echo -e "${YELLOW}配置:${NC}"
    echo "  - 总 GPU: 8"
    echo "  - 张量并行: 8 (分割权重)"
    echo "  - 批大小: 16"
    echo "  - 序列长度: 4096"
    echo ""
    
    read -p "是否运行此场景? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "开始张量并行训练..."
        make train-llm \
            NEURX_WORLD_SIZE=8 \
            NEURX_TENSOR_PARALLEL_SIZE=8 \
            NEURX_DATA_PARALLEL_SIZE=1 \
            NEURX_TOTAL_STEPS=10000 \
            NEURX_BATCH_SIZE=16 \
            NEURX_SEQ_LENGTH=4096 \
            NEURX_LR=0.00005 \
            NEURX_MIXED_PRECISION_MODE=bf16
        print_success "张量并行训练完成！"
    fi
    echo ""
}

scenario_claude_scale() {
    print_header "场景 6: NeurX frontier 训练 (70B+) (数周)"
    echo ""
    echo "此场景用于大规模 NeurX frontier 模型训练"
    echo ""
    echo -e "${YELLOW}配置:${NC}"
    echo "  - 总 GPU: 32"
    echo "  - 数据并行: 2"
    echo "  - 张量并行: 8"
    echo "  - 管道并行: 2"
    echo "  - 批大小: 32"
    echo "  - 序列长度: 8192"
    echo ""
    
    read -p "是否运行此场景? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "开始 NeurX frontier 训练..."
        make train-llm \
            NEURX_WORLD_SIZE=32 \
            NEURX_DATA_PARALLEL_SIZE=2 \
            NEURX_TENSOR_PARALLEL_SIZE=8 \
            NEURX_PIPELINE_PARALLEL_SIZE=2 \
            NEURX_TOTAL_STEPS=100000 \
            NEURX_BATCH_SIZE=32 \
            NEURX_SEQ_LENGTH=8192 \
            NEURX_LR=0.00005 \
            NEURX_WARMUP_STEPS=500 \
            NEURX_MIXED_PRECISION_MODE=bf16 \
            NEURX_CHECKPOINT_INTERVAL=100
        print_success "NeurX frontier 训练完成！"
    fi
    echo ""
}

scenario_inference() {
    print_header "场景 7: 模型推理"
    echo ""
    echo "此场景用于运行已训练模型的推理"
    echo ""
    
    read -p "选择推理方式: (1)基础推理 (2)实时日志 (3)交互式 " -n 1 -r
    echo
    case $REPLY in
        1)
            print_info "运行基础推理..."
            make infer
            ;;
        2)
            print_info "运行推理 + 实时日志..."
            make infer-watch
            ;;
        3)
            print_info "运行交互式推理..."
            make infer-interactive
            ;;
        *)
            print_warning "无效选择"
            ;;
    esac
    echo ""
}

# ============================================================================
# 主菜单
# ============================================================================

main() {
    print_header "NeurX LLM 训练场景选择器"
    echo ""
    
    # 检查依赖
    check_dependencies
    
    while true; do
        print_header "选择训练场景"
        echo ""
        echo "  1. 快速测试 (5 分钟)"
        echo "  2. 模型验证 (30 分钟)"
        echo "  3. 单 GPU 训练 (2-4 小时)"
        echo "  4. 多 GPU 数据并行 (1-2 天)"
        echo "  5. 张量并行 (大模型) (多天)"
        echo "  6. NeurX frontier 训练 (70B+) (数周)"
        echo "  7. 模型推理"
        echo "  0. 退出"
        echo ""
        read -p "请选择 (0-7): " choice
        
        case $choice in
            1) scenario_quick_test ;;
            2) scenario_model_validation ;;
            3) scenario_single_gpu ;;
            4) scenario_multi_gpu_dp ;;
            5) scenario_tensor_parallel ;;
            6) scenario_claude_scale ;;
            7) scenario_inference ;;
            0) 
                print_success "退出"
                exit 0
                ;;
            *)
                print_warning "无效选择，请重试"
                echo ""
                ;;
        esac
    done
}

# ============================================================================
# 运行脚本
# ============================================================================

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "NeurX LLM 训练场景脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --help, -h      显示此帮助信息"
    echo "  --quick         运行快速测试"
    echo "  --validate      运行模型验证"
    echo "  --single-gpu    运行单 GPU 训练"
    echo "  --multi-gpu     运行多 GPU 训练"
    echo "  --infer         运行推理"
    echo ""
    echo "示例:"
    echo "  $0                  # 交互式菜单"
    echo "  $0 --quick          # 快速测试"
    echo "  $0 --single-gpu     # 单 GPU 训练"
    exit 0
fi

if [ "$1" == "--quick" ]; then
    make train-llm NEURX_TOTAL_STEPS=10
    exit 0
fi

if [ "$1" == "--validate" ]; then
    make train-llm NEURX_TOTAL_STEPS=100 NEURX_BATCH_SIZE=4
    exit 0
fi

if [ "$1" == "--single-gpu" ]; then
    make train-llm \
        NEURX_TOTAL_STEPS=1000 \
        NEURX_BATCH_SIZE=16 \
        NEURX_SEQ_LENGTH=512 \
        NEURX_LR=0.0001 \
        NEURX_MIXED_PRECISION_MODE=bf16
    exit 0
fi

if [ "$1" == "--multi-gpu" ]; then
    make train-dp \
        NEURX_WORLD_SIZE=4 \
        NEURX_DATA_PARALLEL_SIZE=4 \
        NEURX_TOTAL_STEPS=5000 \
        NEURX_BATCH_SIZE=32 \
        NEURX_SEQ_LENGTH=2048 \
        NEURX_MIXED_PRECISION_MODE=bf16
    exit 0
fi

if [ "$1" == "--infer" ]; then
    make infer
    exit 0
fi

# 默认运行交互式菜单
main
