#!/bin/bash

set -e

COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'
COLOR_YELLOW='\033[1;33m'
NC='\033[0m'

NEURX_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$NEURX_HOME"

print_success() {
    echo -e "${COLOR_GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${COLOR_BLUE}ℹ${NC} $1"
}

print_header() {
    echo -e "${COLOR_YELLOW}▶${NC} $1"
}

echo -e "${COLOR_BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${COLOR_BLUE}║     NeurX 服务重启${NC}"
echo -e "${COLOR_BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# 停止服务
print_header "停止当前服务..."
docker compose down
sleep 2
print_success "服务已停止"

# 清理端口
print_header "清理端口..."
PIDS=$(lsof -t -i :8000 2>/dev/null || true)
if [ -n "$PIDS" ]; then
    for PID in $PIDS; do
        print_info "停止进程 $PID..."
        kill -9 $PID 2>/dev/null || sudo kill -9 $PID 2>/dev/null || true
    done
fi
sleep 2
print_success "端口已清理"

# 启动服务
print_header "启动服务..."
docker compose --profile api up -d neurx-api
sleep 10
print_success "服务已启动"

# 验证
print_header "验证服务..."
if curl -s http://localhost:8000/health &>/dev/null; then
    HEALTH=$(curl -s http://localhost:8000/health)
    print_success "服务健康: $HEALTH"
else
    print_info "等待服务初始化..."
    sleep 10
    HEALTH=$(curl -s http://localhost:8000/health)
    print_success "服务健康: $HEALTH"
fi

echo ""
echo -e "${COLOR_GREEN}✨ 服务已重启${NC}"
echo -e "📍 访问地址: ${COLOR_BLUE}http://localhost:8000${NC}"
