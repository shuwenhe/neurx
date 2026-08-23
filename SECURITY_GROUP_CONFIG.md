# 🔓 启用公网访问 - 安全组配置

## 📊 当前状态

```
✅ Nginx 反向代理: 已配置并运行
✅ 本地访问: http://localhost → 正常
✅ 本地 IP 访问: http://172.21.216.150 → 正常
❌ 公网 IP 访问: http://8.140.241.141 → 需要开放安全组
```

## 🎯 您的信息

- **公网 IP**: 8.140.241.141
- **内网 IP**: 172.21.216.150
- **HTTP 端口**: 80 (Nginx 代理)
- **API 端口**: 8000 (后端,内部访问)
- **前端端口**: 3000 (前端,内部访问)

## ⚙️ 配置步骤 (选择您的云平台)

### 阿里云 (ECS) - 推荐配置步骤

**1. 登录控制台**
- 访问: https://ecs.console.aliyun.com
- 选择地区: 同您的 ECS 实例

**2. 进入安全组**
- 左侧菜单 → 网络与安全 → 安全组
- 或直接搜索 "安全组"

**3. 添加入站规则**
- 找到您的安全组
- 点击 "编辑规则" 或 "管理规则"
- 点击 "添加规则" (入站)

**4. 配置规则**
```
协议类型: TCP
端口范围: 80/80
授权对象: 0.0.0.0/0
优先级: 1
```

或使用快速选择:
```
预设: HTTP (80)
优先级: 1
```

**5. 保存**
- 点击 "确定" 或 "保存"
- 等待 1-2 分钟规则生效

### AWS (EC2)

**1. 登录 AWS 控制台**
- 访问: https://console.aws.amazon.com

**2. 进入安全组**
- EC2 → 安全组

**3. 编辑入站规则**
- 选择您的安全组
- 编辑入站规则

**4. 添加规则**
```
类型: HTTP
协议: TCP
端口范围: 80
来源: 0.0.0.0/0
```

**5. 保存**

### 腾讯云 (CVM)

**1. 登录控制台**
- 访问: https://console.cloud.tencent.com

**2. 进入安全组**
- 云产品 → 计算 → 云服务器 → 安全组

**3. 添加规则**
- 操作 → 编辑规则

**4. 添加入站规则**
```
来源: 0.0.0.0/0
协议端口: TCP:80
操作: 允许
```

**5. 确定**

### 华为云 (ECS)

**1. 登录控制台**
- 访问: https://console.huaweicloud.com

**2. 进入安全组**
- 计算 → 弹性云服务器 → 安全组

**3. 编辑规则**
- 入方向规则 → 添加规则

**4. 配置规则**
```
优先级: 1
方向: 入
协议: TCP
端口: 80
源地址: 0.0.0.0/0
操作: 允许
```

**5. 提交**

## 🧪 验证配置

### 步骤 1: 等待规则生效
规则添加后需要 1-2 分钟生效

### 步骤 2: 本地测试 (验证 Nginx 工作)
```bash
# 健康检查
curl http://localhost/health

# 输出应该是:
# {"status":"ok","backend":"neurx-s-cpu"}
```

### 步骤 3: 测试公网访问

**通过 curl:**
```bash
# 使用您的公网 IP
curl http://8.140.241.141/health

# 或从另一台机器
curl http://8.140.241.141/health
```

**通过浏览器:**
```
http://8.140.241.141
```

**预期结果:**
- ✅ 看到 NeurX 前端 Web UI
- ✅ /health 返回 JSON: `{"status":"ok","backend":"neurx-s-cpu"}`
- ✅ 前端页面可以与后端通信

### 步骤 4: 测试 API

```bash
curl -X POST http://8.140.241.141/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "Hello"}],
    "temperature": 0.3,
    "max_tokens": 100
  }'
```

## 🔍 故障排查

### 问题 1: 仍然无法访问

**检查清单:**
- [ ] 云平台安全组已添加 TCP 80 规则
- [ ] 规则已生效 (等待 2-3 分钟)
- [ ] Nginx 运行: `sudo systemctl status nginx`
- [ ] 后端运行: `curl http://localhost:8000/health`

**诊断命令:**
```bash
# 检查安全组是否有效
sudo iptables -L -n | grep 80

# 检查 Nginx 错误
sudo tail -f /var/log/nginx/error.log

# 测试内网 IP
curl http://172.21.216.150/health
```

### 问题 2: 超时 (Connection timeout)

**原因:** 云平台防火墙没有开放端口

**解决:**
1. 重新检查安全组配置
2. 确保规则中的 "端口范围" 是 80/80
3. 确保 "授权对象" 是 0.0.0.0/0 (允许所有)
4. 保存并等待生效

### 问题 3: 连接被拒绝 (Connection refused)

**原因:** 
- Nginx 没有运行
- Nginx 监听错误的端口

**解决:**
```bash
# 检查 Nginx
sudo systemctl status nginx

# 检查监听端口
sudo lsof -i :80

# 重启 Nginx
sudo systemctl restart nginx
```

### 问题 4: 502 Bad Gateway

**原因:** Nginx 无法连接到后端

**解决:**
```bash
# 检查后端是否运行
curl http://localhost:8000/health

# 查看 Nginx 错误日志
sudo tail -50 /var/log/nginx/error.log

# 重新启动后端
cd /app/shuwen/neurx
docker compose --profile api restart neurx-api
```

## 📝 快速命令参考

```bash
# 检查 Nginx 状态
sudo systemctl status nginx

# 重启 Nginx
sudo systemctl restart nginx

# 查看实时日志
sudo tail -f /var/log/nginx/access.log

# 检查后端
curl http://localhost:8000/health

# 从公网测试
curl http://8.140.241.141/health

# 查看监听端口
sudo lsof -i :80
sudo lsof -i :8000

# 查看 Nginx 配置
sudo cat /etc/nginx/nginx.conf
```

## 🎯 检查清单

在测试公网访问前，确保:

- [ ] Nginx 运行且配置正确: `sudo systemctl status nginx`
- [ ] 后端 API 运行: `curl http://localhost:8000/health`
- [ ] 本地代理工作: `curl http://localhost/health`
- [ ] 云平台安全组已配置
- [ ] 安全组规则已生效 (等待 2-3 分钟)
- [ ] 防火墙未阻止 (UFW 已验证为不活跃)

## 📞 常见问题

**Q: 为什么需要安全组?**
A: 云平台的安全组是虚拟防火墙，默认阻止所有入站流量，必须显式开放端口。

**Q: 80 端口有什么特别的?**
A: HTTP 默认端口是 80。通过 Nginx 监听 80，您可以使用公网 IP 直接访问，无需指定端口号。

**Q: 是否安全?**
A: HTTP 80 是明文传输。对于生产环境，建议配置 HTTPS。

**Q: 如何启用 HTTPS?**
A: Nginx 配置中有 HTTPS 模板，需要 SSL 证书。可使用 Let's Encrypt (免费)。

**Q: 其他云平台如何配置?**
A: 原理相同，都是在安全组/防火墙规则中添加 TCP 80 入站规则。

## 🚀 后续步骤

配置完成并验证后:

1. [ ] 分享公网 URL 给用户: http://8.140.241.141
2. [ ] 配置 HTTPS (生产环境推荐)
3. [ ] 配置 API 速率限制
4. [ ] 添加身份认证

## 📚 参考文档

- [Nginx 反向代理文档](/app/shuwen/neurx/docker/nginx-publicip.conf)
- [完整部署指南](/app/shuwen/neurx/FULLSTACK_DEPLOYMENT.md)
- [故障排查指南](/app/shuwen/neurx/PUBLIC_ACCESS_GUIDE.md)

---

**配置完成后，您的 NeurX 模型推理服务将可以通过互联网访问！**

需要帮助? 查看日志: `sudo tail -f /var/log/nginx/access.log`
