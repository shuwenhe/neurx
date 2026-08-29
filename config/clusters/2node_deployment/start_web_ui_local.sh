#!/bin/bash

# NeurX Web UI - 本地访问脚本
# 功能：建立 SSH 隧道并在本地浏览器中打开前端
# 使用方法：
#   bash start_web_ui_local.sh        # 启动隧道 + 前端
#   bash start_web_ui_local.sh stop   # 停止隧道

set -e

CONTROLLER_IP="192.168.10.39"
CONTROLLER_USER="shuwen"
CONTROLLER_PASSWORD="shuwen"
LOCAL_PORT="8081"
REMOTE_PORT="8081"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查 sshpass
check_sshpass() {
    if ! command -v sshpass &> /dev/null; then
        echo -e "${RED}❌ sshpass 未安装${NC}"
        echo "请运行: brew install sshpass"
        exit 1
    fi
}

# 启动 SSH 隧道（包括 Web UI 和推理 API）
start_tunnel() {
    echo -e "${BLUE}🔗 建立 SSH 端口转发...${NC}"
    echo ""
    
    # 检查 Web UI 端口
    if lsof -Pi :${LOCAL_PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  本地端口 ${LOCAL_PORT} 已被占用${NC}"
        EXISTING_PID=$(lsof -t -i :${LOCAL_PORT})
        echo -e "${YELLOW}现有进程 PID: ${EXISTING_PID}${NC}"
        read -p "是否杀死现有进程? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kill $EXISTING_PID 2>/dev/null || true
            sleep 1
        else
            echo -e "${YELLOW}使用现有连接${NC}"
            return
        fi
    fi
    
    # 检查推理 API 端口
    if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  本地端口 8000 已被占用${NC}"
        EXISTING_PID=$(lsof -t -i :8000)
        echo -e "${YELLOW}现有进程 PID: ${EXISTING_PID}${NC}"
        read -p "是否杀死现有进程? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kill $EXISTING_PID 2>/dev/null || true
            sleep 1
        else
            echo -e "${YELLOW}使用现有连接${NC}"
            return
        fi
    fi
    
    # 启动 SSH 隧道（同时转发两个端口）
    echo "启动命令: sshpass -p '***' ssh -N -L ${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT} -L 8000:127.0.0.1:8000 ${CONTROLLER_USER}@${CONTROLLER_IP}"
    echo ""
    
    sshpass -p "${CONTROLLER_PASSWORD}" ssh -N \
        -L ${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT} \
        -L 8000:127.0.0.1:8000 \
        ${CONTROLLER_USER}@${CONTROLLER_IP} &
    SSH_PID=$!
    
    # 保存 PID
    echo $SSH_PID > /tmp/neurx_ssh_tunnel.pid
    
    echo -e "${GREEN}✅ SSH 隧道已启动${NC}"
    echo -e "   PID: ${SSH_PID}"
    echo -e "   Web UI (8081): http://127.0.0.1:8081"
    echo -e "   推理 API (8000): http://127.0.0.1:8000"
    sleep 2
}

# 启动远程 Web UI 服务
start_remote_ui() {
    echo ""
    echo -e "${BLUE}🖥️  检查远程 Web UI 服务...${NC}"
    echo ""
    
    sshpass -p "${CONTROLLER_PASSWORD}" ssh ${CONTROLLER_USER}@${CONTROLLER_IP} << 'REMOTE_SCRIPT'
cd /neurx

# 检查服务是否已运行
if ps aux | grep -q "http.server 8081" | grep -v grep; then
    echo "✅ Web UI 服务已在运行"
else
    echo "🚀 启动 Web UI 服务..."
    nohup python3 -m http.server 8081 --directory app/web > /tmp/neurx_web_ui.log 2>&1 &
    sleep 2
    echo "✅ Web UI 服务已启动"
fi

# 验证
echo ""
echo "📋 服务验证:"
ss -tlnp | grep 8081 | awk '{print "   " $0}'

REMOTE_SCRIPT
}

# 打开浏览器
open_browser() {
    echo ""
    echo -e "${BLUE}🌐 打开本地浏览器...${NC}"
    echo ""
    
    # 等待连接建立
    sleep 2
    
    # 测试连接
    echo "测试连接 http://127.0.0.1:${LOCAL_PORT}..."
    for i in {1..10}; do
        if curl -s http://127.0.0.1:${LOCAL_PORT} > /dev/null 2>&1; then
            echo -e "${GREEN}✅ 连接成功！${NC}"
            break
        fi
        echo "等待中... ($i/10)"
        sleep 1
    done
    
    echo ""
    
    # 选择浏览器
    if command -v open &> /dev/null; then
        # macOS
        open "http://127.0.0.1:${LOCAL_PORT}"
        echo -e "${GREEN}✅ 浏览器已打开${NC}"
    elif command -v xdg-open &> /dev/null; then
        # Linux
        xdg-open "http://127.0.0.1:${LOCAL_PORT}" &
        echo -e "${GREEN}✅ 浏览器已打开${NC}"
    else
        echo -e "${YELLOW}⚠️  请手动在浏览器中打开:${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ NeurX Web UI 已准备就绪！${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "🌐 访问地址: ${BLUE}http://127.0.0.1:${LOCAL_PORT}${NC}"
    echo ""
    echo "📝 说明:"
    echo "  - SSH 隧道在后台运行"
    echo "  - 按 Ctrl+C 停止此脚本"
    echo "  - 执行 bash start_web_ui_local.sh stop 停止隧道"
    echo ""
}

# 停止隧道
stop_tunnel() {
    echo -e "${BLUE}🛑 停止 SSH 隧道...${NC}"
    
    if [ -f /tmp/neurx_ssh_tunnel.pid ]; then
        SSH_PID=$(cat /tmp/neurx_ssh_tunnel.pid)
        if ps -p $SSH_PID > /dev/null 2>&1; then
            kill $SSH_PID
            echo -e "${GREEN}✅ SSH 隧道已停止 (PID: ${SSH_PID})${NC}"
        fi
        rm /tmp/neurx_ssh_tunnel.pid
    else
        # 尝试杀死所有 SSH 隧道
        pkill -f "ssh -N -L ${LOCAL_PORT}" || true
        echo -e "${GREEN}✅ SSH 隧道已停止${NC}"
    fi
    
    # 检查端口
    if lsof -Pi :${LOCAL_PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  端口 ${LOCAL_PORT} 仍在使用${NC}"
    else
        echo -e "${GREEN}✅ 端口 ${LOCAL_PORT} 已释放${NC}"
    fi
}

# 主函数
main() {
    clear
    
    echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  NeurX 分布式推理系统 - Web UI 本地访问   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ "$1" == "stop" ]; then
        stop_tunnel
        exit 0
    fi
    
    check_sshpass
    start_tunnel
    start_remote_ui
    open_browser
    
    # 监听 Ctrl+C 退出
    trap 'echo ""; echo -e "${YELLOW}正在关闭...${NC}"; stop_tunnel; exit 0' SIGINT
    
    echo -e "${GREEN}✓ Web UI 运行中。按 Ctrl+C 停止。${NC}"
    
    while true; do
        sleep 60
    done
}

# 运行
main "$@"
