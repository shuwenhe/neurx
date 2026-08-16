# NeurX REST API Server 使用指南

## 📋 概览

NeurX REST API Server 是一个 OpenAI 兼容的 HTTP API 服务，用于访问 NeurX 推理引擎。

**特性**：
- ✅ OpenAI-compatible API (`/v1/chat/completions`)
- ✅ Automatic model management
- ✅ Health check endpoint
- ✅ Full API documentation (Swagger UI)
- ✅ Python CLI client
- ✅ cURL/Postman support

---

## 🚀 快速开始（3步）

### 第 1 步: 安装依赖

```bash
pip install fastapi uvicorn pydantic requests
```

### 第 2 步: 启动服务

```bash
cd /app/shuwen/neurx/api
chmod +x start_api_server.sh
./start_api_server.sh

# 或直接运行
python3 neurx_api_server.py
```

**预期输出**：
```
╔════════════════════════════════════════════════════════════════╗
🚀 NeurX REST API Server Starting
╚════════════════════════════════════════════════════════════════╝
  Model: Qwen2.5-0.5B-Instruct
  Host: 0.0.0.0
  Port: 8000

📚 API Documentation: http://localhost:8000/docs
```

### 第 3 步: 测试 API

```bash
# 方式 1: 使用 CLI 客户端
python3 /app/shuwen/neurx/api/neurx_client.py --chat "Hello, how are you?"

# 方式 2: 使用 cURL
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen2.5-0.5B-Instruct",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 128
  }'

# 方式 3: 打开浏览器
# 访问: http://localhost:8000/docs
# 或: http://localhost:8000/redoc
```

---

## 📡 API 端点

### 健康检查

**请求**：
```bash
curl http://localhost:8000/health
```

**响应**：
```json
{
  "status": "healthy",
  "model": "Qwen2.5-0.5B-Instruct",
  "model_path": "/app/shuwen/model/Qwen2.5-0.5B-Instruct",
  "timestamp": "2026-08-16T10:30:00.123456",
  "api_version": "v1"
}
```

### 列表模型

**请求**：
```bash
curl http://localhost:8000/v1/models
```

**响应**：
```json
{
  "object": "list",
  "data": [
    {
      "id": "Qwen2.5-0.5B-Instruct",
      "object": "model",
      "created": 1692216600,
      "owned_by": "neurx"
    }
  ]
}
```

### 聊天完成（OpenAI 兼容）

**端点**: `POST /v1/chat/completions`

**请求格式**：
```json
{
  "model": "Qwen2.5-0.5B-Instruct",
  "messages": [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "What is machine learning?"}
  ],
  "temperature": 0.7,
  "top_p": 0.9,
  "max_tokens": 256,
  "stream": false
}
```

**响应格式**：
```json
{
  "id": "chatcmpl-abc123def456",
  "object": "chat.completion",
  "created": 1692216600,
  "model": "Qwen2.5-0.5B-Instruct",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Machine learning is a subset of artificial intelligence..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 15,
    "completion_tokens": 128,
    "total_tokens": 143
  }
}
```

### 文本补全（遗留端点）

**端点**: `POST /v1/completions`

**请求**：
```json
{
  "prompt": "Once upon a time",
  "max_tokens": 50,
  "temperature": 0.7
}
```

**响应**：
```json
{
  "object": "text_completion",
  "model": "Qwen2.5-0.5B-Instruct",
  "choices": [
    {
      "text": ", there was a young girl...",
      "index": 0,
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 4,
    "completion_tokens": 50,
    "total_tokens": 54
  }
}
```

---

## 🛠️ 命令行客户端使用

### 健康检查

```bash
python3 neurx_client.py --health
```

### 列表模型

```bash
python3 neurx_client.py --models
```

### 单次聊天

```bash
# 基本用法
python3 neurx_client.py --chat "What is AI?"

# 自定义参数
python3 neurx_client.py --chat "Explain quantum computing" \
  --max-tokens 256 \
  --temperature 0.5 \
  --model "Qwen2.5-0.5B-Instruct"
```

### 交互式聊天

```bash
python3 neurx_client.py --interactive

# 输出:
# 💬 Entering interactive mode (type 'exit' to quit)
#
# You: Hello, how are you?
# Assistant: I'm doing well, thank you for asking...
#
# You: Tell me about machine learning
# Assistant: Machine learning is...
#
# You: exit
# 👋 Goodbye!
```

### 自定义服务器地址

```bash
python3 neurx_client.py --url http://remote-server:8000 --chat "Hello"
```

---

## 🔗 使用示例

### Python 客户端

```python
import requests

# Chat completion
response = requests.post("http://localhost:8000/v1/chat/completions", json={
    "model": "Qwen2.5-0.5B-Instruct",
    "messages": [{"role": "user", "content": "What is AI?"}],
    "max_tokens": 150
})

result = response.json()
print(result["choices"][0]["message"]["content"])
```

### JavaScript/Node.js

```javascript
const response = await fetch("http://localhost:8000/v1/chat/completions", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    model: "Qwen2.5-0.5B-Instruct",
    messages: [{ role: "user", content: "Hello" }],
    max_tokens: 100
  })
});

const result = await response.json();
console.log(result.choices[0].message.content);
```

### cURL

```bash
# 简单请求
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen2.5-0.5B-Instruct",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }' | jq .

# 保存到文件
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d @request.json > response.json
```

---

## ⚙️ 配置

### 环境变量

```bash
# 服务器配置
export API_HOST=0.0.0.0          # 监听地址
export API_PORT=8000             # 监听端口

# 模型配置
export NEURX_MODEL_PATH=/app/shuwen/model/Qwen2.5-0.5B-Instruct

# 启动服务
python3 neurx_api_server.py
```

### Docker 运行

```bash
# 构建镜像
docker build -f Dockerfile -t neurx-api:latest .

# 运行容器
docker run -d \
  -p 8000:8000 \
  -e NEURX_MODEL_PATH=/app/model \
  -v /app/shuwen/model:/app/model \
  --name neurx-api-server \
  neurx-api:latest

# 查看日志
docker logs -f neurx-api-server

# 停止服务
docker stop neurx-api-server
```

---

## 📊 性能优化

### 启用推理引擎优化

```bash
# 在启动服务前设置环境变量
export NEURX_KV_CACHE_ENABLED=1
export NEURX_BATCH_SIZE=32
export NEURX_CONTINUOUS_BATCHING=1
export NEURX_FUSED_OPS=1

python3 neurx_api_server.py
```

### 性能监控

```bash
# 查看 API 服务资源使用
watch -n 1 'ps aux | grep neurx_api_server'

# 监控推理延迟（查看服务器日志）
tail -f neurx_api.log | grep "Generating"
```

---

## 🐛 故障排查

### 问题 1: 连接被拒绝

```bash
# 症状
# Error: Failed to connect to http://localhost:8000

# 解决方案
# 1. 检查服务是否运行
ps aux | grep neurx_api_server

# 2. 检查端口是否正确
netstat -tuln | grep 8000

# 3. 启动服务
python3 /app/shuwen/neurx/api/neurx_api_server.py
```

### 问题 2: 模型路径错误

```bash
# 症状
# "Model file not found"

# 解决方案
ls -lh /app/shuwen/model/Qwen2.5-0.5B-Instruct/model.safetensors

# 如果不存在，下载模型
python -m huggingface_hub download Qwen/Qwen2.5-0.5B-Instruct \
  --local-dir /app/shuwen/model/Qwen2.5-0.5B-Instruct
```

### 问题 3: 推理超时

```bash
# 症状
# Inference timeout (>120s)

# 解决方案
# 1. 增加超时时间（编辑 neurx_api_server.py）
# 2. 减少 max_tokens 参数
# 3. 检查系统资源是否充足
free -h  # 检查内存
df -h    # 检查磁盘空间
```

### 问题 4: 内存不足

```bash
# 症状
# MemoryError 或推理缓慢

# 解决方案 1: 禁用 KV-Cache
unset NEURX_KV_CACHE_ENABLED

# 解决方案 2: 减少批处理大小
export NEURX_BATCH_SIZE=8

# 解决方案 3: 增加系统交换空间
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

---

## 📚 API 文档

### 自动生成的文档

启动服务后，访问以下地址查看交互式 API 文档：

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **OpenAPI Schema**: http://localhost:8000/openapi.json

---

## 🔒 安全建议

### 生产部署

```bash
# 1. 绑定特定 IP 而不是 0.0.0.0
export API_HOST=127.0.0.1

# 2. 使用反向代理（Nginx）
# 3. 启用 HTTPS/TLS
# 4. 添加认证（API Key）
# 5. 启用请求限流（Rate Limiting）
# 6. 启用 CORS 安全策略
```

### 示例 Nginx 配置

```nginx
server {
    listen 443 ssl;
    server_name api.neurx.example.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

## 📞 支持

遇到问题？

1. 检查日志: `tail -f /var/log/neurx-api.log`
2. 访问 API 文档: http://localhost:8000/docs
3. 查看源代码: `/app/shuwen/neurx/api/`
4. 检查配置: 环境变量和 Makefile

---

**祝你使用 NeurX API 服务愉快！🚀**
