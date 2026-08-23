# 🚀 NeurX 公网访问 - 快速参考

## 📍 服务状态 (2024-现在)

| 组件 | 状态 | 地址 | 访问 |
|------|------|------|------|
| 后端 API | ✅ 运行 | 127.0.0.1:8000 | 本地 |
| 前端 Web | ✅ 运行 | 127.0.0.1:3000 | 本地 |
| Nginx 代理 | ✅ 运行 | 0.0.0.0:80 | 本地/内网 |
| 公网访问 | ❌ 待配置 | 8.140.241.141 | 需安全组 |

## 🎯 3步启用公网访问

### 1️⃣ 配置安全组 (2 分钟)

**阿里云控制台:**
```
https://ecs.console.aliyun.com
→ 网络与安全 → 安全组
→ 编辑规则 → 添加规则
  协议: TCP
  端口: 80/80
  来源: 0.0.0.0/0
→ 保存 → 等待生效 (1-2 分钟)
```

### 2️⃣ 测试连接 (即时)

```bash
# 本地测试 (立即)
curl http://localhost/health

# 公网测试 (安全组生效后)
curl http://8.140.241.141/health

# 预期: {"status":"ok","backend":"neurx-s-cpu"}
```

### 3️⃣ 访问服务

```
前端 Web UI: http://8.140.241.141
API 端点: http://8.140.241.141/v1/chat/completions
```

## 📞 常用命令

```bash
# 检查服务
curl http://localhost/health

# 查看 Nginx 状态
sudo systemctl status nginx

# 重启 Nginx
sudo systemctl restart nginx

# 查看日志
sudo tail -f /var/log/nginx/access.log

# 查看后端日志
docker logs neurx-api-server

# 测试聊天 API
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"default","messages":[{"role":"user","content":"hello"}]}'
```

## 🔍 故障排查

| 症状 | 原因 | 解决 |
|------|------|------|
| 本地 OK，公网不行 | 安全组未配置 | 按步骤 1 配置 |
| 502 Bad Gateway | 后端未运行 | `docker compose up -d` |
| Connection timeout | 端口未开放 | 检查安全组规则 |
| 无法连接 Nginx | Nginx 停止 | `sudo systemctl restart nginx` |

## 📁 重要文件

- Nginx 配置: `/etc/nginx/nginx.conf`
- 后端: Docker Compose (`docker-compose-full.yml`)
- 前端: `frontend/index.html`
- 模型: `/model/Qwen2.5-0.5B-Instruct`

## 📚 详细文档

- [安全组配置](SECURITY_GROUP_CONFIG.md)
- [完整指南](PUBLIC_ACCESS_GUIDE.md)
- [部署手册](FULLSTACK_DEPLOYMENT.md)

---
**提示**: 公网访问通常需要 1-2 分钟安全组规则生效，请耐心等待。
