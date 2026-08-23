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

print_header "NeurX 公网访问 - Nginx 反向代理配置"

echo ""
print_info "此脚本将配置 Nginx 反向代理以实现公网访问"

print_info "第 1/3 步: 检查 Nginx 安装状态"

if command -v nginx >/dev/null 2>&1; then
    print_status "Nginx 已安装"
    NGINX_INSTALLED=true
else
    print_info "Nginx 未安装，将尝试安装..."
    
    if command -v apt-get >/dev/null 2>&1; then
        print_info "检测到 Debian/Ubuntu 系统，使用 apt 安装"
        sudo apt-get update >/dev/null 2>&1
        sudo apt-get install -y nginx >/dev/null 2>&1
        print_status "Nginx 安装完成"
    elif command -v yum >/dev/null 2>&1; then
        print_info "检测到 RHEL/CentOS 系统，使用 yum 安装"
        sudo yum install -y nginx >/dev/null 2>&1
        print_status "Nginx 安装完成"
    else
        print_error "无法自动安装 Nginx，请手动安装后重试"
        echo "Ubuntu/Debian: sudo apt-get install nginx"
        echo "RHEL/CentOS: sudo yum install nginx"
        exit 1
    fi
    NGINX_INSTALLED=true
fi

echo ""
print_info "第 2/3 步: 备份并配置 Nginx"

# 备份原配置
if [ -f /etc/nginx/nginx.conf ]; then
    sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)
    print_status "原配置已备份"
fi

# 复制新配置
sudo cp "$SCRIPT_DIR/nginx-publicip.conf" /etc/nginx/nginx.conf
print_status "Nginx 配置已更新"

echo ""
print_info "第 3/3 步: 启动 Nginx"

# 重启 Nginx
sudo systemctl restart nginx
sleep 2

if sudo systemctl is-active --quiet nginx; then
    print_status "Nginx 已启动并运行"
else
    print_error "Nginx 启动失败，检查配置..."
    sudo nginx -t
    exit 1
fi

echo ""
print_header "配置完成！"

echo ""
echo -e "${GREEN}────────────────────────────────────────────────────────────────${NC}"
echo -e "${GREEN}   ✅ Nginx 反向代理已配置${NC}"
echo -e "${GREEN}────────────────────────────────────────────────────────────────${NC}"
echo ""

PUBLIC_IP=$(hostname -I | awk '{print $1}')
echo "📍 服务访问地址:"
echo "   ✓ 前端: http://$PUBLIC_IP"
echo "   ✓ 后端 API: http://$PUBLIC_IP/api/*"
echo "   ✓ 健康检查: http://$PUBLIC_IP/health"
echo ""

echo "🧪 快速测试:"
echo "   健康检查:"
echo "     curl http://$PUBLIC_IP/health"
echo ""
echo "   聊天 API (本地):"
echo "     curl -X POST http://localhost:8000/v1/chat/completions \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"model\":\"default\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]}'"
echo ""
echo "   聊天 API (通过 Nginx):"
echo "     curl -X POST http://$PUBLIC_IP/v1/chat/completions \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"model\":\"default\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]}'"
echo ""

echo "🔧 管理命令:"
echo "   查看状态: sudo systemctl status nginx"
echo "   重启: sudo systemctl restart nginx"
echo "   停止: sudo systemctl stop nginx"
echo "   查看日志: sudo tail -f /var/log/nginx/access.log"
echo "   检查配置: sudo nginx -t"
echo ""

echo "🌐 公网访问:"
echo "   如果上述本地测试成功，但公网仍无法访问，请检查:"
echo "   1️⃣ 云平台的安全组 (需要开放 80/443 端口)"
echo "   2️⃣ 防火墙规则 (sudo ufw allow 80/tcp)"
echo "   3️⃣ 路由器/NAT 设置 (端口转发)"
echo ""

echo -e "${GREEN}────────────────────────────────────────────────────────────────${NC}"
echo ""
