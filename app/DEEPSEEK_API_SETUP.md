# DeepSeek API 配置指南

## 🚀 快速开始

NeurX 应用现已集成 **DeepSeek V3** 免费 API，提供高速稳定的 AI 推理服务。

### 1. 注册并获取 API Key

访问 DeepSeek 官网注册账号并获取免费 API Key：

**官网：** https://platform.deepseek.com

1. 点击右上角「注册/登录」
2. 完成注册后，进入「API Keys」页面
3. 点击「创建 API Key」
4. 复制生成的 API Key（格式：`sk-xxxxxxxxxxxxxxxx`）

**免费额度：**
- 每天 **1000 万 tokens** 免费额度
- 响应速度：**1-3 秒**（vs 原 NPU 推理 90-150 秒）
- 无需服务器维护

### 2. 配置环境变量

编辑 `neurx/app/run_with_llm.sh` 或在终端设置：

```bash
export NEURX_API_KEY="sk-your-api-key-here"
```

**推荐方式**：在 `~/.bashrc` 或 `~/.zshrc` 中添加：

```bash
# DeepSeek API Configuration
export NEURX_API_KEY="sk-xxxxxxxxxxxxxxxx"
```

### 3. 启动应用

```bash
cd /home/shuwen/shuwen/neurx/app
./run_with_llm.sh
```

应用将自动使用 DeepSeek API 进行推理。

## 🔧 高级配置

### 切换到其他 API 提供商

如需使用其他 OpenAI 兼容 API（如 SiliconFlow、通义千问等），可设置：

```bash
export NEURX_REMOTE_BASE_URL="https://api.siliconflow.cn"
export NEURX_REMOTE_CHAT_PATH="/v1/chat/completions"
export NEURX_REMOTE_MODEL="Qwen/Qwen2.5-7B-Instruct"
export NEURX_API_KEY="sk-your-siliconflow-key"
```

### 关闭远程模式（使用本地 NPU）

```bash
export NEURX_REMOTE_ONLY=0
```

## 📊 性能对比

| 指标 | 原 NPU 方案 | DeepSeek V3 API |
|------|-------------|------------------|
| 响应时间 | 90-150 秒 | 1-3 秒 ⚡ |
| 稳定性 | 频繁超时 | 高稳定 ✅ |
| 免费额度 | 无限制（本地） | 1000万 tokens/天 |
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
curl -X POST https://api.deepseek.com/v1/chat/completions \
  -H "Authorization: Bearer $NEURX_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-chat",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

## 🌐 其他免费 API 推荐

1. **SiliconFlow**：新用户 2000 万 tokens
   - https://siliconflow.cn

2. **通义千问**：每月 100 万 tokens
   - https://dashscope.aliyun.com

3. **智谱 AI**：每月 500 万 tokens
   - https://open.bigmodel.cn

---

**更新时间：** 2026-05-22  
**适用版本：** NeurX App v0.1+
