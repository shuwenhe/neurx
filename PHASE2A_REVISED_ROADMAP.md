# Phase 2A Revised Roadmap (2026-07-29)

**核心原则**: Golden Test First - 每个模块必须与 PyTorch 数值对齐

---

## 🎯 重新定义的成熟度评估

| 层级 | 名称 | 标准 | 工具 |
|------|------|------|------|
| **Infrastructure** | 工程框架 | ✅ **已完成** | Git, Makefile, 编译器 |
| **Numerical Kernel** | 数值内核 | ❌ **未完成** | Transformer, Loss, Optimizer |
| **Verification** | 数值验证 | ⏳ **进行中** | Golden Test 框架 |

---

## 📋 6 阶段渐进式实施计划

### 🔹 阶段 1: 模型加载 (2-3 天)

**目标**: 从 safetensors 正确加载权重到内存

```
Qwen2.5-0.5B-Instruct/model.safetensors
    ↓
parse_safetensors_metadata()
    ↓
load_tensor("model.layers.0.self_attn.q_proj.weight")
    ↓
verify_shape(expected=[896, 896], actual=?)
    ↓
verify_dtype(expected=float32/float16)
```

**验证点**:
```python
# PyTorch
import torch
model = torch.load("model.safetensors")
layer0_q = model["model.layers.0.self_attn.q_proj.weight"]
print(layer0_q.shape)  # [896, 896]
print(layer0_q[0, 0])  # 某个具体值

# NeurX
tensor = load_tensor("model.layers.0.self_attn.q_proj.weight")
assert tensor.shape == [896, 896]
assert abs(tensor.data[0] - PyTorch值) < 1e-5
```

**交付物**:
- `posttrain/model/safetensors_loader.s` (真实实现)
- `make test-numerical-loader` (验证 10 个随机权重值)

---

### 🔹 阶段 2: 单层 Forward (3-5 天)

**目标**: 只实现 Layer 0，不做全部 24 层

```
input_ids: [1, 512]  # batch=1, seq=512
    ↓
Embedding(input_ids)
    ↓
Layer 0 (Attention + MLP)
    ↓
logits: [1, 512, 151936]
```

**子模块验证顺序**:
1. **Embedding**: `token_id → 896-dim vector`
   ```python
   # Golden Test
   pytorch_embed = model.embed_tokens(torch.tensor([1234]))
   neurx_embed = embedding_forward([1234])
   assert np.allclose(pytorch_embed, neurx_embed, atol=1e-4)
   ```

2. **RMSNorm**: `normalize(hidden_states)`
   ```python
   pytorch_norm = layer0.input_layernorm(hidden)
   neurx_norm = rms_norm_forward(hidden, layer0.norm.weight)
   assert np.allclose(pytorch_norm, neurx_norm, atol=1e-4)
   ```

3. **RoPE**: `rotary_position_embedding(q, k)`
   ```python
   pytorch_rope = apply_rotary_pos_emb(q, cos, sin)
   neurx_rope = rope_apply(q, cos, sin)
   assert np.allclose(pytorch_rope, neurx_rope, atol=1e-4)
   ```

4. **Attention**: `multi_head_attention(q, k, v)`
   ```python
   pytorch_attn = layer0.self_attn(hidden)[0]
   neurx_attn = multi_head_attention_forward(hidden, ...)
   assert np.allclose(pytorch_attn, neurx_attn, atol=1e-3)
   ```

5. **MLP**: `mlp(hidden_states)`
   ```python
   pytorch_mlp = layer0.mlp(hidden)
   neurx_mlp = mlp_forward(hidden, ...)
   assert np.allclose(pytorch_mlp, neurx_mlp, atol=1e-3)
   ```

6. **完整 Layer 0**:
   ```python
   pytorch_out = model.layers[0](hidden)[0]
   neurx_out = transformer_block_forward(hidden, layer0_weights)
   assert np.allclose(pytorch_out, neurx_out, atol=1e-3)
   ```

**交付物**:
- `posttrain/model/transformer_layers.s` (真实实现)
- `make test-numerical-layer0` (与 PyTorch 对齐)
- Golden outputs 保存在 `tests/golden/layer0/`

---

### 🔹 阶段 3: CrossEntropy Loss (1-2 天)

**目标**: 确保 Loss 计算与 PyTorch 完全一致

```
logits: [batch, seq, vocab]
labels: [batch, seq]
    ↓
softmax(logits)
    ↓
log(softmax)
    ↓
nll_loss(log_probs, labels)
    ↓
loss: scalar
```

**验证点**:
```python
# PyTorch
import torch.nn.functional as F
loss_pytorch = F.cross_entropy(
    logits.view(-1, 151936), 
    labels.view(-1)
)

# NeurX
loss_neurx = cross_entropy_loss_batch(logits, labels)

assert abs(loss_pytorch - loss_neurx) < 1e-5
```

**交付物**:
- `posttrain/loss/cross_entropy.s` (真实实现)
- `make test-numerical-loss` (10 个随机样本验证)

---

### 🔹 阶段 4: Backward Pass (5-7 天)

**目标**: 先不做完整 Transformer，只验证简单 Linear 的梯度

```
Linear(x, W)
    ↓
loss = MSE(output, target)
    ↓
backward()
    ↓
dW, db
```

**验证点**:
```python
# PyTorch
linear = nn.Linear(896, 896)
linear.weight.requires_grad = True
output = linear(x)
loss = F.mse_loss(output, target)
loss.backward()
grad_pytorch = linear.weight.grad

# NeurX
output_neurx = linear_forward(x, W)
loss_neurx = mse_loss(output_neurx, target)
grad_neurx = linear_backward(loss_neurx, x, W)

assert np.allclose(grad_pytorch, grad_neurx, atol=1e-4)
```

**子验证**:
1. Linear Forward ✓
2. Linear Backward (dW)
3. Linear Backward (dx)
4. Chain Rule 验证

**交付物**:
- `posttrain/autograd/backward.s` (基础梯度)
- `make test-numerical-grad` (梯度检查)

---

### 🔹 阶段 5: LoRA Integration (3-4 天)

**目标**: 在 Linear 梯度正确的基础上，加入 LoRA

```
Linear(x, W_frozen) 
    +
LoRA(x, A, B)  # trainable
    ↓
output = Linear(x, W) + scaling * (x @ A @ B)
    ↓
backward()
    ↓
dA, dB  # 只更新这两个
```

**验证点**:
```python
# PyTorch (PEFT)
from peft import LoraConfig, get_peft_model
config = LoraConfig(r=8, lora_alpha=16, target_modules=["q_proj"])
model = get_peft_model(base_model, config)
loss = model(x).loss
loss.backward()
lora_A_grad = model.base_model.model.layers[0].self_attn.q_proj.lora_A.weight.grad

# NeurX
lora = create_lora_linear(in_dim=896, out_dim=896, rank=8)
output = lora_linear_forward(x, W, lora.A, lora.B, scaling=2.0)
loss = cross_entropy(output, labels)
grad_A, grad_B = lora_linear_backward(loss, x, lora.A, lora.B)

assert np.allclose(lora_A_grad, grad_A, atol=1e-4)
```

**交付物**:
- `posttrain/lora/lora_layer.s` (真实梯度)
- `make test-numerical-lora` (LoRA 梯度验证)

---

### 🔹 阶段 6: 完整 24 层训练 (5-7 天)

**目标**: 组合所有模块

```
24 × Transformer Layers (with LoRA)
    ↓
CrossEntropy Loss
    ↓
Backward (chain through 24 layers)
    ↓
AdamW Optimizer
    ↓
Update LoRA weights
```

**验证点**:
```python
# PyTorch Full Training Step
optimizer = torch.optim.AdamW(lora_params, lr=5e-4)
output = model(input_ids, labels=labels)
loss = output.loss
loss.backward()
optimizer.step()

print(f"Loss: {loss.item()}")
print(f"Grad norm: {torch.nn.utils.clip_grad_norm_(lora_params, 1.0)}")

# NeurX Full Training Step
state = training_step(state, batch, config)
print(f"Loss: {state.current_loss}")
print(f"Grad norm: {state.grad_norm}")

# 验证
assert abs(pytorch_loss - neurx_loss) < 0.01  # 允许更大误差
assert abs(pytorch_grad_norm - neurx_grad_norm) < 0.1
```

**子模块**:
1. AdamW 优化器
2. Learning rate scheduler
3. Gradient clipping
4. LoRA adapter 保存

**交付物**:
- `posttrain/training/phase2a_trainer.s` (真实版本)
- `make test-numerical-e2e` (端到端验证)
- Adapter 文件生成验证

---

## 🧪 Golden Test 框架

### 新增 Makefile 目标

```makefile
# 顶层数值验证目标
test-numerical: test-numerical-loader test-numerical-layer0 test-numerical-loss

# 阶段 1: 权重加载
test-numerical-loader:
	python scripts/generate_golden_loader.py
	make run-neurx-loader
	python scripts/verify_golden_loader.py

# 阶段 2: Layer 0 Forward
test-numerical-layer0:
	python scripts/generate_golden_layer0.py
	make run-neurx-layer0
	python scripts/verify_golden_layer0.py

# 阶段 3: Loss
test-numerical-loss:
	python scripts/generate_golden_loss.py
	make run-neurx-loss
	python scripts/verify_golden_loss.py
```

### Golden Test 流程

```
1. Python (PyTorch) 生成 Golden Output
   ↓
   保存到 tests/golden/*.npy
   
2. NeurX (S Runtime) 运行相同输入
   ↓
   保存输出到 tests/output/*.npy
   
3. Python 比较误差
   ↓
   Report: ✓ Passed / ✗ Failed (误差 > 阈值)
```

---

## 📊 新的验证层级

| 层级 | 工具 | 验证内容 | 状态 |
|------|------|---------|------|
| **L1** | `make test-posttrain` | 基础设施 | ✅ 完成 |
| **L2** | `make test-numerical-loader` | 权重加载 | ⏳ 待实现 |
| **L3** | `make test-numerical-layer0` | Layer 0 Forward | ⏳ 待实现 |
| **L4** | `make test-numerical-loss` | CrossEntropy | ⏳ 待实现 |
| **L5** | `make test-numerical-grad` | 梯度计算 | ⏳ 待实现 |
| **L6** | `make test-numerical-lora` | LoRA 梯度 | ⏳ 待实现 |
| **L7** | `make test-numerical-e2e` | 完整训练步 | ⏳ 待实现 |

---

## 🎯 成功标准 (修订版)

Phase 2A 只有在满足以下条件时才算**真正完成**:

```
✅ 所有 7 个 test-numerical-* 测试通过
✅ 误差控制在合理范围 (< 1e-3 for forward, < 1e-4 for grad)
✅ 生成的 adapter_model.safetensors 可被 Python PEFT 加载
✅ 推理输出合理
```

---

## 💡 核心改进

**之前**: 一次实现 24 层 → 难以调试，无法验证  
**现在**: 渐进式实现，每步都有 Golden Test

**之前**: "代码写完就是完成"  
**现在**: "与 PyTorch 数值对齐才是完成"

**之前**: Mock Loss 就够了  
**现在**: 真实 CrossEntropy，误差 < 1e-5

---

## 📌 时间估算

| 阶段 | 时间 | 累计 |
|------|------|------|
| 1. 模型加载 | 2-3 天 | 3 天 |
| 2. Layer 0 Forward | 3-5 天 | 8 天 |
| 3. CrossEntropy | 1-2 天 | 10 天 |
| 4. Backward | 5-7 天 | 17 天 |
| 5. LoRA | 3-4 天 | 21 天 |
| 6. 完整训练 | 5-7 天 | **~28 天 (4周)** |

**现实预估**: 考虑调试和优化，可能需要 **5-6 周**。

---

这个 Roadmap 更符合工程实际，每个阶段都可以独立验证，失败时容易定位问题。
