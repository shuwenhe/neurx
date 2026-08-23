# NeurX 完全栈部署方案

## 📌 概述

本方案提供了**完整的前后端一键部署解决方案**，可快速启动 NeurX 推理服务及其 Web UI。

## 🎯 新增功能

### 1️⃣ 前后端一键部署脚本
- **文件**: `deploy-full.sh`
- **功能**: 自动启动后端 API 和前端 Web 服务
- **用法**: `bash deploy-full.sh`

### 2️⃣ Make 命令简化部署
- **文件**: `Makefile.deploy`
- **功能**: 提供简洁的 Make 命令
- **用法**: 
  ```bash
  make -f Makefile.deploy help      # 查看帮助
  make -f Makefile.deploy deploy    # 启动后端
  make -f Makefile.deploy deploy-full  # 启动前后端
  ```

### 3️⃣ 完整的 Web UI 前端
- **目录**: `frontend/`
- **框架**: Vanilla JS (无依赖版本可用)
- **功能**: 
  - 实时聊天界面
  - 参数配置面板
  - 模型信息展示
  - 响应式设计

### 4️⃣ 完整的部署文档
- **文件**: `FRONTEND_DEPLOYMENT.md`
- **内容**: 详细的前后端部署指南

---

## 🚀 快速开始

### 方式 1: 脚本部署 (推荐)

**仅启动后端:**
```bash
bash deploy.sh
# 后端 API: http://localhost:8000
```

**启动前后端:**
```bash
bash deploy-full.sh
# 后端 API: http://localhost:8000
# 前端 Web: http://localhost:3000
```

### 方式 2: Make 命令部署

**查看所有命令:**
```bash
make -f Makefile.deploy help
```

**启动后端:**
```bash
make -f Makefile.deploy deploy
```

**启动前后端:**
```bash
make -f Makefile.deploy deploy-full
```

---

## 📁 文件结构

```
neurx/
├── deploy.sh                      # 后端一键部署脚本
├── deploy-full.sh                 # 前后端一键部署脚本
├── Makefile.deploy                # Make 命令配置
├── FRONTEND_DEPLOYMENT.md         # 前后端部署指南
├── FULLSTACK_DEPLOYMENT.md        # 本文件
├── ONE_CLICK_DEPLOY.md            # 快速参考
├── QUICK_START.md                 # 详细指南
├── DEPLOY_SCRIPTS.md              # 脚本文档
├── docker-compose.yml             # 后端部署配置
├── docker-compose-full.yml        # 前后端部署配置
├── docker/                        # Docker 配置目录
│   ├── entrypoint.sh
│   └── nginx.conf
└── frontend/                      # 前端项目目录
    ├── index.html                 # Web UI 应用
    ├── package.json               # 项目配置
    ├── vite.config.js             # Vite 配置
    ├── Dockerfile                 # 容器镜像配置
    └── .gitignore
```

---

## 🔄 部署方案对比

### 方案 A: 仅后端 (API 模式)

**启动方式:**
```bash
bash deploy.sh
```

**访问方式:**
- API: `http://localhost:8000`
- 健康检查: `curl http://localhost:8000/health`

**适用场景:**
- ✅ 服务器/容器部署
- ✅ API 集成到其他应用
- ✅ 性能优先
- ✅ 资源受限环境

**优点:**
- 启动快速 (5-10 分钟)
- 资源占用少 (~500MB)
- 支持多种客户端集成
- 易于扩展和定制

### 方案 B: 前后端完整 (Web 模式)

**启动方式:**
```bash
bash deploy-full.sh
```

**访问方式:**
- 前端 Web UI: `http://localhost:3000`
- 后端 API: `http://localhost:8000`

**适用场景:**
- ✅ 演示和展示
- ✅ 快速原型开发
- ✅ 测试和验证
- ✅ 用户友好界面

**优点:**
- 提供即用的 Web UI
- 可视化参数配置
- 实时聊天展示
- 无需额外开发

---

## 📊 启动对比表

| 方面 | 仅后端 | 前后端完整 |
|------|--------|----------|
| 启动命令 | `bash deploy.sh` | `bash deploy-full.sh` |
| 启动时间 | ~7 分钟 | ~10 分钟 |
| 资源占用 | ~500MB | ~700MB |
| 后端 API | ✅ http://localhost:8000 | ✅ http://localhost:8000 |
| 前端 UI | ❌ | ✅ http://localhost:3000 |
| 集成开发 | ✅ | ✅ |
| 演示展示 | ⚠️ 需自行集成 | ✅ 开箱即用 |
| 依赖复杂度 | 低 | 中等 |

---

## 🛠️ 常用命令速查

### 启动服务

```bash
# 启动后端
bash deploy.sh

# 启动前后端
bash deploy-full.sh

# 使用 Make 启动
make -f Makefile.deploy deploy-full
```

### 管理服务

```bash
# 重启服务
bash restart.sh
make -f Makefile.deploy restart

# 停止服务
bash stop.sh
make -f Makefile.deploy stop

# 查看服务状态
make -f Makefile.deploy status

# 查看日志
docker logs neurx-api-server -f
docker logs neurx-frontend -f
```

### 测试验证

```bash
# 测试 API
bash test.sh
make -f Makefile.deploy test

# 健康检查
curl http://localhost:8000/health

# 测试前端
curl http://localhost:3000
```

---

## 🎨 前端功能展示

### 主界面

```
┌─────────────────────────────────────────────────────┐
│          🤖 NeurX 模型推理 Web UI                 │
│       利用 AI 的力量进行智能对话                    │
└─────────────────────────────────────────────────────┘

┌──────────────────────┐  ┌──────────────────────┐
│      对话面板        │  │    参数配置面板      │
│                      │  │                      │
│ 👤 用户问题          │  │ 🌡️ Temperature:0.7 │
│ 🤖 AI 回复           │  │ 📏 Max Tokens:200   │
│ 👤 用户跟进          │  │ 🎯 Top P: 0.9      │
│ 🤖 AI 解答           │  │ 👑 Top K: 40       │
│                      │  │                      │
│ 📤 [发送] 🗑️ [清空]  │  │ 📊 模型信息        │
└──────────────────────┘  └──────────────────────┘
```

### 主要特性

- ✨ **实时聊天**: 流式显示对话内容
- ⚙️ **参数控制**: 可视化调整推理参数
- 📊 **状态监控**: 实时显示后端连接状态
- 🎨 **现代设计**: 响应式布局, 适配多设备
- 🌐 **多语言**: 支持中英文输入
- 📱 **移动友好**: 手机浏览器完全支持

---

## 🔧 配置与定制

### 修改后端参数

编辑 `docker-compose.yml` 或 `docker-compose-full.yml`:

```yaml
environment:
  - NEURX_INFER_DEVICE=cpu        # cpu 或 gpu
  - NEURX_CPU_THREADS=8           # CPU 线程数
  - NEURX_CHAT_MAX_NEW_TOKENS=2048  # 最大输出长度
  - NEURX_S_PORT=8000             # API 端口
```

### 修改前端配置

编辑 `frontend/vite.config.js`:

```javascript
export default defineConfig({
  server: {
    port: 3000,  // 修改前端端口
    proxy: {
      target: 'http://backend.com:8000'  // 修改后端地址
    }
  }
})
```

### 自定义 Web UI

前端项目支持完全定制:

```bash
cd frontend
npm install              # 安装依赖
npm run dev             # 开发模式
npm run build           # 构建生产版本
```

---

## 📈 性能优化建议

### 后端优化

```bash
# 增加 CPU 线程 (如果 CPU 核心多)
NEURX_CPU_THREADS=16

# 使用 GPU (如果有 NVIDIA GPU)
NEURX_INFER_DEVICE=gpu

# 增加最大输出长度
NEURX_CHAT_MAX_NEW_TOKENS=4096
```

### 前端优化

```bash
# 生产构建
cd frontend && npm run build

# 配置 Nginx 反向代理和缓存
# 启用 Gzip 压缩
# 使用 CDN 加速
```

---

## 🐛 常见问题

### Q1: 如何仅使用 API，不需要前端？

**A:** 运行 `bash deploy.sh` 只启动后端，然后使用任何 HTTP 客户端调用 API。

### Q2: 前端无法连接后端怎么办？

**A:** 
```bash
# 检查后端是否运行
docker ps | grep neurx

# 测试后端连接
curl http://localhost:8000/health

# 查看前端日志
docker logs neurx-frontend
```

### Q3: 如何修改前端的默认参数？

**A:** 编辑 `frontend/index.html` 的 `app.state` 对象。

### Q4: 如何部署到云服务器？

**A:** 参考 [FRONTEND_DEPLOYMENT.md](FRONTEND_DEPLOYMENT.md) 中的生产部署部分。

---

## 📚 完整文档导航

| 文档 | 用途 | 场景 |
|------|------|------|
| [ONE_CLICK_DEPLOY.md](ONE_CLICK_DEPLOY.md) | 快速参考 | 快速启动 |
| [QUICK_START.md](QUICK_START.md) | 详细指南 | 完整学习 |
| [DEPLOY_SCRIPTS.md](DEPLOY_SCRIPTS.md) | 脚本文档 | 脚本使用 |
| [FRONTEND_DEPLOYMENT.md](FRONTEND_DEPLOYMENT.md) | 前后端指南 | 前后端部署 |
| [FULLSTACK_DEPLOYMENT.md](FULLSTACK_DEPLOYMENT.md) | 本文件 | 架构概览 |

---

## ✅ 部署检查清单

- ☐ Docker 已安装
- ☐ 模型文件存在
- ☐ 脚本有执行权限
- ☐ 端口 8000 和 3000 未被占用
- ☐ 运行 `bash deploy-full.sh`
- ☐ 访问 http://localhost:3000
- ☐ 测试聊天功能
- ☐ 查看后端日志验证

---

## 🎯 部署场景示例

### 场景 1: 本地快速测试

```bash
cd /app/shuwen/neurx
bash deploy-full.sh
# 等待 10 分钟
# 访问 http://localhost:3000
```

### 场景 2: API 服务集成

```bash
bash deploy.sh
# 从其他应用调用
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"default","messages":[{"role":"user","content":"hello"}]}'
```

### 场景 3: 云服务器部署

```bash
# 1. SSH 连接到服务器
ssh user@your.server.com

# 2. 克隆项目
git clone <repo> neurx
cd neurx

# 3. 启动部署
bash deploy-full.sh

# 4. 配置反向代理
# 使用 Nginx 或 Apache

# 5. 访问
# http://your.domain.com
```

---

## 🚀 下一步

### 立即启动

```bash
cd /app/shuwen/neurx
bash deploy-full.sh
```

### 或选择方案

- **仅 API**: `bash deploy.sh`
- **完整部署**: `bash deploy-full.sh`
- **使用 Make**: `make -f Makefile.deploy deploy-full`

---

## 📞 支持

遇到问题？

1. 查看 [FRONTEND_DEPLOYMENT.md](FRONTEND_DEPLOYMENT.md) 的故障排查部分
2. 检查日志: `docker logs neurx-api-server`
3. 测试连接: `curl http://localhost:8000/health`

---

**祝部署顺利！** 🎉
