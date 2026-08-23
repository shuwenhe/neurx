# NeurX 公网访问配置指南

## 📌 问题说明

您的后端 API 仅在 `127.0.0.1:8000` 监听，这意味着：
- ✅ 本地访问有效: `curl http://localhost:8000/health`
- ❌ 公网无法访问: `curl http://8.140.241.141:8000/health`

## 🔧 解决方案选择

### 方案 A: Nginx 反向代理 (推荐) ⭐

**优点:**
- 无需修改后端代码
- 支持多个后端
- 可配置缓存和压缩
- 生产级解决方案

**步骤:**

```bash
# 1. 运行配置脚本 (自动安装和配置 Nginx)
bash setup-public-access.sh

# 2. 测试本地连接
curl http://localhost/health

# 3. 测试公网 IP (如果配置了安全组)
curl http://8.140.241.141/health
```

### 方案 B: Docker 端口映射

**优点:**
- 简单直接
- 无需额外软件

**步骤:**

```bash
# 1. 停止现有容器
docker compose down

# 2. 编辑 docker-compose.yml
# 修改 neurx-api 服务:
# 删除这行: network_mode: host
# 添加这行: ports:
#          - "8000:8000"

# 3. 重新启动
docker compose --profile api up -d neurx-api

# 4. 测试
curl http://localhost:8000/health
```

### 方案 C: 重新构建 (修改后端监听地址)

**优点:**
- 最根本的解决方案

**缺点:**
- 需要修改源代码
- 需要重新编译

## 🌐 云平台安全组配置

### 阿里云 (ECS)

1. 进入 [安全组](https://ecs.console.aliyun.com/#/securityGroup)
2. 选择您的安全组
3. 添加入站规则:
   ```
   协议类型: TCP
   端口范围: 80/80 (HTTP)
   授权对象: 0.0.0.0/0
   ```
4. 可选: 添加 443/443 (HTTPS)

### AWS (EC2)

1. 进入 [安全组](https://console.aws.amazon.com/ec2/v2/home#SecurityGroups)
2. 选择您的安全组
3. 编辑入站规则:
   ```
   类型: HTTP
   协议: TCP
   端口范围: 80
   来源: 0.0.0.0/0
   ```

### 腾讯云 (CVM)

1. 进入 [安全组](https://console.cloud.tencent.com/vpc/securitygroup)
2. 选择您的安全组
3. 添加入站规则:
   ```
   协议: TCP
   端口: 80
   来源: 0.0.0.0/0
   ```

## 🚀 快速启动 (完整指南)

### 第 1 步: 配置 Nginx

```bash
cd /app/shuwen/neurx
bash setup-public-access.sh
```

输出示例:
```
✓ Nginx 已安装
✓ 原配置已备份
✓ Nginx 配置已更新
✓ Nginx 已启动并运行

📍 服务访问地址:
   ✓ 前端: http://172.21.216.150
   ✓ 后端 API: http://172.21.216.150/api/*
   ✓ 健康检查: http://172.21.216.150/health
```

### 第 2 步: 测试本地连接

```bash
# 健康检查
curl http://localhost/health

# 聊天 API
curl -X POST http://localhost/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"default","messages":[{"role":"user","content":"hello"}]}'
```

### 第 3 步: 配置云平台安全组

按照上述云平台说明，开放 80 端口。

### 第 4 步: 测试公网访问

```bash
# 使用公网 IP 测试
curl http://8.140.241.141/health

# 或在浏览器访问
# http://8.140.241.141
```

## 🐛 故障排查

### 问题 1: Nginx 启动失败

**症状:** 错误信息 "Address already in use"

**解决:**
```bash
# 查找占用端口的进程
lsof -i :80

# 停止占用的进程
sudo kill -9 <PID>

# 或修改 Nginx 端口 (编辑 /etc/nginx/nginx.conf)
# 将 listen 80 改为 listen 8080
```

### 问题 2: Nginx 配置错误

**症状:** "Bad gateway" 或 "Connection refused"

**解决:**
```bash
# 检查配置语法
sudo nginx -t

# 查看错误日志
sudo tail -f /var/log/nginx/error.log

# 检查后端是否运行
curl http://localhost:8000/health
```

### 问题 3: 本地能访问，公网不能访问

**症状:** `curl http://localhost/health` 成功，但 `curl http://8.140.241.141/health` 失败

**原因:** 云平台安全组未开放端口

**解决:**
1. 进入云平台控制台
2. 找到您的 ECS/EC2/CVM 实例
3. 进入安全组设置
4. 添加入站规则: 开放 TCP 80 端口

### 问题 4: 前端无法连接到后端

**症状:** 前端显示 "后端离线"

**原因:** Nginx 代理路径配置不正确

**解决:**
```bash
# 编辑 Nginx 配置
sudo nano /etc/nginx/nginx.conf

# 确保包含以下内容:
# location /v1/ {
#     proxy_pass http://neurx_backend/v1/;
# }
# location /health {
#     proxy_pass http://neurx_backend/health;
# }

# 重新加载配置
sudo systemctl reload nginx
```

## 📊 访问路径对比

### 直接访问 (本地)
```bash
后端 API: http://localhost:8000
前端 Web: http://localhost:3000
```

### 通过 Nginx (本地/公网)
```bash
http://localhost
  ├─ / → 前端 Web UI
  ├─ /health → 后端健康检查
  ├─ /v1/chat/completions → 聊天 API
  └─ /api/* → 其他后端端点
```

## 🔐 安全建议

### 1. 启用 HTTPS (生产环境必须)

```bash
# 申请免费 SSL 证书 (Let's Encrypt)
sudo apt-get install certbot python3-certbot-nginx

# 申请证书
sudo certbot certonly --standalone -d your.domain.com

# 编辑 /etc/nginx/nginx.conf 启用 HTTPS 部分
# 取消注释 HTTPS server 块
# 修改域名和证书路径

# 重启 Nginx
sudo systemctl restart nginx
```

### 2. 限制 API 访问频率

在 Nginx 配置中添加:
```nginx
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

location /v1/ {
    limit_req zone=api_limit burst=20 nodelay;
    proxy_pass http://neurx_backend/v1/;
}
```

### 3. 添加防火墙规则

```bash
# 仅允许特定 IP 访问
sudo ufw allow from 203.0.113.0 to any port 80

# 限制连接数
sudo iptables -A INPUT -p tcp --dport 80 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j DROP
```

## 📞 快速命令参考

```bash
# 查看 Nginx 状态
sudo systemctl status nginx

# 重启 Nginx
sudo systemctl restart nginx

# 停止 Nginx
sudo systemctl stop nginx

# 启动 Nginx
sudo systemctl start nginx

# 检查配置
sudo nginx -t

# 查看实时日志
sudo tail -f /var/log/nginx/access.log

# 查看错误日志
sudo tail -f /var/log/nginx/error.log

# 重新加载配置 (不中断服务)
sudo systemctl reload nginx

# 查看监听的端口
sudo lsof -i :80
sudo lsof -i :443

# 查看 Nginx 进程
ps aux | grep nginx
```

## 📖 相关文档

- [Nginx 官方文档](http://nginx.org/en/docs/)
- [Let's Encrypt 免费 SSL](https://letsencrypt.org/)
- [Docker 网络模式](https://docs.docker.com/network/)

## 🎯 推荐步骤

1. ✅ 运行 `bash setup-public-access.sh`
2. ✅ 本地测试: `curl http://localhost/health`
3. ✅ 配置云平台安全组
4. ✅ 公网测试: `curl http://8.140.241.141/health`
5. ✅ 访问前端: `http://8.140.241.141`

---

**需要帮助？** 查看故障排查部分或查看 `/var/log/nginx/error.log` 中的日志。
