# NeurX 一键部署脚本说明

## 📦 核心脚本

### 1. `deploy.sh` - 完整一键部署 ⭐

**功能**：自动完成从检查环境到启动服务的所有步骤

```bash
bash deploy.sh
```

**包含步骤**：
1. ✅ 检查 Docker 和 docker-compose
2. ✅ 验证模型文件（如缺失可自动下载）
3. ✅ 清理端口冲突
4. ✅ 构建 Docker 镜像
5. ✅ 启动推理服务
6. ✅ 等待服务初始化
7. ✅ 验证健康检查
8. ✅ 显示 API 文档
9. ✅ 快速功能测试

**输出示例**：
```
╔════════════════════════════════════════╗
║   NeurX 推理服务一键启动             ║
╚════════════════════════════════════════╝

[步骤 1] 检查前置条件
✓ Docker 已安装
✓ docker-compose 已安装
✓ 模型文件已就绪

[步骤 2] 检查端口占用
✓ 端口 8000 已就绪

[步骤 3] 构建 Docker 镜像
ℹ 镜像已存在，跳过构建

[步骤 4] 启动推理服务
ℹ 启动 NeurX API 服务...
ℹ 等待服务初始化（最多 60 秒）...

[步骤 5] 验证服务
✓ 服务健康检查通过
ℹ 状态: {"status":"ok","backend":"neurx-s-cpu"}

[步骤 6] 部署完成
╔════════════════════════════════════════════════════╗
║ 🎉 NeurX 推理服务已启动！                         ║
╠════════════════════════════════════════════════════╣
║ 📍 本地访问: http://localhost:8000              ║
║ 🌐 公网访问: http://8.140.241.141:8000         ║
╠════════════════════════════════════════════════════╣
║ 📊 API 端点:
║   • 健康检查: GET /health
║   • 聊天 API:  POST /v1/chat/completions
╠════════════════════════════════════════════════════╣
║ 🛠️  常用命令:
║   查看日志: docker logs neurx-api-server
║   停止服务: docker compose down
║   健康检查: curl http://localhost:8000/health
╚════════════════════════════════════════════════════╝
```

---

### 2. `test.sh` - API 功能测试

**功能**：完整的 API 端点测试

```bash
bash test.sh
```

**测试内容**：
- ✅ 健康检查 (`GET /health`)
- ✅ 简单对话 (English)
- ✅ 中文对话
- ✅ 长文本生成
- ✅ 并发请求 (3 个同时请求)

**输出示例**：
```
╔════════════════════════════════════════╗
║     NeurX API 功能测试                ║
╚════════════════════════════════════════╝

━━━ 测试 1: 健康检查 ━━━
✓ 健康检查通过
响应: {"status":"ok","backend":"neurx-s-cpu"}

━━━ 测试 2: 简单对话 ━━━
✓ 聊天 API 响应正常
{
    "id": "chatcmpl-neurx-1000000",
    "object": "chat.completion",
    ...
}

━━━ 测试 5: 并发请求 ━━━
ℹ 发送 3 个并发请求...
✓ 并发请求全部成功 (3/3)

✨ 所有测试完成！

📊 服务状态
70542a1a43f5   neurx:latest    "/entrypoint.sh api"   3 min    Up 3 min    neurx-api-server

📈 资源使用
CONTAINER CPU% MEM USAGE   LIMIT     MEM%
neurx-api   15%  1.2GiB    31.3GiB   3.8%
```

---

### 3. `restart.sh` - 重启服务

**功能**：停止旧服务，清理端口，重新启动

```bash
bash restart.sh
```

**步骤**：
1. 停止 Docker 容器
2. 清理占用的端口进程
3. 启动服务
4. 验证服务健康

---

### 4. `stop.sh` - 停止服务

**功能**：优雅停止所有服务

```bash
bash stop.sh
```

**可选**：清理 Docker 镜像

---

## 🚀 快速开始

### 最简单的启动方式 (推荐)

```bash
cd /app/shuwen/neurx
bash deploy.sh
```

### 三步启动 (手动)

```bash
# 1. 进入目录
cd /app/shuwen/neurx

# 2. 启动 API
docker compose --profile api up -d neurx-api

# 3. 测试连接
curl http://localhost:8000/health
```

---

## 📋 常见场景

### 场景 1: 首次部署

```bash
bash deploy.sh
```
- 自动检查、下载、部署、验证

### 场景 2: 服务不响应，需要重启

```bash
bash restart.sh
```
- 自动清理端口冲突并重新启动

### 场景 3: 验证 API 是否正常工作

```bash
bash test.sh
```
- 运行完整的功能测试套件

### 场景 4: 停止服务进行维护

```bash
bash stop.sh
```
- 优雅关闭服务，可选清理镜像

### 场景 5: 仅查看日志

```bash
docker logs neurx-api-server -f
```
- 实时查看容器日志

---

## 🛠️ 脚本参数和环境变量

### deploy.sh 可配置项

通过修改 `docker-compose.yml` 中的环境变量：

```yaml
neurx-api:
  environment:
    NEURX_INFER_DEVICE: cpu              # cpu 或 gpu
    NEURX_S_PORT: 8000                   # 服务端口
    NEURX_CPU_THREADS: 8                 # CPU 线程数
    NEURX_CHAT_MAX_NEW_TOKENS: 2048      # 最大 token 数
```

### 模型配置

在 `docker-compose.yml` 中修改卷挂载：

```yaml
volumes:
  - /model/Qwen2.5-0.5B-Instruct:/models/default
```

---

## 📊 脚本执行流程图

```
启动 deploy.sh
    │
    ├─→ 检查 Docker ─→ ✓ 已安装
    │
    ├─→ 检查 docker-compose ─→ ✓ 已安装
    │
    ├─→ 检查模型文件 ─→ ✓ 文件存在
    │
    ├─→ 清理端口 ─→ ✓ 端口就绪
    │
    ├─→ 构建镜像 ─→ ✓ 镜像准备
    │
    ├─→ 启动容器 ─→ ✓ 容器运行
    │
    ├─→ 等待初始化 ─→ ✓ 服务就绪
    │
    ├─→ 健康检查 ─→ ✓ 响应正常
    │
    └─→ 显示文档 ─→ ✓ 部署完成 🎉
```

---

## ⚠️ 故障排查

### 脚本无法执行

```bash
# 检查权限
ls -lh deploy.sh

# 添加执行权限
chmod +x deploy.sh
```

### Docker 命令找不到

```bash
# 安装 Docker
curl -fsSL https://get.docker.com | sh

# 添加当前用户到 docker 组 (避免 sudo)
sudo usermod -aG docker $USER
newgrp docker
```

### 模型文件不存在

```bash
# 脚本会自动提示下载，或手动下载：
docker compose --profile download up download-model
```

### 端口被占用

```bash
# 脚本会自动清理，或手动清理：
lsof -i :8000
kill -9 <PID>
```

---

## 📈 性能监控

### 查看容器资源使用

```bash
docker stats neurx-api-server
```

### 查看实时日志

```bash
docker logs neurx-api-server -f
```

### 查看容器信息

```bash
docker ps -a | grep neurx
docker inspect neurx-api-server
```

---

## 🔄 更新和升级

### 更新镜像

```bash
# 1. 停止服务
docker compose down

# 2. 重建镜像
docker build -t neurx:latest .

# 3. 重新启动
docker compose --profile api up -d neurx-api
```

### 更新配置

```bash
# 1. 编辑 docker-compose.yml
# 2. 执行
docker compose --profile api restart neurx-api
```

---

## 📚 相关文档

- [QUICK_START.md](QUICK_START.md) - 快速开始指南
- [DEPLOYMENT_COMPLETE.md](DEPLOYMENT_COMPLETE.md) - 完整部署指南
- [docker/README.md](docker/README.md) - Docker 构建详情
- [config/frontend_backend_binding.json](config/frontend_backend_binding.json) - API 配置

---

## ✨ 特点总结

| 脚本 | 用途 | 运行时间 | 复杂度 |
|------|------|---------|--------|
| `deploy.sh` | 完整部署 | 5-10 分钟 | ⭐⭐⭐ |
| `test.sh` | 功能测试 | 2-3 分钟 | ⭐⭐ |
| `restart.sh` | 服务重启 | 15-20 秒 | ⭐ |
| `stop.sh` | 停止服务 | 5-10 秒 | ⭐ |

---

## 🎯 核心命令速查

```bash
# 一键启动 (首次) - 最推荐
bash deploy.sh

# 启动服务 (后续)
docker compose --profile api up -d neurx-api

# 健康检查
curl http://localhost:8000/health

# 测试 API
bash test.sh

# 查看日志
docker logs neurx-api-server -f

# 重启服务
bash restart.sh

# 停止服务
bash stop.sh
```

---

**现在就试试：`bash deploy.sh` 🚀**
