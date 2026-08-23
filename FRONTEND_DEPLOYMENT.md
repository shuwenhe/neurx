# NeurX 前后端一键部署指南

## 📋 快速开始

### 最快启动 (仅后端)
```bash
cd /app/shuwen/neurx
bash deploy.sh
```

### 完整部署 (前后端)
```bash
cd /app/shuwen/neurx
bash deploy-full.sh
```

## 🎯 部署方案对比

### 方案 1: 仅后端 (推荐用于 API 集成)
```bash
# 启动
bash deploy.sh

# 访问
curl http://localhost:8000/health
```

**优点:**
- 快速启动 (5-10 分钟)
- 资源占用少
- 适合服务器/容器部署
- 支持多种客户端集成

### 方案 2: 前后端完整 (推荐用于演示/开发)
```bash
# 启动
bash deploy-full.sh

# 访问
# 后端 API: http://localhost:8000
# 前端 Web: http://localhost:3000
```

**优点:**
- 提供即用的 Web UI
- 易于演示和测试
- 可视化配置参数
- 支持实时对话展示

## 🔧 使用 Make 命令 (推荐)

创建了新的 `Makefile.deploy` 文件，支持更简洁的命令：

### 基础命令

#### 1. 后端部署 (推荐)
```bash
make -f Makefile.deploy deploy
```

#### 2. 完整部署 (前后端)
```bash
make -f Makefile.deploy deploy-full
```

#### 3. 查看帮助
```bash
make -f Makefile.deploy help
```

### 管理命令

#### 停止服务
```bash
make -f Makefile.deploy stop
```

#### 重启服务
```bash
make -f Makefile.deploy restart
```

#### 测试 API
```bash
make -f Makefile.deploy test
```

#### 查看日志
```bash
make -f Makefile.deploy logs              # 后端日志
make -f Makefile.deploy logs-frontend     # 前端日志
```

#### 查看状态
```bash
make -f Makefile.deploy status
```

#### 清理环境
```bash
make -f Makefile.deploy clean
```

## 📂 前端项目结构

```
frontend/
├── index.html           # 单页应用入口
├── package.json         # Node.js 项目配置
├── vite.config.js       # Vite 构建配置
├── Dockerfile           # Docker 容器配置
├── .gitignore          # Git 忽略文件
└── dist/               # 构建输出目录
```

### 前端特性

✨ **完整的 Web UI:**
- 📝 实时聊天界面
- ⚙️ 参数配置面板
- 📊 模型信息展示
- 🎨 现代化设计
- 📱 响应式布局

✨ **参数控制:**
- 🌡️ Temperature (0.0-2.0)
- 📏 Max Tokens (10-2048)
- 🎯 Top P (0.0-1.0)
- 👑 Top K (1-100)

✨ **实时反馈:**
- ✅ 后端连接状态指示
- 💬 消息流式显示
- ⏳ 加载状态显示
- ❌ 错误处理提示

## 📖 API 集成

### Python 示例

```python
import requests

url = "http://localhost:8000/v1/chat/completions"
headers = {"Content-Type": "application/json"}
payload = {
    "model": "default",
    "messages": [
        {"role": "user", "content": "Hello!"}
    ],
    "max_tokens": 100,
    "temperature": 0.7
}

response = requests.post(url, headers=headers, json=payload)
print(response.json())
```

### JavaScript 示例

```javascript
const response = await fetch('http://localhost:8000/v1/chat/completions', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    model: 'default',
    messages: [{ role: 'user', content: 'Hello!' }],
    max_tokens: 100,
    temperature: 0.7
  })
});

const data = await response.json();
console.log(data.choices[0].message.content);
```

### cURL 示例

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "hello"}],
    "max_tokens": 100
  }'
```

## 🐛 故障排查

### 问题 1: 后端无法启动

**症状:** `curl http://localhost:8000/health` 无响应

**解决:**
```bash
# 1. 检查 Docker 运行状态
docker ps | grep neurx

# 2. 查看详细日志
docker logs neurx-api-server

# 3. 清理并重新启动
bash stop.sh
bash deploy.sh
```

### 问题 2: 端口被占用

**症状:** `Address already in use`

**解决:**
```bash
# 自动清理
bash deploy.sh  # 脚本会自动清理

# 或手动清理
lsof -i :8000
kill -9 <PID>
```

### 问题 3: 前端无法连接后端

**症状:** 前端显示"后端离线"

**解决:**
```bash
# 1. 检查后端是否运行
docker ps | grep neurx-api

# 2. 测试后端 API
curl http://localhost:8000/health

# 3. 检查网络配置
docker network ls
```

### 问题 4: 内存不足

**症状:** 容器频繁退出

**解决:**
```bash
# 检查系统资源
free -h
docker stats

# 调整参数 (docker-compose.yml)
# 减少 NEURX_CPU_THREADS 或 NEURX_CHAT_MAX_NEW_TOKENS
```

## 🚀 部署场景

### 场景 1: 本地开发测试

```bash
# 启动后端
make -f Makefile.deploy deploy

# 开发前端 (另一个终端)
cd frontend
npm install
npm run dev

# 访问前端
# http://localhost:5173
```

### 场景 2: 演示展示

```bash
# 完整部署前后端
make -f Makefile.deploy deploy-full

# 访问 Web UI
# http://localhost:3000
```

### 场景 3: 生产部署

```bash
# 完整清理和部署
make -f Makefile.deploy production

# 配置反向代理 (Nginx/Apache)
# 后端: localhost:8000 -> your.api.com
# 前端: localhost:3000 -> your.web.com
```

### 场景 4: 仅 API 服务

```bash
# 启动后端
make -f Makefile.deploy deploy-backend

# 通过 API 集成到其他应用
# Python/Node.js/Go 等客户端调用
```

## 📊 性能优化

### 后端优化

在 `docker-compose.yml` 中调整:

```yaml
environment:
  - NEURX_CPU_THREADS=8          # 增加 CPU 线程
  - NEURX_CHAT_MAX_NEW_TOKENS=2048  # 增加最大输出
  - NEURX_INFER_DEVICE=gpu       # 切换到 GPU (如可用)
```

### 前端优化

在 `frontend/vite.config.js` 中:

```javascript
build: {
  minify: 'terser',           // 压缩输出
  sourcemap: false,           // 禁用源映射
  rollupOptions: {
    output: {
      manualChunks: undefined  // 优化分割
    }
  }
}
```

## 🔐 安全建议

1. **API 认证**
   ```bash
   # 添加 API Key 验证
   # 修改后端配置或 Nginx 配置
   ```

2. **HTTPS**
   ```bash
   # 使用 Nginx 反向代理
   # 配置 SSL 证书
   ```

3. **防火墙**
   ```bash
   # 限制端口访问
   ufw allow 3000
   ufw allow 8000
   ```

4. **环境变量**
   ```bash
   # 使用 .env 文件管理敏感信息
   # 不在源码中硬编码
   ```

## 📞 支持和文档

### 相关文档
- [ONE_CLICK_DEPLOY.md](ONE_CLICK_DEPLOY.md) - 快速参考
- [QUICK_START.md](QUICK_START.md) - 详细指南
- [DEPLOY_SCRIPTS.md](DEPLOY_SCRIPTS.md) - 脚本文档

### 命令速查

```bash
# 一键启动
bash deploy-full.sh

# 或使用 Make
make -f Makefile.deploy deploy-full

# 查看帮助
make -f Makefile.deploy help
```

### 常用命令

```bash
make -f Makefile.deploy status           # 服务状态
make -f Makefile.deploy logs             # 查看日志
make -f Makefile.deploy test             # 测试 API
make -f Makefile.deploy restart          # 重启服务
make -f Makefile.deploy stop             # 停止服务
make -f Makefile.deploy clean            # 清理环境
```

---

**祝您使用愉快！** 🎉
