# 🌐 NeurX Web UI 快速访问指南

## 三种访问方式对比

### 🏆 方式一：一键启动脚本（推荐）

```bash
cd /Users/shuwen/shuwen/neurx
bash config/clusters/2node_deployment/start_web_ui_local.sh
```

**特点**：
- ✅ 全自动化
- ✅ 自动打开浏览器
- ✅ 错误自动恢复
- ✅ 按 Ctrl+C 优雅关闭

**预期输出**：
```
╔════════════════════════════════════════════╗
║  NeurX 分布式推理系统 - Web UI 本地访问   ║
╚════════════════════════════════════════════╝

✅ SSH 隧道已启动
✅ Web UI 服务已启动
✅ 浏览器已打开
✅ NeurX Web UI 已准备就绪！
🌐 访问地址: http://127.0.0.1:8081
```

---

### 🔧 方式二：手动三步法

#### 第一步：建立 SSH 隧道（保持此终端打开）

```bash
sshpass -p "shuwen" ssh -N -L 8081:127.0.0.1:8081 shuwen@192.168.10.39
```

#### 第二步：启动远程 Web UI（另一个终端）

```bash
sshpass -p "shuwen" ssh shuwen@192.168.10.39 \
  "cd /neurx && nohup python3 -m http.server 8081 --directory app/web &"
```

#### 第三步：打开浏览器

在浏览器地址栏输入：
```
http://127.0.0.1:8081
```

---

### 💻 方式三：Docker 容器化访问（可选）

```bash
# 在本地构建简单代理容器
docker run -d \
  -p 8081:8081 \
  --name neurx-web \
  alpine/flanneld \
  sh -c "apk add --no-cache openssh-client && \
         ssh -N -L 8081:127.0.0.1:8081 shuwen@192.168.10.39"
```

---

## 📊 系统架构

```
您的本地 MacBook
    │
    ├─ 浏览器 (Safari/Chrome/Firefox)
    │   └─ http://127.0.0.1:8081
    │
    └─ SSH 隧道
        └─ 端口转发 8081 → 192.168.10.39:8081
            │
            └─ 远程 Linux 服务器 (192.168.10.39)
                ├─ Controller 推理服务 (Python)
                │   └─ 推理 API: http://192.168.10.39:8000
                │
                └─ Web UI 服务 (Python HTTP Server)
                    └─ 前端页面: http://192.168.10.39:8081
                        └─ 文件: /neurx/app/web/index.html
                            │
                            └─ 调用推理 API
                                └─ Worker 节点 (192.168.10.75) 执行
```

---

## 🎯 关键信息速查

| 项目 | 内容 |
|------|------|
| **本地访问地址** | `http://127.0.0.1:8081` |
| **Controller IP** | `192.168.10.39` |
| **Worker IP** | `192.168.10.75` |
| **推理 API 地址** | `http://192.168.10.39:8000` |
| **Controller 用户名** | `shuwen` |
| **Controller 密码** | `shuwen` |
| **Worker 用户名** | `shuwen` |
| **Worker 密码** | `Linux@_2026..` |
| **启动脚本位置** | `/neurx/config/clusters/2node_deployment/start_web_ui_local.sh` |

---

## ✅ 验证步骤

### 检查连接

```bash
# 1. 测试 SSH 连接
sshpass -p "shuwen" ssh -q shuwen@192.168.10.39 "echo ✅ SSH连接正常"

# 2. 测试推理 API
curl http://192.168.10.39:8000/v1/models 2>/dev/null | jq '.data[0].id'

# 3. 测试本地 Web UI（建立隧道后）
curl http://127.0.0.1:8081 | head -5
```

### 查看日志

```bash
# Controller Web UI 日志
sshpass -p "shuwen" ssh shuwen@192.168.10.39 \
  "tail -20 /tmp/neurx_web_ui.log"

# SSH 隧道进程
ps aux | grep "ssh -N -L 8081"

# 远程 Python 服务器
sshpass -p "shuwen" ssh shuwen@192.168.10.39 \
  "ps aux | grep 'http.server 8081'"
```

---

## 🚀 启动命令速记

```bash
# 最简单：一键启动
bash /Users/shuwen/shuwen/neurx/config/clusters/2node_deployment/start_web_ui_local.sh

# 停止
bash /Users/shuwen/shuwen/neurx/config/clusters/2node_deployment/start_web_ui_local.sh stop

# 重启
bash start_web_ui_local.sh stop; sleep 2; bash start_web_ui_local.sh
```

---

## ⚠️ 常见问题速解

| 问题 | 解决方案 |
|------|--------|
| **连接被拒绝 (ERR_CONNECTION_REFUSED)** | 1. 检查 SSH 隧道: `ps aux \| grep ssh`<br>2. 重建隧道: `sshpass -p "shuwen" ssh -N -L 8081:127.0.0.1:8081 shuwen@192.168.10.39` |
| **页面加载慢** | 1. 检查网络延迟<br>2. 查看远程日志<br>3. 重启服务 |
| **SSH 命令不found** | 安装 sshpass: `brew install sshpass` |
| **端口 8081 已被占用** | 杀死占用进程: `lsof -i :8081 \| tail -1 \| awk '{print $2}' \| xargs kill -9` |
| **无法连接 192.168.10.39** | 检查网络和防火墙配置 |

---

## 📖 详细文档

完整的访问指南和故障排查，请查看：
```
/Users/shuwen/shuwen/neurx/config/clusters/2node_deployment/WEB_UI_ACCESS_GUIDE.md
```

---

## 🎯 典型工作流

### 早上启动

```bash
# 1. 启动 Web UI（一句命令）
bash /Users/shuwen/shuwen/neurx/config/clusters/2node_deployment/start_web_ui_local.sh

# 2. 浏览器自动打开 http://127.0.0.1:8081

# 3. 开始使用推理服务
```

### 晚上关闭

```bash
# 停止所有服务
bash /Users/shuwen/shuwen/neurx/config/clusters/2node_deployment/start_web_ui_local.sh stop

# 或直接 Ctrl+C（脚本运行终端）
```

---

## 📞 需要帮助？

```bash
# 查看脚本帮助
bash start_web_ui_local.sh --help 2>/dev/null || echo "查看 WEB_UI_ACCESS_GUIDE.md"

# 查看状态
ps aux | grep -E "ssh.*8081|http.server 8081"

# 查看日志
tail -50 /tmp/neurx_web_ui.log
sshpass -p "shuwen" ssh shuwen@192.168.10.39 "tail -50 /tmp/neurx_web_ui.log"
```

---

**现在就开始**：
```bash
bash /Users/shuwen/shuwen/neurx/config/clusters/2node_deployment/start_web_ui_local.sh
```

✅ **就这么简单！** 🎉
