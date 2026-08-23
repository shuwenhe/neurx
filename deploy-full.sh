#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} $1"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
}

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$SCRIPT_DIR/frontend"

print_header "NeurX 前后端一键部署"

print_info "开始前后端部署流程..."

echo ""
print_info "第 1/4 步: 检查环境依赖"
command -v docker >/dev/null 2>&1 || { print_error "Docker 未安装"; exit 1; }
print_status "Docker 已安装"

command -v docker-compose >/dev/null 2>&1 || { print_error "docker-compose 未安装"; exit 1; }
print_status "docker-compose 已安装"

echo ""
print_info "第 2/4 步: 验证模型文件"
if [ ! -d "/model/Qwen2.5-0.5B-Instruct" ]; then
    print_error "模型文件不存在: /model/Qwen2.5-0.5B-Instruct"
    print_info "正在下载模型 (这可能需要几分钟)..."
    docker compose --profile download up download-model 2>&1 | grep -E "Download|completed|error" || true
else
    print_status "模型文件已存在"
fi

echo ""
print_info "第 3/4 步: 清理端口冲突"
for PORT in 8000 8080 3000; do
    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_info "检测到端口 $PORT 被占用，正在清理..."
        PID=$(lsof -Pi :$PORT -sTCP:LISTEN -t 2>/dev/null)
        kill -9 $PID 2>/dev/null || true
        sleep 1
    fi
done
print_status "端口冲突已清理"

echo ""
print_info "第 4/4 步: 启动后端和前端服务"

print_info "构建 NeurX 后端镜像..."
docker build -t neurx:latest . >/dev/null 2>&1
print_status "后端镜像构建完成"

print_info "启动后端服务 (API 端口 8000)..."
docker compose --profile api up -d neurx-api >/dev/null 2>&1
print_status "后端服务已启动"

print_info "等待后端服务就绪 (最多 60 秒)..."
RETRY=0
MAX_RETRY=12
while [ $RETRY -lt $MAX_RETRY ]; do
    if curl -s http://localhost:8000/health | grep -q "ok"; then
        print_status "后端服务已就绪"
        break
    fi
    RETRY=$((RETRY + 1))
    echo -n "."
    sleep 5
done

if [ $RETRY -eq $MAX_RETRY ]; then
    print_error "后端服务启动失败"
    exit 1
fi

print_info "构建前端镜像..."
if [ -d "$FRONTEND_DIR" ]; then
    cd "$FRONTEND_DIR"
    if [ -f "package.json" ]; then
        docker build -t neurx-frontend:latest . >/dev/null 2>&1
        cd "$SCRIPT_DIR"
        print_status "前端镜像构建完成"
        
        print_info "启动前端服务 (Web 端口 3000)..."
        docker run -d \
            --name neurx-frontend \
            -p 3000:3000 \
            --network host \
            neurx-frontend:latest >/dev/null 2>&1
        print_status "前端服务已启动"
        
        sleep 3
        FRONTEND_STATUS="✓ 前端: http://localhost:3000"
    else
        cd "$SCRIPT_DIR"
        print_info "前端项目配置缺失，跳过前端部署"
        FRONTEND_STATUS="- 前端: 未配置"
    fi
else
    print_info "前端目录不存在，跳过前端部署"
    FRONTEND_STATUS="- 前端: 未部署"
fi

echo ""
print_header "部署完成！"

echo ""
echo -e "${GREEN}────────────────────────────────────────────────────────────────${NC}"
echo -e "${GREEN}   ✅ NeurX 前后端部署成功${NC}"
echo -e "${GREEN}────────────────────────────────────────────────────────────────${NC}"
echo ""
echo "📍 服务地址:"
echo "   ✓ 后端 API: http://localhost:8000"
echo "   $FRONTEND_STATUS"
echo ""
echo "🧪 测试服务:"
echo "   后端健康检查:"
echo "     curl http://localhost:8000/health"
echo ""
echo "   后端聊天 API:"
echo "     curl -X POST http://localhost:8000/v1/chat/completions \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"model\":\"default\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]}'"
echo ""
echo "🔧 管理命令:"
echo "   查看后端日志:  docker logs neurx-api-server -f"
if [ -n "$(docker ps -aq -f name=neurx-frontend 2>/dev/null)" ]; then
    echo "   查看前端日志:  docker logs neurx-frontend -f"
fi
echo "   停止服务:      bash stop.sh"
echo "   重启服务:      bash restart.sh"
echo "   测试 API:      bash test.sh"
echo ""
echo "📚 文档:"
echo "   快速参考:      cat ONE_CLICK_DEPLOY.md"
echo "   详细指南:      cat QUICK_START.md"
echo "   部署脚本:      cat DEPLOY_SCRIPTS.md"
echo ""
echo -e "${GREEN}────────────────────────────────────────────────────────────────${NC}"
echo ""
