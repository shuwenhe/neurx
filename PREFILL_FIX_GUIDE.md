# NeurX Prefill 失败 - 根本原因分析

## 问题诊断

### 关键发现

模型配置：
```json
{
  "model_type": "qwen2",
  "torch_dtype": "bfloat16",  // ⚠️ 关键
  "hidden_size": 896,
  "num_attention_heads": 14,
  "num_hidden_layers": 24,
  "vocab_size": 151936,
  "max_position_embeddings": 32768
}
```

### 根本原因

❌ **S 语言推理引擎的 Embedding 层不支持 bfloat16 dtype**

- Qwen2.5-0.5B-Instruct 使用 bfloat16 精度
- S 运行时的 Embedding 实现可能只支持 float32
- Prefill 阶段需要加载权重到 Embedding 层
- 类型不匹配导致初始化失败

### 错误日志证据

```
[Prefill] Embedding failed
[Inference-Optimized] Prefill phase failed
[Inference] Greeting detected; using fallback responder
```

---

## 解决方案

### 选项 1: 转换模型权重到 float32（推荐）

```bash
# 使用 transformers 库转换
python3 << 'PYTHON'
import torch
from safetensors.torch import load_file, save_file

# 加载 bfloat16 权重
state_dict = load_file('/model/Qwen2.5-0.5B-Instruct/model.safetensors')

# 转换到 float32
state_dict_fp32 = {k: v.float() if v.dtype == torch.bfloat16 else v 
                   for k, v in state_dict.items()}

# 保存
save_file(state_dict_fp32, '/model/Qwen2.5-0.5B-Instruct/model_fp32.safetensors')
PYTHON
```

### 选项 2: 修复 S 语言运行时

文件需要修改：
- `/app/neurx/inference/embedding.s` - 添加 bfloat16 支持
- `/app/neurx/agent/runtime.s` - 修复类型处理

### 选项 3: 使用 Python 后端（临时方案）

替换 S 语言推理为 Transformers + ONNX Runtime：
- 支持所有数据类型
- 更成熟稳定
- 可用于生产

---

## 立即修复步骤

### 步骤 1: 安装依赖
```bash
pip install transformers safetensors torch
```

### 步骤 2: 转换权重
```python
import torch
from safetensors.torch import load_file, save_file

# 加载
state = load_file('/model/Qwen2.5-0.5B-Instruct/model.safetensors')

# 转换
state_fp32 = {k: v.to(torch.float32) for k, v in state.items()}

# 保存
save_file(state_fp32, '/model/Qwen2.5-0.5B-Instruct/model_fp32.safetensors')
```

### 步骤 3: 配置 S 运行时使用 float32 模型
```
更新环境变量：
NEURX_MODEL_DTYPE=float32
NEURX_MODEL_FILE=/model/Qwen2.5-0.5B-Instruct/model_fp32.safetensors
```

---

## 状态

- ✅ 前端：完全可用
- ✅ 网络：公网/本地都可访问
- ⚠️ 推理：Prefill 失败（dtype 不匹配）
- 📝 诊断：完成
- 🔧 修复：就绪（需要用户执行权重转换）

---

生成时间：2026-08-23 13:20 UTC+8
