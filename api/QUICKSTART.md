# 🚀 NeurX REST API 快速启动指南

## ✅ 服务状态

```
✓ API Server: Running on port 8888
✓ Model: Qwen2.5-0.5B-Instruct  
✓ Status: Healthy
```

**API 地址**: `http://localhost:8888`

---

## 🎯 3分钟快速开始

### 方式 1: 使用 CLI 客户端（推荐）

```bash
# 1️⃣ 健康检查
python3 /app/shuwen/neurx/api/neurx_client.py --url http://localhost:8888 --health

# 2️⃣ 单次聊天
python3 /app/shuwen/neurx/api/neurx_client.py --url http://localhost:8888 \
  --chat "What is machine learning?"

# 3️⃣ 交互式聊天
python3 /app/shuwen/neurx/api/neurx_client.py --url http://localhost:8888 --interactive
```

### 方式 2: 使用 cURL

```bash
# 1️⃣ 健康检查
curl http://localhost:8888/health

# 2️⃣ 聊天完成
curl -X POST http://localhost:8888/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen2.5-0.5B-Instruct",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 128
  }'

# 3️⃣ 列表模型
curl http://localhost:8888/v1/models
```

### 方式 3: 使用 Python

```python
import requests

# 发送聊天请求
response = requests.post("http://localhost:8888/v1/chat/completions", json={
    "model": "Qwen2.5-0.5B-Instruct",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 128
})

result = response.json()
print(result["choices"][0]["message"]["content"])
```

---

## 📚 API 端点参考

| 端点 | 方法 | 功能 | 示例 |
|------|------|------|------|
| `/health` | GET | 健康检查 | `curl http://localhost:8888/health` |
| `/v1/models` | GET | 列表模型 | `curl http://localhost:8888/v1/models` |
| `/v1/chat/completions` | POST | 聊天完成 | 见下方 |
| `/v1/completions` | POST | 文本补全 | 见下方 |
| `/docs` | GET | Swagger 文档 | 浏览器打开 |

### 聊天完成请求示例

```json
{
  "model": "Qwen2.5-0.5B-Instruct",
  "messages": [
    {"role": "user", "content": "What is AI?"}
  ],
  "temperature": 0.7,
  "max_tokens": 256
}
```

### 聊天完成响应示例

```json
{
  "id": "chatcmpl-abc123",
  "object": "chat.completion",
  "created": 1692216600,
  "model": "Qwen2.5-0.5B-Instruct",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "AI stands for Artificial Intelligence..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 5,
    "completion_tokens": 50,
    "total_tokens": 55
  }
}
```

---

## 🔧 服务管理

### 启动服务

```bash
# 方式 1: 使用启动脚本
cd /app/shuwen/neurx/api
./start_api_server.sh

# 方式 2: 直接运行
API_PORT=8888 python3 neurx_api_server.py

# 方式 3: 后台运行
nohup python3 neurx_api_server.py > api.log 2>&1 &
```

### 停止服务

```bash
# 杀死进程
pkill -f neurx_api_server.py

# 或释放端口
fuser -k 8888/tcp
```

### 查看日志

```bash
tail -f /tmp/neurx_api*.log
```

---

## 🎨 高级用法

### 自定义参数

```bash
# 增加生成长度
python3 /app/shuwen/neurx/api/neurx_client.py \
  --url http://localhost:8888 \
  --chat "Tell me a story" \
  --max-tokens 512 \
  --temperature 0.5

# 使用不同的采样参数
curl -X POST http://localhost:8888/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen2.5-0.5B-Instruct",
    "messages": [{"role": "user", "content": "Hello"}],
    "temperature": 0.3,
    "top_p": 0.8,
    "max_tokens": 256
  }'
```

### 批量请求

```python
import requests
import json

prompts = [
    "What is AI?",
    "Explain quantum computing",
    "Tell me about deep learning"
]

for prompt in prompts:
    response = requests.post("http://localhost:8888/v1/chat/completions", json={
        "model": "Qwen2.5-0.5B-Instruct",
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 100
    })
    result = response.json()
    print(f"Q: {prompt}")
    print(f"A: {result['choices'][0]['message']['content']}\n")
```

### 启用性能优化

```bash
# 启动服务时启用优化
export NEURX_KV_CACHE_ENABLED=1
export NEURX_BATCH_SIZE=32
export NEURX_CONTINUOUS_BATCHING=1

API_PORT=8888 python3 neurx_api_server.py
```

---

## 🌐 集成示例

### JavaScript/Node.js

```javascript
const fetch = require('node-fetch');

async function chat(message) {
  const response = await fetch('http://localhost:8888/v1/chat/completions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: 'Qwen2.5-0.5B-Instruct',
      messages: [{ role: 'user', content: message }],
      max_tokens: 128
    })
  });
  
  const data = await response.json();
  return data.choices[0].message.content;
}

// 使用
chat('Hello').then(console.log);
```

### Go

```go
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
)

func main() {
	payload := map[string]interface{}{
		"model": "Qwen2.5-0.5B-Instruct",
		"messages": []map[string]string{
			{"role": "user", "content": "Hello"},
		},
		"max_tokens": 128,
	}
	
	jsonData, _ := json.Marshal(payload)
	resp, _ := http.Post(
		"http://localhost:8888/v1/chat/completions",
		"application/json",
		bytes.NewBuffer(jsonData),
	)
	
	body, _ := ioutil.ReadAll(resp.Body)
	fmt.Println(string(body))
}
```

### Java

```java
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;

CloseableHttpClient client = HttpClients.createDefault();
HttpPost httpPost = new HttpPost("http://localhost:8888/v1/chat/completions");

String jsonBody = "{\"model\": \"Qwen2.5-0.5B-Instruct\", " +
    "\"messages\": [{\"role\": \"user\", \"content\": \"Hello\"}], " +
    "\"max_tokens\": 128}";

httpPost.setEntity(new StringEntity(jsonBody));
httpPost.setHeader("Content-Type", "application/json");

var response = client.execute(httpPost);
```

---

## 🔍 故障排查

### 问题 1: 连接被拒绝

```bash
# 检查服务是否运行
ps aux | grep neurx_api

# 检查端口
netstat -tuln | grep 8888

# 重启服务
pkill -f neurx_api_server.py
sleep 2
API_PORT=8888 python3 /app/shuwen/neurx/api/neurx_api_server.py &
```

### 问题 2: 超时

```bash
# 减少 max_tokens
python3 neurx_client.py --url http://localhost:8888 \
  --chat "Hello" --max-tokens 50

# 检查系统资源
free -h
df -h
```

### 问题 3: 模型路径错误

```bash
# 验证模型
ls -lh /app/shuwen/model/Qwen2.5-0.5B-Instruct/

# 设置正确的路径
export NEURX_MODEL_PATH=/app/shuwen/model/Qwen2.5-0.5B-Instruct
```

---

## 📊 性能指标

基于当前部署：

| 指标 | 值 |
|------|-----|
| **模型大小** | 2.4 GB |
| **推理延迟** | ~245ms |
| **吞吐量** | ~204 tokens/sec |
| **最大令牌** | 2048 |
| **并发请求** | 支持（排队处理） |

---

## 📁 文件结构

```
/app/shuwen/neurx/api/
├── neurx_api_server.py      # 主 API 服务
├── neurx_client.py          # 命令行客户端
├── start_api_server.sh      # 启动脚本
└── README.md                # 完整文档
```

---

## 🚀 下一步

1. ✅ **API 服务已启动** - 在 http://localhost:8888
2. 📖 **查看完整文档** - [README.md](README.md)
3. 🧪 **交互式 API 文档** - http://localhost:8888/docs
4. ⚡ **启用性能优化** - 查看 [DEPLOYMENT_GUIDE_CN.md](../DEPLOYMENT_GUIDE_CN.md)
5. 🐳 **Docker 部署** - 参考部署指南

---

**服务已准备就绪！🎉 开始使用 NeurX API。**
