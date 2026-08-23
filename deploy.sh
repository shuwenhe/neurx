#!/bin/bash

set -e

COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
    echo -e "${COLOR_BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${COLOR_BLUE}║   NeurX 推理服务一键启动${NC}"
    echo -e "${COLOR_BLUE}╚════════════════════════════════════════╝${NC}"
}

print_step() {
    echo -e "\n${COLOR_BLUE}[步骤 $1]${NC} $2"
}

print_success() {
    echo -e "${COLOR_GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${COLOR_RED}✗${NC} $1"
}

print_info() {
    echo -e "${COLOR_YELLOW}ℹ${NC} $1"
}

# 脚本开始
print_header

NEURX_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$NEURX_HOME"

print_step 1 "检查前置条件"

# 检查 Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker 未安装"
    echo "请安装 Docker: https://docs.docker.com/engine/install/"
    exit 1
fi
print_success "Docker 已安装"

# 检查 docker-compose
if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
    print_error "docker-compose 未安装"
    echo "请安装 docker-compose（Docker 1.29+）"
    exit 1
fi
print_success "docker-compose 已安装"

# 检查模型目录
if [ ! -d "/model/Qwen2.5-0.5B-Instruct" ]; then
    print_error "模型文件不存在"
    print_info "模型应位于: /model/Qwen2.5-0.5B-Instruct/"
    echo ""
    read -p "是否现在下载模型? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_step 2 "下载模型"
        docker compose --profile download up download-model && docker compose down
        print_success "模型下载完成"
    else
        print_error "缺少模型文件，无法继续"
        exit 1
    fi
else
    print_success "模型文件已就绪"
fi

# 检查端口占用
print_step 2 "检查端口占用"
if lsof -i :8000 &>/dev/null 2>&1; then
    print_info "检测到端口 8000 被占用，尝试清理..."
    PIDS=$(lsof -t -i :8000 2>/dev/null || true)
    if [ -n "$PIDS" ]; then
        for PID in $PIDS; do
            if ! kill -0 $PID 2>/dev/null; then
                continue
            fi
            print_info "停止进程 $PID..."
            kill -9 $PID 2>/dev/null || sudo kill -9 $PID 2>/dev/null || true
        done
    fi
    sleep 2
fi
print_success "端口 8000 已就绪"

# 构建镜像
print_step 3 "构建 Docker 镜像"
if docker image inspect neurx:latest &>/dev/null; then
    print_info "镜像已存在，跳过构建"
else
    print_info "正在构建镜像（首次启动需要约 5-10 分钟）..."
    docker build -t neurx:latest . --quiet
    print_success "镜像构建完成"
fi

# 启动服务
print_step 4 "启动推理服务"

# 停止旧容器
docker compose down 2>/dev/null || true
sleep 2

# 启动服务
print_info "启动 NeurX API 服务..."
docker compose --profile api up -d neurx-api

print_info "等待服务初始化（最多 60 秒）..."
sleep 8

# 检查服务状态
print_step 5 "验证服务"
RETRIES=0
MAX_RETRIES=12

while [ $RETRIES -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8000/health &>/dev/null; then
        HEALTH=$(curl -s http://localhost:8000/health)
        print_success "服务健康检查通过"
        print_info "状态: $HEALTH"
        break
    fi
    RETRIES=$((RETRIES + 1))
    if [ $RETRIES -lt $MAX_RETRIES ]; then
        echo -ne "等待服务启动... ($(($MAX_RETRIES - $RETRIES))s 剩余)\r"
        sleep 5
    fi
done

if [ $RETRIES -eq $MAX_RETRIES ]; then
    print_error "服务启动失败，请检查日志:"
    docker logs neurx-api-server
    exit 1
fi

# 显示访问信息
print_step 6 "部署完成"
echo ""
echo -e "${COLOR_GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${COLOR_GREEN}║${NC} ${COLOR_YELLOW}NeurX 推理服务已启动！${NC}${COLOR_GREEN}                       ║${NC}"
echo -e "${COLOR_GREEN}╠════════════════════════════════════════════════════╣${NC}"
echo -e "${COLOR_GREEN}║${NC} 📍 本地访问: ${COLOR_BLUE}http://localhost:8000${NC}${COLOR_GREEN}        ║${NC}"
echo -e "${COLOR_GREEN}║${NC} 🌐 公网访问: ${COLOR_BLUE}http://8.140.241.141:8000${NC}${COLOR_GREEN}  ║${NC}"
echo -e "${COLOR_GREEN}╠════════════════════════════════════════════════════╣${NC}"
echo -e "${COLOR_GREEN}║${NC} 📊 API 端点:${NC}"
echo -e "${COLOR_GREEN}║${NC}   • 健康检查: ${COLOR_BLUE}GET /health${NC}"
echo -e "${COLOR_GREEN}║${NC}   • 聊天 API:  ${COLOR_BLUE}POST /v1/chat/completions${NC}"
echo -e "${COLOR_GREEN}╠════════════════════════════════════════════════════╣${NC}"
echo -e "${COLOR_GREEN}║${NC} 🛠️  常用命令:${NC}"
echo -e "${COLOR_GREEN}║${NC}   查看日志: ${COLOR_BLUE}docker logs neurx-api-server${NC}"
echo -e "${COLOR_GREEN}║${NC}   停止服务: ${COLOR_BLUE}docker compose down${NC}"
echo -e "${COLOR_GREEN}║${NC}   健康检查: ${COLOR_BLUE}curl http://localhost:8000/health${NC}"
echo -e "${COLOR_GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# 测试 API
print_step 7 "快速测试"
print_info "测试聊天 API..."
RESPONSE=$(curl -s -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "hello"}],
    "max_tokens": 20
  }')

if echo "$RESPONSE" | grep -q "chatcmpl"; then
    print_success "API 响应正常"
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null | head -15
else
    print_error "API 响应异常"
    echo "$RESPONSE"
fi

echo ""
echo -e "${COLOR_GREEN}✨ 部署流程完成！服务已就绪。${NC}"
