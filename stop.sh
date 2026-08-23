#!/bin/bash

set -e

COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
NC='\033[0m'

NEURX_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$NEURX_HOME"

print_success() {
    echo -e "${COLOR_GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${COLOR_RED}✗${NC} $1"
}

print_info() {
    echo -e "${COLOR_BLUE}ℹ${NC} $1"
}

echo -e "${COLOR_RED}停止 NeurX 推理服务${NC}"
echo ""

# 停止服务
print_info "停止 Docker 容器..."
docker compose down

print_success "服务已停止"

# 可选：清理镜像
read -p "是否删除 Docker 镜像? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "删除镜像..."
    docker rmi neurx:latest 2>/dev/null || true
    print_success "镜像已删除"
fi

echo -e "${COLOR_GREEN}✓ 清理完成${NC}"
