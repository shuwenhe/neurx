# 🚀 NeurX 完整部署方案

**当前状态**: ✅ 所有模型就绪，可以立即部署

---

## 📍 您的模型位置

```
/model/
├── Qwen2.5-0.5B-Instruct          ✅ 已就绪 (943 MB)
│   ├── model.safetensors          (权重)
│   ├── config.json                (配置)
│   ├── tokenizer.json             (分词器)
│   ├── tokenizer_config.json
│   └── generation_config.json
│
└── Qwen2.5-VL-7B                  ✅ 已就绪 (15 GB)
    ├── model-00001-of-00005.safetensors
    ├── model-00002-of-00005.safetensors
    ├── model-00003-of-00005.safetensors
    ├── model-00004-of-00005.safetensors
    ├── model-00005-of-00005.safetensors
    ├── config.json
    ├── tokenizer.json
    └── ...其他配置文件
```

---

## 🎯 3 种部署方式

### 方式 A：快速启动（推荐 👈）

```bash
# 进入 NeurX 目录
cd /home/shuwen/shuwen/neurx

# 一键启动文本推理服务（端口 8000）
make start-inference-service

# 在另一个终端启动 VL 服务（端口 8001）
make start-vl-inference
```

**立即测试:**
```bash
# 文本模型测试
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "你好"}]}'

# VL 模型测试
curl http://localhost:8001/health
```

---

### 方式 B：使用启动脚本

```bash
# 进入 NeurX 目录
cd /home/shuwen/shuwen/neurx

# 赋予执行权限
chmod +x start_inference_service.sh

# 运行脚本（选择选项 1/2/3）
./start_inference_service.sh

# 或直接指定选项
./start_inference_service.sh 1    # 启动文本模型
./start_inference_service.sh 2    # 启动 VL 模型
./start_inference_service.sh 3    # 启动两个服务
```

---

### 方式 C：分步式手动部署

```bash
cd /home/shuwen/shuwen/neurx

# 步骤 1: 验证 VL 模型
make verify-vl-model

# 步骤 2: 构建推理引擎
make build-local-inference
make build-vl-inference

# 步骤 3: 启动服务
make start-inference-service      # 终端 1
make start-vl-inference           # 终端 2

# 步骤 4: 测试 API
chmod +x test_api.sh
./test_api.sh                     # 完整 API 测试套件
```

---

## 📊 部署架构图

```
┌──────────────────────────────────────────────────────────────────┐
│                       您的模型文件                                  │
│  /model/Qwen2.5-0.5B-Instruct  +  /model/Qwen2.5-VL-7B          │
└────────────────────┬─────────────────────────────┬────────────────┘
                     │                             │
                     ↓                             ↓
        ┌────────────────────────┐   ┌────────────────────────┐
        │  文本推理引擎            │   │  VL 推理引擎           │
        │  production_inference   │   │  vl_inference_engine   │
        │  Engine.ir             │   │  .ir                   │
        └────────┬───────────────┘   └──────────┬─────────────┘
                 │                              │
                 │  HTTP Server                 │  HTTP Server
                 │  Rest API                    │  Rest API
                 │  OpenAI Protocol             │  OpenAI Protocol
                 ↓                              ↓
        ┌────────────────────────┐   ┌────────────────────────┐
        │  端口 8000              │   │  端口 8001             │
        │  http://localhost:8000 │   │  http://localhost:8001 │
        └────────┬───────────────┘   └──────────┬─────────────┘
                 │                              │
                 ↓                              ↓
        ┌────────────────────────┐   ┌────────────────────────┐
        │  API 客户端 1           │   │  API 客户端 2          │
        │  - curl                │   │  - curl                │
        │  - Python requests     │   │  - Python requests     │
        │  - JavaScript fetch    │   │  - JavaScript fetch    │
        └────────────────────────┘   └────────────────────────┘
```

---

## 🔗 API 使用示例

### 1️⃣ 文本模型 (port 8000)

**基础对话:**
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen2.5-0.5B-Instruct",
    "messages": [
      {"role": "user", "content": "请介绍一下自己"}
    ],
    "temperature": 0.7,
    "max_tokens": 512
  }'
```

**Python 客户端:**
```python
import requests

response = requests.post(
    'http://localhost:8000/v1/chat/completions',
    json={
        'messages': [{'role': 'user', 'content': '你好'}],
        'max_tokens': 100,
        'temperature': 0.7
    }
)

print(response.json()['choices'][0]['message']['content'])
```

**流式输出:**
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "写一首诗"}],
    "stream": true
  }'
```

---

### 2️⃣ VL 多模态模型 (port 8001)

**单图像分析:**
```bash
curl -X POST http://localhost:8001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "这张图片中有什么?"}
    ],
    "images": ["/path/to/image.jpg"],
    "max_tokens": 512
  }'
```

**多图像对比:**
```bash
curl -X POST http://localhost:8001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "比较这两张图片的区别"}
    ],
    "images": [
      "/path/to/image1.jpg",
      "/path/to/image2.jpg"
    ],
    "max_tokens": 512
  }'
```

---

## 🧪 完整测试步骤

### 快速验证（5 分钟）

```bash
# 1. 启动服务（终端 1）
cd /home/shuwen/shuwen/neurx
make start-inference-service

# 2. 健康检查（终端 2）
curl http://localhost:8000/health
curl http://localhost:8001/health

# 3. 简单测试
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "你好"}]}'
```

### 完整测试（15 分钟）

```bash
# 1. 启动两个服务（需要两个终端）
# 终端 1
make start-inference-service

# 终端 2
make start-vl-inference

# 3. 在第三个终端运行测试脚本
chmod +x test_api.sh
./test_api.sh 5    # 运行全部测试

# 或选择性测试
./test_api.sh 1    # 文本模型测试
./test_api.sh 4    # 性能测试
```

---

## ⚙️ 配置说明

### 文本模型配置

修改 `deploy/deployment_config.yaml`:

```yaml
# 模型路径
model:
  model_dir: "/model/Qwen2.5-0.5B-Instruct"
  precision: "bfloat16"

# 推理配置
inference:
  backend: "cpu"
  batch_size: 1
  max_seq_length: 2048
  use_paged_attention: true
  
# API 配置
api:
  port: 8000
  host: "0.0.0.0"
  streaming: true
```

### VL 模型配置

修改 `deploy/vl_deployment_config.yaml`:

```yaml
model:
  local_dir: "/model/Qwen2.5-VL-7B"
  weights_precision: "bfloat16"

inference:
  backend: "cpu"
  max_images: 16
  image_size: 448

api:
  port: 8001
  streaming: true
```

---

## 📈 性能调优

### CPU 优化

```yaml
inference:
  use_paged_attention: true          # 启用页式 attention
  enable_kv_cache: true              # 启用 KV 缓存
  batch_size: 4                      # 调整批大小
  num_threads: 16                    # CPU 线程数
```

### 内存优化

```yaml
inference:
  kv_cache_dtype: "int8"             # 使用 int8 KV 缓存
  max_num_cached_tokens: 4096        # 限制缓存大小
  kv_cache_allocation: "lazy"        # 延迟分配
```

---

## 🐛 故障排查

### 问题 1: 端口被占用

```bash
# 查看占用端口的进程
lsof -i :8000
lsof -i :8001

# 杀死进程
kill -9 <PID>

# 或使用不同端口
# 编辑 Makefile，修改 INFERENCE_PORT
```

### 问题 2: 模型加载缓慢

```bash
# 增加日志详情查看加载进度
tail -f artifacts/logs/inference_service_*.log

# 检查磁盘 IO
iostat -x 1 10

# 检查内存使用
free -h
```

### 问题 3: API 返回 500 错误

```bash
# 查看完整错误日志
cat artifacts/logs/inference_service_*.log | tail -100

# 重启服务
# Ctrl+C 停止
# 重新运行 make start-inference-service
```

---

## 📚 文件清单

### 核心文件

```
/home/shuwen/shuwen/neurx/
├── deploy/
│   ├── deployment_config.yaml          ✅ 文本模型配置（已更新）
│   ├── vl_deployment_config.yaml       ✅ VL 模型配置（已更新）
│   ├── local_deployment.s              ✅ 部署脚本
│   └── model_downloader.s              ✅ 模型下载脚本
│
├── inference/
│   ├── production_inference_engine.s   ✅ 文本推理引擎
│   ├── inference_server.s              ✅ 服务器框架
│   ├── openai_protocol.s               ✅ OpenAI 协议支持
│   └── ...其他推理组件
│
├── Makefile                             ✅ 构建系统
├── QUICK_DEPLOY_GUIDE.md               ✅ 快速部署指南（新建）
├── start_inference_service.sh          ✅ 启动脚本（新建）
├── test_api.sh                         ✅ API 测试脚本（新建）
└── artifacts/
    ├── build/
    │   ├── production_inference_engine/
    │   │   └── production_inference_engine.ir  ✅ 已编译
    │   └── vl_inference/
    │       └── vl_inference_engine.ir         ✅ 已编译
    └── logs/                           📝 服务日志
```

---

## 💡 最佳实践

✅ **推荐做法:**
- 使用 `make start-inference-service` 启动服务
- 在不同终端运行不同的服务
- 定期检查 `artifacts/logs/` 中的日志
- 使用 `test_api.sh` 进行定期测试
- 在生产环境使用 Docker/K8s 容器化

❌ **避免做法:**
- 不要同时在多个节点运行相同模型
- 不要忽视内存和 CPU 监控
- 不要直接修改已编译的 .ir 文件
- 不要在生产中使用 CPU 后端处理大量请求

---

## 📞 快速参考

| 操作 | 命令 |
|------|------|
| 启动文本服务 | `make start-inference-service` |
| 启动 VL 服务 | `make start-vl-inference` |
| 检查健康状态 | `curl http://localhost:8000/health` |
| 查看日志 | `tail -f artifacts/logs/inference_service_*.log` |
| 停止服务 | `Ctrl+C` |
| 运行测试 | `./test_api.sh` |
| 完整部署 | `./start_inference_service.sh 3` |

---

## 🎉 下一步

1. **立即启动**: `make start-inference-service`
2. **测试 API**: `curl http://localhost:8000/health`
3. **发送请求**: 使用前面的 curl 或 Python 示例
4. **监控性能**: 检查 `artifacts/logs/` 中的日志
5. **生产部署**: 使用 Docker 或 Kubernetes

---

**祝您部署成功！🚀**

有任何问题，请参考文件中的故障排查部分或查看完整的 QUICK_DEPLOY_GUIDE.md
