# NeurX 推理服务 - 一键启动指南

## 最快启动方式 (仅需一条命令)

```bash
bash deploy.sh
```

**就这样！** 脚本会自动完成以下所有工作：
- ✅ 检查 Docker 和依赖
- ✅ 验证模型文件
- ✅ 清理端口冲突
- ✅ 构建 Docker 镜像
- ✅ 启动推理服务
- ✅ 验证服务健康
- ✅ 显示 API 文档

---

## 详细步骤

### 前置条件检查清单

```bash
# 1. 检查 Docker 已安装
docker --version

# 2. 检查 docker-compose 已安装 (Docker 1.29+)
docker compose version

# 3. 检查模型文件存在
ls -lh /model/Qwen2.5-0.5B-Instruct/model.safetensors
```

### 一键启动

```bash
cd /app/shuwen/neurx
bash deploy.sh
```

### 手动启动 (如需逐步操作)

```bash
# 1. 进入项目目录
cd /app/shuwen/neurx

# 2. 构建镜像 (首次)
docker build -t neurx:latest .

# 3. 启动 API 服务
docker compose --profile api up -d neurx-api

# 4. 等待服务初始化 (30-60 秒)
sleep 10

# 5. 验证服务
curl http://localhost:8000/health
```

---

## API 使用示例

### 健康检查

```bash
curl http://localhost:8000/health
```

返回:
```json
{"status":"ok","backend":"neurx-s-cpu"}
```

### 聊天 API (OpenAI 兼容格式)

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [
      {"role": "user", "content": "你好，请介绍一下自己"}
    ],
    "max_tokens": 100
  }'
```

### Python 调用

```python
import requests
import json

response = requests.post(
    'http://localhost:8000/v1/chat/completions',
    json={
        'model': 'default',
        'messages': [
            {'role': 'user', 'content': 'hello'}
        ],
        'max_tokens': 50
    },
    headers={'Content-Type': 'application/json'}
)
print(json.dumps(response.json(), indent=2))
```

### Node.js 调用

```javascript
const axios = require('axios');

async function chat(message) {
  const response = await axios.post(
    'http://localhost:8000/v1/chat/completions',
    {
      model: 'default',
      messages: [{ role: 'user', content: message }],
      max_tokens: 50
    }
  );
  console.log(response.data.choices[0].message.content);
}

chat('hello');
```

---

## 常见问题排查

### 问题 1: 端口 8000 被占用

```bash
# 查看占用进程
lsof -i :8000

# 停止占用进程
kill -9 <PID>

# 或使用 deploy.sh 会自动处理
```

### 问题 2: 模型文件不存在

```bash
# 检查模型目录
ls -la /model/Qwen2.5-0.5B-Instruct/

# 如果不存在，使用 deploy.sh 下载 (自动提示)
# 或手动下载:
docker compose --profile download up download-model
```

### 问题 3: 容器无法启动

```bash
# 查看容器日志
docker logs neurx-api-server -f

# 查看容器状态
docker ps -a

# 重新启动
docker compose restart neurx-api
```

### 问题 4: 连接超时 (公网)

```bash
# 检查本地连接
curl http://localhost:8000/health  # 应该正常

# 检查公网 IP 和防火墙
ping 8.140.241.141
# 检查云平台安全组/防火墙规则是否允许 8000 端口
```

---

## 停止和管理

### 停止服务

```bash
docker compose down
```

### 查看服务状态

```bash
docker ps | grep neurx
```

### 查看实时日志

```bash
docker logs neurx-api-server -f
```

### 重启服务

```bash
docker compose restart neurx-api
```

### 完全清理 (包括镜像)

```bash
docker compose down
docker rmi neurx:latest
```

---

## 配置调整

### 修改推理参数

编辑 `docker-compose.yml`:

```yaml
neurx-api:
  environment:
    NEURX_S_PORT: 8000              # 服务端口
    NEURX_CPU_THREADS: 8            # CPU 线程数
    NEURX_CHAT_MAX_NEW_TOKENS: 2048 # 最大生成 token
```

然后重启:
```bash
docker compose restart neurx-api
```

### 更换模型

1. 停止服务:
```bash
docker compose down
```

2. 下载新模型到 `/model/` 目录

3. 修改 `docker-compose.yml` 卷挂载:
```yaml
volumes:
  - /model/<新模型名>:/models/default
```

4. 重新启动:
```bash
docker compose --profile api up -d neurx-api
```

---

## 性能优化建议

### CPU 优化

- 增加 `NEURX_CPU_THREADS` 数量 (根据 CPU 核心数)
- 监控 CPU 使用率: `top` 或 `htop`

### 内存优化

- 模型缓存配置在推理过程中自动管理
- 监控内存: `free -h` 或 `docker stats`

### GPU 支持 (如果可用)

```bash
# 启用 GPU 模式
docker compose --profile gpu up -d neurx-gpu

# 检查 GPU 使用
nvidia-smi
```

---

## 完整命令参考

| 目的 | 命令 |
|------|------|
| 一键启动 | `bash deploy.sh` |
| 启动 API | `docker compose --profile api up -d neurx-api` |
| 启动 GPU | `docker compose --profile gpu up -d neurx-gpu` |
| 下载模型 | `docker compose --profile download up download-model` |
| 停止服务 | `docker compose down` |
| 查看日志 | `docker logs neurx-api-server -f` |
| 健康检查 | `curl http://localhost:8000/health` |
| 测试 API | `curl -X POST http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" -d '{"model":"default","messages":[{"role":"user","content":"hello"}],"max_tokens":20}'` |

---

## 获取帮助

### 查看日志获取更多信息

```bash
# 显示最后 50 行日志
docker logs neurx-api-server --tail 50

# 实时跟踪日志
docker logs neurx-api-server -f

# 显示完整日志
docker logs neurx-api-server > logs.txt
```

### 检查服务健康

```bash
# 详细健康检查
curl -v http://localhost:8000/health

# 检查 API 响应
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"default","messages":[{"role":"user","content":"test"}],"max_tokens":5}' \
  | python3 -m json.tool
```

---

## 下一步

- 📖 查看 [DEPLOYMENT_COMPLETE.md](DEPLOYMENT_COMPLETE.md) 了解完整部署细节
- 🔧 查看 [config/frontend_backend_binding.json](config/frontend_backend_binding.json) 了解 API 配置
- 💬 查看 [docker/README.md](docker/README.md) 了解 Docker 构建详情

---

**🎉 现在就试试: `bash deploy.sh`**
