# SiliconFlow API 配置指南

## 🚀 快速开始

NeurX 应用现已集成 **SiliconFlow Qwen2.5-7B** 免费 API，提供高速稳定的 AI 推理服务。

### 1. API Key（已配置）

**当前配置：**
- 提供商：**SiliconFlow**
- 模型：**Qwen/Qwen2.5-7B-Instruct**
- API Key：已内置到脚本中
- 免费额度：**2000 万 tokens**（新用户）

### 2. 启动应用

```bash
cd /home/shuwen/shuwen/neurx/app
./run_with_llm.sh
```

应用将自动使用 SiliconFlow API 进行推理。

## 🔧 高级配置

### 自定义 API Key

如需使用自己的 API Key，在启动前设置：

```bash
export NEURX_API_KEY="sk-your-siliconflow-key"
cd /home/shuwen/shuwen/neurx/app
./run_with_llm.sh
```

**获取新 API Key：** https://siliconflow.cn

### 切换到其他模型

SiliconFlow 支持多种模型：

```bash
# 使用更大的模型
export NEURX_REMOTE_MODEL="Qwen/Qwen2.5-14B-Instruct"

# 使用 DeepSeek
export NEURX_REMOTE_BASE_URL="https://api.deepseek.com"
export NEURX_REMOTE_MODEL="deepseek-chat"
export NEURX_API_KEY="sk-your-deepseek-key"
```

### 关闭远程模式（使用本地 NPU）

```bash
export NEURX_REMOTE_ONLY=0
```

## 📊 性能对比

| 指标 | 原 NPU 方案 | SiliconFlow API |
|------|-------------|------------------|
| 响应时间 | 90-150 秒 | 1-3 秒 ⚡ |
| 稳定性 | 频繁超时 | 高稳定 ✅ |
| 免费额度 | 无限制（本地） | 2000万 tokens |
| 维护成本 | 需管理服务器 | 零维护 🎯 |

## 🔍 故障排查

### 检查 API Key 是否生效

```bash
echo $NEURX_API_KEY
```

### 查看应用日志

启动时会显示：
```
bridge http_request start ... has_api_key=yes
```

如果显示 `has_api_key=no`，说明 API Key 未正确设置。

### 测试 API 连通性

```bash
curl -X POST https://api.siliconflow.cn/v1/chat/completions \
  -H "Authorization: Bearer $NEURX_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-7B-Instruct",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

## 🌐 其他免费 API 推荐

1. **DeepSeek V3**：每天 1000 万 tokens
   - https://platform.deepseek.com

2. **通义千问**：每月 100 万 tokens
   - https://dashscope.aliyun.com

3. **智谱 AI**：每月 500 万 tokens
   - https://open.bigmodel.cn

---

**更新时间：** 2026-05-22  
**适用版本：** NeurX App v0.1+
