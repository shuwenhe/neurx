# NeurX 分布式推理系统 - 本地Web UI访问指南

## 📋 概述

NeurX 分布式推理系统运行在两台远程 Linux 机器上：
- **Controller** (Master): 192.168.10.39 - 推理服务 + Web UI
- **Worker** (Slave): 192.168.10.75 - 计算节点

由于本地是 macOS (ARM64)，而远程是 Linux (x86-64)，不能直接在本地运行前端。
**解决方案**：通过 SSH 端口转发将远程 Web UI 服务转发到本地浏览器访问。

---

## 🚀 快速启动 (推荐)

### 方式一：使用启动脚本 (最简单)

```bash
# 进入项目目录
cd /Users/shuwen/shuwen/neurx

# 执行启动脚本
bash config/clusters/2node_deployment/start_web_ui_local.sh
```

**功能**：
- ✅ 自动建立 SSH 隧道
- ✅ 启动远程 Web UI 服务
- ✅ 自动打开浏览器访问
- ✅ 管理隧道生命周期

**脚本输出示例**：
```
╔════════════════════════════════════════════╗
║  NeurX 分布式推理系统 - Web UI 本地访问   ║
╚════════════════════════════════════════════╝

🔗 建立 SSH 端口转发...
✅ SSH 隧道已启动
   PID: 12345

🖥️  检查远程 Web UI 服务...
✅ Web UI 服务已启动

🌐 打开本地浏览器...
✅ 连接成功！
✅ 浏览器已打开

✅ NeurX Web UI 已准备就绪！
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🌐 访问地址: http://127.0.0.1:8081
```

---

## 🔧 手动方式

如果启动脚本出现问题，可以手动执行以下步骤：

### 步骤 1: 建立 SSH 隧道

在本地终端运行（**保持此终端打开**）：

```bash
sshpass -p "shuwen" ssh -N -L 8081:127.0.0.1:8081 shuwen@192.168.10.39
```

**参数说明**：
- `-N`: 不执行远程命令，仅用于端口转发
- `-L 8081:127.0.0.1:8081`: 本地端口 8081 转发到远程 127.0.0.1:8081
- `192.168.10.39`: Controller 的 IP

**输出**：
```
(无输出，保持连接)
```

### 步骤 2: 启动远程 Web UI 服务

在 **另一个终端** 执行：

```bash
sshpass -p "shuwen" ssh shuwen@192.168.10.39 << 'EOF'
cd /neurx
nohup python3 -m http.server 8081 --directory app/web > /tmp/neurx_web_ui.log 2>&1 &
sleep 2
echo "✅ Web UI 服务已启动"
ps aux | grep "http.server" | grep -v grep
EOF
```

**验证输出**：
```
✅ Web UI 服务已启动
shuwen  12345  0.5  0.0  31836 19984 ?  S  15:59  0:00 python3 -m http.server 8081 --directory app/web
```

### 步骤 3: 在浏览器中打开

在本地浏览器地址栏输入：
```
http://127.0.0.1:8081
```

---

## 📊 工作流程图

```
┌─────────────────────────┐
│  本地浏览器 (macOS)      │
│ http://127.0.0.1:8081   │
└────────────┬────────────┘
             │ (HTTP 请求)
             │
     ┌───────▼────────┐
     │  SSH 隧道      │
     │  端口 8081     │
     └───────┬────────┘
             │ (TCP 转发)
             │
┌────────────▼──────────────┐
│  Controller 192.168.10.39 │
│  Python HTTP 服务器       │
│  端口 8081                │
│  serving app/web/         │
└─────────────────────────┘
```

---

## 🎯 常见操作

### 查看 Web UI 服务状态

**本地**：
```bash
# 测试本地连接
curl http://127.0.0.1:8081

# 查看 SSH 隧道进程
ps aux | grep "ssh -N -L 8081"
```

**远程**：
```bash
# 查看远程 Web UI 进程
sshpass -p "shuwen" ssh shuwen@192.168.10.39 "ps aux | grep http.server"

# 查看日志
sshpass -p "shuwen" ssh shuwen@192.168.10.39 "tail -20 /tmp/neurx_web_ui.log"

# 查看监听端口
sshpass -p "shuwen" ssh shuwen@192.168.10.39 "ss -tlnp | grep 8081"
```

### 停止 Web UI

**使用脚本停止**：
```bash
bash config/clusters/2node_deployment/start_web_ui_local.sh stop
```

**手动停止**：
```bash
# 停止 SSH 隧道
pkill -f "ssh -N -L 8081"

# 停止远程 Web UI 服务
sshpass -p "shuwen" ssh shuwen@192.168.10.39 "pkill -f 'http.server 8081'"
```

### 重启 Web UI

```bash
# 停止
bash config/clusters/2node_deployment/start_web_ui_local.sh stop

# 等待 2 秒
sleep 2

# 启动
bash config/clusters/2node_deployment/start_web_ui_local.sh
```

### 查看远程日志

```bash
# 查看最近 50 行日志
sshpass -p "shuwen" ssh shuwen@192.168.10.39 "tail -50 /tmp/neurx_web_ui.log"

# 实时跟踪日志
sshpass -p "shuwen" ssh shuwen@192.168.10.39 "tail -f /tmp/neurx_web_ui.log"
```

---

## 🔍 故障排查

### 问题 1: "连接被拒绝" (ERR_CONNECTION_REFUSED)

**原因**：
- SSH 隧道未建立
- 远程 Web UI 服务未启动

**解决方案**：
```bash
# 1. 验证 SSH 连接
sshpass -p "shuwen" ssh -T shuwen@192.168.10.39 "echo OK"

# 2. 检查隧道进程
ps aux | grep "ssh -N -L 8081"

# 3. 重新建立隧道
sshpass -p "shuwen" ssh -N -L 8081:127.0.0.1:8081 shuwen@192.168.10.39

# 4. 验证连接
curl http://127.0.0.1:8081 | head -20
```

### 问题 2: "ssh: command not found"

**原因**：未安装 sshpass

**解决方案**：
```bash
# macOS
brew install sshpass

# 或手动输入密码（去掉 sshpass）
ssh -N -L 8081:127.0.0.1:8081 shuwen@192.168.10.39
# 输入密码: shuwen
```

### 问题 3: 端口已被占用

**症状**：
```
bind: Address already in use
```

**解决方案**：
```bash
# 查看占用端口的进程
lsof -i :8081

# 杀死进程
kill -9 <PID>

# 或重新映射到其他端口
sshpass -p "shuwen" ssh -N -L 8082:127.0.0.1:8081 shuwen@192.168.10.39
# 然后访问: http://127.0.0.1:8082
```

### 问题 4: Web 页面加载不完整

**症状**：页面加载后部分资源 404

**原因**：app/web/ 目录下某些文件缺失

**解决方案**：
```bash
# 检查远程文件
sshpass -p "shuwen" ssh shuwen@192.168.10.39 "ls -la /neurx/app/web/"

# 重新同步文件
cd /Users/shuwen/shuwen/neurx
rsync -avz app/web/ shuwen@192.168.10.39:/neurx/app/web/

# 刷新浏览器 (Ctrl+Shift+R 强制刷新)
```

---

## 📝 网络配置参考

| 组件 | 地址 | 端口 | 说明 |
|------|------|------|------|
| Controller 推理 API | 192.168.10.39 | 8000 | REST API (推理请求) |
| Controller Web UI | 192.168.10.39 | 8081 | HTTP (前端页面) |
| Worker 计算 | 192.168.10.75 | 29501 | NCCL (分布式通信) |
| 本地 Web UI | 127.0.0.1 | 8081 | SSH 隧道转发 |

---

## 🔐 安全说明

**当前配置**（演示环境）：
- ✗ 无 HTTPS/TLS
- ✗ 无 API 认证
- ✓ SSH 连接加密
- ✓ 限于局域网

**生产环境建议**：
1. 配置 HTTPS 证书
2. 添加 API 认证 (Bearer Token)
3. 启用速率限制
4. 配置反向代理 (Nginx)
5. 设置防火墙规则

---

## 💡 高级用法

### 在后台持久运行

```bash
# 创建 systemd 服务（可选）
cat > /tmp/neurx_web.service << 'EOF'
[Unit]
Description=NeurX Web UI SSH Tunnel
After=network.target

[Service]
Type=simple
User=shuwen
ExecStart=/usr/bin/sshpass -p shuwen /usr/bin/ssh -N -L 8081:127.0.0.1:8081 shuwen@192.168.10.39
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 或使用 tmux 后台运行
tmux new-session -d -s neurx_web \
  "sshpass -p shuwen ssh -N -L 8081:127.0.0.1:8081 shuwen@192.168.10.39"

# 查看会话
tmux list-sessions

# 关闭会话
tmux kill-session -t neurx_web
```

### 访问不同的远程服务

```bash
# 访问推理 API (端口 8000)
sshpass -p "shuwen" ssh -N -L 8000:127.0.0.1:8000 shuwen@192.168.10.39

# 访问 Worker 节点
sshpass -p "Linux@_2026.." ssh -N -L 29501:127.0.0.1:29501 shuwen@192.168.10.75
```

---

## 🎯 总结

| 步骤 | 命令 | 说明 |
|------|------|------|
| 1 | `bash start_web_ui_local.sh` | 一键启动（推荐） |
| 2 | 浏览器访问 `http://127.0.0.1:8081` | 打开 Web UI |
| 3 | `bash start_web_ui_local.sh stop` | 停止服务 |

---

**部署完成时间**: 2026-08-29  
**系统状态**: ✅ **正常运行**  
**本地访问**: ✅ **已就绪**
