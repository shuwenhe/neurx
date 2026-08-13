# 🚀 Qwen2.5-VL-7B 快速启动指南

**Vision-Language Model** | **7 Billion Parameters** | **多模态理解**

> ✨ 支持**图文混合输入**，能理解和生成图像相关的文本

---

## ⚡ 3 步快速启动 (5 分钟)

### Step 1️⃣: 验证模型文件 (1 分钟)

```bash
cd /home/shuwen/shuwen/neurx
make verify-vl-model
```

**预期输出**:
```
🔍 Verifying VL model files...
✓ All required files present
👁️  Vision encoder files ready
📚 Language model files ready

Total files: 15/15
Estimated size: ~14 GB
```

### Step 2️⃣: 构建推理引擎 (2-3 分钟)

```bash
make build-vl-inference
```

**预期输出**:
```
🔨 Building Vision-Language inference engine...
✓ S code compiled to IR
✓ Vision encoder module ready
✓ Language model module ready
✓ VL bridge initialized
```

### Step 3️⃣: 启动服务 (30 秒)

```bash
make start-vl-inference
```

**预期输出**:
```
🚀 Starting Vision-Language inference service...
API Server: http://0.0.0.0:8000
Model: Qwen2.5-VL-7B
Status: Ready for inference
[服务运行中...]
```

---

## 📋 完整步骤

```bash
# 1. 验证模型
make verify-vl-model

# 2. 构建推理引擎
make build-vl-inference

# 3. 启动服务
make start-vl-inference

# 4. 在另一个终端测试
# 见下面的 API 调用示例
```

---

## 🌐 API 使用示例

### 📝 纯文本对话 (不含图像)

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen2.5-VL-7B",
    "messages": [
      {
        "role": "user",
        "content": "什么是糖尿病?"
      }
    ],
    "temperature": 0.7,
    "max_tokens": 256
  }'
```

**响应示例**:
```json
{
  "id": "chatcmpl-xxx",
  "object": "chat.completion",
  "model": "Qwen2.5-VL-7B",
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "糖尿病是一种慢性代谢疾病，主要特征是血糖升高..."
      },
      "finish_reason": "stop"
    }
  ]
}
```

### 🖼️ 图文对话 - 图像描述

```bash
curl -X POST http://localhost:8000/v1/vision/describe \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "file:///path/to/medical/image.jpg",
    "prompt": "请详细描述这张医学图像中的内容",
    "max_tokens": 512,
    "language": "chinese"
  }'
```

**响应示例**:
```json
{
  "description": "这是一张显示糖尿病血糖监测数据的图表。图表显示...",
  "objects_detected": [
    {"name": "血糖仪", "confidence": 0.92},
    {"name": "血液样本", "confidence": 0.87}
  ],
  "tokens_used": 156
}
```

### ❓ 视觉问答 (VQA)

```bash
curl -X POST http://localhost:8000/v1/vision/vqa \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "file:///path/to/xray.jpg",
    "question": "这张 X 光片中可以看到什么病变?",
    "max_tokens": 256
  }'
```

**响应示例**:
```json
{
  "answer": "X 光片显示右肺有明显的渗出影，可能....",
  "confidence": 0.85,
  "processing_time_ms": 3500
}
```

### 🖼️ 多图像理解

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen2.5-VL-7B",
    "messages": [
      {
        "role": "user",
        "content": "比较这两张医学图像的区别",
        "images": [
          {"url": "file:///path/to/image1.jpg"},
          {"url": "file:///path/to/image2.jpg"}
        ]
      }
    ],
    "max_tokens": 512
  }'
```

**响应示例**:
```json
{
  "id": "chatcmpl-xxx",
  "choices": [{
    "message": {
      "content": "第一张图显示...，第二张图显示...，主要区别是..."
    }
  }]
}
```

### 📸 Base64 图像输入

```bash
# 将图像转换为 Base64
image_base64=$(base64 -w0 /path/to/image.jpg)

curl -X POST http://localhost:8000/v1/vision/describe \
  -H "Content-Type: application/json" \
  -d "{
    \"image_base64\": \"$image_base64\",
    \"image_format\": \"jpeg\",
    \"prompt\": \"这是什么?\"
  }"
```

---

## ⚙️ 配置文件

主配置文件: `vl_deployment_config.yaml`

**关键参数**:

```yaml
# 视觉编码器
vision_encoder:
  type: "vit"
  patch_size: 14
  image_size: 448
  
# 语言模型
architecture:
  hidden_size: 3584
  num_layers: 28
  vocab_size: 152064
  
# 推理设置
inference:
  batch_size: 1
  max_sequence_length: 4096
  enable_kv_cache: true
  
# API 服务
deployment:
  port: 8000
  timeout: 300
  
# 图像处理
image_processing:
  size: [448, 448]
  max_images: 16
```

修改配置示例:

```bash
# 修改最大图像数
sed -i 's/max_images: 16/max_images: 8/' vl_deployment_config.yaml

# 修改序列长度
sed -i 's/max_sequence_length: 4096/max_sequence_length: 2048/' vl_deployment_config.yaml

# 启用量化 (减少内存)
sed -i "s/method: \"none\"/method: \"int8\"/" vl_deployment_config.yaml
```

重启服务以应用新配置:
```bash
make start-vl-inference
```

---

## 📊 性能指标 (预期)

### 硬件要求

| 配置 | 值 |
|------|-----|
| CPU | 16+ 核 |
| 内存 | 32+ GB |
| 磁盘 | 20 GB+ 可用 |
| 网络 | 100 Mbps+ |

### 推理速度 (16 核 CPU)

| 操作 | 速度 |
|------|------|
| 单张图像编码 | 1-2s |
| 文本生成 (Prefill) | 10-20 tok/s |
| 文本生成 (Decode) | 3-7 tok/s |
| 首个 Token | 2-5s |
| 整体响应 | 5-10s |

### 内存使用

| 组件 | 内存 |
|------|------|
| 模型权重 | 14 GB |
| KV 缓存 | 1-2 GB |
| 工作集 | 2-3 GB |
| **总计** | **17-19 GB** |

---

## 🛠️ 故障排查

### 问题 1: "Model files not found"

**原因**: 模型文件不完整

**解决**:
```bash
# 检查文件
ls -lh /home/shuwen/shuwen/model/Qwen2.5-VL-7B/

# 应该看到所有 15 个文件:
# model-00001-of-00005.safetensors (3GB+)
# model-00002-of-00005.safetensors (3GB+)
# model-00003-of-00005.safetensors (3GB+)
# model-00004-of-00005.safetensors (3GB+)
# model-00005-of-00005.safetensors 等

# 验证文件
make verify-vl-model
```

### 问题 2: "Out of Memory"

**原因**: 内存不足 (需要 32GB, 但只有 16GB)

**解决方案**:

```bash
# 启用量化 (减少 75% 内存)
sed -i "s/method: \"none\"/method: \"int8\"/" vl_deployment_config.yaml

# 减少最大图像数
sed -i 's/max_images: 16/max_images: 4/' vl_deployment_config.yaml

# 减少批处理大小
sed -i 's/batch_size: 1/batch_size: 1/' vl_deployment_config.yaml  # 已是最小

# 启用虚拟内存 (临时, 性能下降)
sudo swapon -a
```

### 问题 3: "Port already in use"

**原因**: 8000 端口被占用

**解决**:
```bash
# 查找占用进程
lsof -i :8000

# 杀死进程
kill -9 <PID>

# 或使用不同端口
export NEURX_API_PORT=8001
make start-vl-inference
```

### 问题 4: "Vision encoder error"

**原因**: 图像处理配置错误

**解决**:
```bash
# 检查图像文件
file /path/to/image.jpg

# 支持的格式: JPEG, PNG, WebP, BMP
# 最大大小: 50 MB

# 验证图像配置
cat vl_deployment_config.yaml | grep -A 10 "image_processing:"
```

### 问题 5: "Slow inference (>15s per request)"

**原因**: CPU 不足或配置不优化

**解决**:
```bash
# 启用 CPU 亲和性
export NEURX_CPU_AFFINITY=true

# 减少最大 tokens
sed -i 's/max_new_tokens: 512/max_new_tokens: 256/' vl_deployment_config.yaml

# 禁用前缀缓存 (取决于场景)
sed -i 's/enable_prefix_cache: true/enable_prefix_cache: false/' vl_deployment_config.yaml

# 监控 CPU 使用
top -bn1 | grep "Cpu(s)"
```

---

## 📚 相关文档

- [VL 部署配置详情](vl_deployment_config.yaml)
- [VL 模型验证工具](vl_model_verifier.s)
- [VL 推理引擎](vl_inference_engine.s)
- [完整 NeurX 文档](DEPLOYMENT_GUIDE.md)

---

## ✅ 验收清单

部署成功标志:

- [ ] 模型文件完整 (15 个文件)
  ```bash
  ls -1 /home/shuwen/shuwen/model/Qwen2.5-VL-7B/ | wc -l  # 应显示 15
  ```

- [ ] 验证通过
  ```bash
  make verify-vl-model
  # 应显示 ✓ 所有文件检查通过
  ```

- [ ] 服务启动成功
  ```bash
  make start-vl-inference &
  sleep 5
  curl http://localhost:8000/health
  # 应返回 200 OK
  ```

- [ ] 能处理纯文本请求
  ```bash
  curl -X POST http://localhost:8000/v1/chat/completions \
    -d '{"messages":[{"role":"user","content":"hello"}]}'
  # 应返回 JSON 响应
  ```

- [ ] 能处理图像请求
  ```bash
  curl -X POST http://localhost:8000/v1/vision/describe \
    -d '{"image_url":"file:///path/to/image.jpg","prompt":"describe"}'
  # 应返回描述性文本
  ```

---

## 🎯 下一步

### 基础使用
- ✅ 启动服务
- ✅ 发送文本请求
- ✅ 发送图像请求

### 进阶配置
- 调整性能参数
- 启用量化
- 配置多GPU (如有)
- 设置监控告警

### 生产部署
- Docker 容器化
- Kubernetes 集群
- 负载均衡
- 灾难恢复

---

**最后更新**: 2026-08-13  
**版本**: 1.0  
**语言**: 100% 纯 S  

*由 NeurX 推理框架提供*
