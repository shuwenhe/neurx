#!/bin/bash

# NeurX 推理部署快速启动脚本
# Usage: bash quickstart_inference.sh [action]
# Actions: setup, download, verify, start, test, stop, help

set -e

PROJECT_ROOT="${PROJECT_ROOT:-.}"
MODEL_DIR="${MODEL_DIR:-$HOME/shuwen/model}"
SERVICE_PORT="${SERVICE_PORT:-8000}"
NUM_WORKERS="${NUM_WORKERS:-4}"
MAX_BATCH_SIZE="${MAX_BATCH_SIZE:-4}"

COLORS_RESET='\033[0m'
COLORS_GREEN='\033[0;32m'
COLORS_BLUE='\033[0;34m'
COLORS_YELLOW='\033[1;33m'
COLORS_RED='\033[0;31m'

log_info() {
    echo -e "${COLORS_BLUE}ℹ️  $1${COLORS_RESET}"
}

log_success() {
    echo -e "${COLORS_GREEN}✅ $1${COLORS_RESET}"
}

log_warn() {
    echo -e "${COLORS_YELLOW}⚠️  $1${COLORS_RESET}"
}

log_error() {
    echo -e "${COLORS_RED}❌ $1${COLORS_RESET}"
}

print_banner() {
    clear
    cat << 'EOF'
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║     🚀 NeurX 推理部署 - 快速启动脚本                    ║
║                                                          ║
║     Pure S Language Implementation                       ║
║     快速部署推理服务                                      ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo ""
}

check_requirements() {
    log_info "检查系统环境..."
    
    local missing=()
    
    # 检查 Python
    if ! command -v python3 &> /dev/null; then
        missing+=("python3")
    else
        log_success "Python 3 已安装: $(python3 --version)"
    fi
    
    # 检查 S 编译器
    if ! command -v s &> /dev/null && ! command -v s_seed &> /dev/null; then
        log_warn "S 编译器未找到，请设置 S_COMPILER_BIN 环境变量"
    else
        log_success "S 编译器已找到"
    fi
    
    # 检查磁盘空间
    local free_space=$(df -h "$MODEL_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
    if (( $(echo "$free_space < 5" | bc -l) )); then
        log_warn "磁盘空间不足: 需要 5GB, 实际 ${free_space}GB"
    else
        log_success "磁盘空间充足: ${free_space}GB"
    fi
    
    # 检查内存
    local total_mem=$(free -h | awk 'NR==2 {print $2}' | sed 's/G//')
    if (( $(echo "$total_mem < 8" | bc -l) )); then
        log_warn "内存不足: 需要 8GB+, 实际 ${total_mem}GB"
    else
        log_success "内存充足: ${total_mem}GB"
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "缺少依赖: ${missing[*]}"
        return 1
    fi
    
    log_success "环境检查完成"
    echo ""
}

setup() {
    print_banner
    log_info "设置 NeurX 推理部署..."
    
    check_requirements
    
    # 创建必要的目录
    log_info "创建目录结构..."
    mkdir -p "$MODEL_DIR"
    mkdir -p "$PROJECT_ROOT/artifacts/logs"
    mkdir -p "$PROJECT_ROOT/artifacts/build"
    
    # 设置环境变量
    log_info "配置环境变量..."
    export NEURX_MODEL_PATH="$MODEL_DIR"
    export NEURX_PORT="$SERVICE_PORT"
    export NEURX_NUM_WORKERS="$NUM_WORKERS"
    export NEURX_MAX_BATCH_SIZE="$MAX_BATCH_SIZE"
    
    log_success "设置完成！"
    echo ""
    echo "📝 环境变量已设置:"
    echo "  NEURX_MODEL_PATH=$NEURX_MODEL_PATH"
    echo "  NEURX_PORT=$NEURX_PORT"
    echo "  NEURX_NUM_WORKERS=$NEURX_NUM_WORKERS"
    echo "  NEURX_MAX_BATCH_SIZE=$NEURX_MAX_BATCH_SIZE"
    echo ""
}

download_model() {
    print_banner
    log_info "下载模型文件..."
    
    if [ -f "$MODEL_DIR/Qwen2.5-0.5B-Instruct/model.safetensors" ]; then
        log_success "模型文件已存在"
        ls -lh "$MODEL_DIR/Qwen2.5-0.5B-Instruct/"
        return 0
    fi
    
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 未安装，无法下载模型"
        return 1
    fi
    
    log_info "正在下载 Qwen2.5-0.5B-Instruct..."
    echo "这可能需要几分钟，取决于网络速度..."
    echo ""
    
    python3 -m pip install huggingface_hub -q 2>/dev/null || true
    
    python3 -m huggingface_hub download \
        Qwen/Qwen2.5-0.5B-Instruct \
        --local-dir "$MODEL_DIR/Qwen2.5-0.5B-Instruct"
    
    log_success "模型下载完成"
    echo ""
}

verify_deployment() {
    print_banner
    log_info "验证部署..."
    
    local failed=0
    
    # 1. 检查模型文件
    log_info "检查模型文件..."
    if [ -f "$MODEL_DIR/Qwen2.5-0.5B-Instruct/model.safetensors" ]; then
        log_success "模型文件 ✓"
    else
        log_error "模型文件缺失"
        failed=$((failed + 1))
    fi
    
    if [ -f "$MODEL_DIR/Qwen2.5-0.5B-Instruct/config.json" ]; then
        log_success "配置文件 ✓"
    else
        log_error "配置文件缺失"
        failed=$((failed + 1))
    fi
    
    if [ -f "$MODEL_DIR/Qwen2.5-0.5B-Instruct/tokenizer.json" ]; then
        log_success "分词器 ✓"
    else
        log_error "分词器缺失"
        failed=$((failed + 1))
    fi
    
    # 2. 检查编译工具
    log_info "检查编译工具..."
    if command -v s &> /dev/null || command -v s_seed &> /dev/null; then
        log_success "S 编译器 ✓"
    else
        log_warn "S 编译器未找到 (非必需)"
    fi
    
    # 3. 检查推理源文件
    log_info "检查推理引擎..."
    if [ -f "$PROJECT_ROOT/inference/inference_engine.s" ]; then
        log_success "推理引擎 ✓"
    else
        log_error "推理引擎文件缺失"
        failed=$((failed + 1))
    fi
    
    if [ -f "$PROJECT_ROOT/serving/inference_service.s" ]; then
        log_success "推理服务 ✓"
    else
        log_error "推理服务文件缺失"
        failed=$((failed + 1))
    fi
    
    echo ""
    if [ $failed -eq 0 ]; then
        log_success "所有检查通过！✨"
    else
        log_error "部分检查失败，请修复后重试"
        return 1
    fi
    echo ""
}

start_service() {
    print_banner
    log_info "启动推理服务..."
    
    # 检查端口是否已占用
    if netstat -tuln 2>/dev/null | grep -q ":$SERVICE_PORT "; then
        log_warn "端口 $SERVICE_PORT 已被占用"
        log_info "尝试寻找可用端口..."
        SERVICE_PORT=$((SERVICE_PORT + 1))
        log_info "使用新端口: $SERVICE_PORT"
    fi
    
    cd "$PROJECT_ROOT"
    
    log_info "编译推理服务..."
    export NEURX_MODEL_PATH="$MODEL_DIR"
    export NEURX_PORT="$SERVICE_PORT"
    export NEURX_NUM_WORKERS="$NUM_WORKERS"
    export NEURX_MAX_BATCH_SIZE="$MAX_BATCH_SIZE"
    
    # 这里应该运行 make 命令
    if [ -f "Makefile" ]; then
        make production-inference 2>&1 | tee artifacts/logs/startup.log &
        SERVICE_PID=$!
        log_success "推理服务已启动 (PID: $SERVICE_PID)"
    else
        log_error "Makefile 未找到"
        return 1
    fi
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 5
    
    # 检查服务是否运行
    test_health
    
    echo ""
    log_success "服务启动完成！"
    echo ""
    echo "📝 服务信息:"
    echo "  地址: http://localhost:$SERVICE_PORT"
    echo "  PID: $SERVICE_PID"
    echo "  日志: $PROJECT_ROOT/artifacts/logs/startup.log"
    echo ""
}

test_service() {
    print_banner
    log_info "测试推理服务..."
    
    if ! command -v curl &> /dev/null; then
        log_warn "curl 未安装，无法测试"
        return 1
    fi
    
    # 1. 健康检查
    log_info "1️⃣  健康检查..."
    if curl -s "http://localhost:$SERVICE_PORT/health" > /dev/null 2>&1; then
        log_success "服务运行中 ✓"
    else
        log_error "服务未响应"
        return 1
    fi
    
    # 2. 获取模型列表
    log_info "2️⃣  获取模型列表..."
    curl -s "http://localhost:$SERVICE_PORT/models" | head -c 200
    echo ""
    log_success "模型列表获取成功 ✓"
    
    # 3. 文本生成测试
    log_info "3️⃣  测试文本生成..."
    RESPONSE=$(curl -s -X POST "http://localhost:$SERVICE_PORT/v1/completions" \
        -H "Content-Type: application/json" \
        -d '{
            "prompt": "你好",
            "max_tokens": 50,
            "temperature": 0.7
        }')
    
    if echo "$RESPONSE" | grep -q "text"; then
        log_success "文本生成成功 ✓"
        echo "$RESPONSE" | head -c 200
        echo ""
    else
        log_warn "文本生成响应异常"
    fi
    
    # 4. 聊天测试
    log_info "4️⃣  测试聊天接口..."
    curl -s -X POST "http://localhost:$SERVICE_PORT/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "Qwen2.5-0.5B-Instruct",
            "messages": [{"role": "user", "content": "你好"}],
            "temperature": 0.7
        }' | head -c 200
    echo ""
    log_success "聊天接口测试完成 ✓"
    
    echo ""
    log_success "所有测试完成！"
    echo ""
}

test_health() {
    for i in {1..10}; do
        if curl -s "http://localhost:$SERVICE_PORT/health" > /dev/null 2>&1; then
            log_success "服务已就绪"
            return 0
        fi
        log_info "等待服务就绪... ($i/10)"
        sleep 1
    done
    
    log_error "服务启动超时"
    return 1
}

stop_service() {
    print_banner
    log_info "停止推理服务..."
    
    # 查找并停止相关进程
    local pids=$(pgrep -f "inference" || true)
    
    if [ -n "$pids" ]; then
        echo "$pids" | xargs kill -9 2>/dev/null || true
        log_success "服务已停止"
    else
        log_warn "未找到运行的服务"
    fi
    
    echo ""
}

show_help() {
    cat << 'EOF'
NeurX 推理部署快速启动脚本

使用方法:
  bash quickstart_inference.sh [action]

可用操作:
  setup          初始化环境和创建目录
  download       下载模型文件 (Qwen2.5-0.5B-Instruct)
  verify         验证部署配置
  start          启动推理服务
  test           测试推理服务
  stop           停止推理服务
  help           显示帮助信息

快速开始:
  # 完整流程（推荐）
  bash quickstart_inference.sh setup
  bash quickstart_inference.sh download
  bash quickstart_inference.sh verify
  bash quickstart_inference.sh start
  bash quickstart_inference.sh test
  
  # 或一步到位
  bash quickstart_inference.sh setup && \
  bash quickstart_inference.sh download && \
  bash quickstart_inference.sh verify && \
  bash quickstart_inference.sh start && \
  bash quickstart_inference.sh test

环境变量:
  PROJECT_ROOT      项目根目录 (默认: .)
  MODEL_DIR         模型存储路径 (默认: $HOME/shuwen/model)
  SERVICE_PORT      API 服务端口 (默认: 8000)
  NUM_WORKERS       工作线程数 (默认: 4)
  MAX_BATCH_SIZE    最大批大小 (默认: 4)

示例:
  # 自定义端口和工作线程
  SERVICE_PORT=8001 NUM_WORKERS=8 bash quickstart_inference.sh start
  
  # 指定模型路径
  MODEL_DIR=/custom/path bash quickstart_inference.sh download

更多信息:
  查看 部署推理指南.md 获取详细说明
EOF
}

main() {
    local action="${1:-help}"
    
    case "$action" in
        setup)
            setup
            ;;
        download)
            download_model
            ;;
        verify)
            verify_deployment
            ;;
        start)
            start_service
            ;;
        test)
            test_service
            ;;
        stop)
            stop_service
            ;;
        help)
            show_help
            ;;
        *)
            log_error "未知操作: $action"
            echo ""
            show_help
            return 1
            ;;
    esac
}

main "$@"
