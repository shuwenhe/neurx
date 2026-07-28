# NeurX Runtime 为中心的实现路线图 (工程架构版本)

**核心原则**: Runtime 优先 > 模型设计 | 可验证优先 > 功能完整 | 接口化优先 > 直接集成

**关键洞察**: 
- 真正决定框架寿命的是 **Runtime + Operator + Autograd + IR**
- KDA、MLA、MoonEP 都只是在 Runtime 上的应用
- PyTorch、JAX、MindSpore、TensorFlow 的本质都是 Runtime

---

## 项目结构（最终）

```
neurx/
├── runtime/                # ⭐⭐⭐⭐⭐ 核心（所有计算都这里）
│   ├── tensor/            # Tensor 定义 + 内存管理
│   ├── operator/          # MatMul, Softmax, LayerNorm, etc.
│   ├── autograd/          # Backward + Gradient computation
│   ├── optimizer/         # AdamW, SGD, etc.
│   └── checkpoint/        # Save/Load 训练状态
│
├── model/
│   ├── core/              # Embedding, RoPE
│   ├── attention/         # Interface + Standard/MLA/KDA impl
│   ├── ffn/               # Interface + Dense/MoE/LatentMoE impl
│   └── transformer.s      # Orchestration
│
├── serialization/
│   ├── safetensors/       # SafeTensors Reader
│   ├── tokenizer/         # HF-compatible tokenizer loader
│   └── hf_compat/         # HuggingFace compatibility layer
│
├── reference/             # ⭐⭐⭐ 与 HF 对齐验证工具
│   ├── export_*.py        # 导出 HF 层的中间结果
│   ├── compare_*.s        # 与 S 实现对比
│   └── tests/             # 自动化对齐测试
│
├── posttrain/
│   ├── trainer/           # 训练主循环
│   └── evaluation/        # Loss 曲线等指标
│
└── config.yaml            # 模型配置
```

---

## 为什么优先构建 Runtime？

```
当前问题:
    SafeTensors → 读数据
    Embedding → 1 步
    Attention → 1 步
    Loss → 1 步
    Backward → 1 步
    ❌ 每个地方要重新写梯度、优化器、内存管理

正确方式:
    Tensor Runtime
         ↓
    自动求导 (Autograd)
         ↓
    所有 Operator 都支持前反向传播
         ↓
    模型只负责「流程」，计算全交给 Runtime
         ↓
    以后：Embedding/Attention/MoE/KDA 都自动支持梯度
```

---

## 阶段 1 ⭐⭐⭐⭐⭐: NeurX Runtime 基础

**目标**: 能正确计算一个 Transformer Block 的前向和反向，数值与 HuggingFace 完全对齐

**验收标准**:
```
✓ Tensor 能存储、管理、操作
✓ MatMul 与 PyTorch 数值一致 (误差 < 1e-4)
✓ Softmax 与 PyTorch 数值一致
✓ LayerNorm 与 PyTorch 数值一致
✓ Backward 梯度与 PyTorch 一致 (误差 < 1e-3)
✓ AdamW 参数更新与 PyTorch 一致
```

### 1.1 Tensor 数据结构 (2-3 天)

**文件**: `runtime/tensor/tensor.s`

```s
struct Tensor {
    data: []float           // 扁平化的数据
    shape: []int            // [batch, seq_len, hidden]
    stride: []int           // 行优先或列优先
    grad: Tensor            // 梯度张量
    requires_grad: bool     // 是否需要计算梯度
    op: Operation           // 产生这个张量的操作
}

func Tensor.reshape(shape: []int) → Tensor
func Tensor.transpose(axes: []int) → Tensor
func Tensor.view(shape: []int) → Tensor
func Tensor.contiguous() → Tensor
```

**关键**:
- 支持 stride（不copy数据就能 reshape）
- 支持自动求导信息
- 支持内存高效的操作

**验证**:
- [x] 能创建张量
- [x] 能 reshape/transpose
- [x] 梯度存储正确

---

### 1.2 基础 Operator: MatMul (1-2 天)

**文件**: `runtime/operator/matmul.s`

```s
func matmul(A: Tensor, B: Tensor) → Result {
    // A: (M, K)
    // B: (K, N)
    // Result: (M, N)
    
    result = Tensor.zeros([M, N])
    for i in range(M)
        for j in range(N)
            for k in range(K)
                result[i, j] += A[i, k] * B[k, j]
    
    // 记录这个操作用于反向传播
    result.op = MatMulOp(A, B)
    return result
}
```

**验证**:
```python
# reference/export_matmul.py
import torch
A = torch.randn(128, 896)
B = torch.randn(896, 896)
result_hf = torch.matmul(A, B)
# 导出 result_hf
```

```s
# reference/compare_matmul.s
let A = load_from_file("A.bin")
let B = load_from_file("B.bin")
let result_s = matmul(A, B)
let result_hf = load_from_file("result_hf.bin")
assert allclose(result_s, result_hf, atol=1e-4)
```

**关键**:
- 支持 batched matmul
- 支持不同形状的广播
- 数值与 PyTorch 一致

---

### 1.3 基础 Operator: Softmax, LayerNorm (1-2 天)

**文件**: `runtime/operator/softmax.s`, `runtime/operator/norm.s`

```s
func softmax(x: Tensor, dim: int) → Tensor {
    // 数值稳定: x_max = max(x)
    x_shifted = x - x_max
    exp_x = exp(x_shifted)
    sum_exp = sum(exp_x)
    return exp_x / sum_exp
}

func layer_norm(x: Tensor, weight: Tensor, bias: Tensor, eps: float) → Tensor {
    // x: (batch, seq, hidden)
    mean = mean(x, axis=-1)
    var = var(x, axis=-1)
    x_norm = (x - mean) / sqrt(var + eps)
    return x_norm * weight + bias
}
```

**验证**: 与 PyTorch 对齐（误差 < 1e-5）

---

### 1.4 Autograd: Backward Graph & Chain Rule (2-3 天)

**文件**: `runtime/autograd/backward.s`

```s
interface Operation {
    func backward(grad_output: Tensor) → []Tensor {
        // 接收上层的梯度
        // 返回对输入的梯度
    }
}

struct MatMulOp: Operation {
    A: Tensor
    B: Tensor
    
    func backward(grad_output: Tensor) → []Tensor {
        grad_A = matmul(grad_output, B.T)
        grad_B = matmul(A.T, grad_output)
        return [grad_A, grad_B]
    }
}

struct SoftmaxOp: Operation {
    x: Tensor
    output: Tensor
    
    func backward(grad_output: Tensor) → []Tensor {
        // d(softmax)/dx = softmax(x) * (grad - (grad * softmax).sum())
        grad_x = output * (grad_output - (grad_output * output).sum())
        return [grad_x]
    }
}

// 自动求导
func backward(loss: Tensor) {
    loss.grad = Tensor.ones(loss.shape)
    
    queue = [loss]
    visited = {}
    
    while queue is not empty {
        tensor = queue.pop()
        
        if tensor.op is None
            continue
        
        grads = tensor.op.backward(tensor.grad)
        
        for i, input_tensor in tensor.op.inputs {
            input_tensor.grad += grads[i]
            if input_tensor not in visited {
                queue.push(input_tensor)
                visited.add(input_tensor)
            }
        }
    }
}
```

**关键**:
- 自动梯度累积
- 防止重复计算（visited 集合）
- 支持复杂计算图

**验证**:
```s
# reference/compare_backward.s
let x = Tensor.randn([32, 896], requires_grad=true)
let y = matmul(x, W) + b
let loss = y.sum()
loss.backward()
# 与 PyTorch 梯度对比
```

---

### 1.5 基础 Operator: 完整集合 (1-2 天)

**文件**: `runtime/operator/ops.s`

```
✓ MatMul
✓ Add/Sub/Mul/Div
✓ Softmax
✓ ReLU / SwiGLU / Tanh
✓ LayerNorm / RMSNorm
✓ Transpose
✓ Reshape
✓ Embedding Lookup
✓ Attention (Q @ K @ V)
✓ CrossEntropy Loss
```

每一个都支持梯度计算。

---

### 1.6 AdamW Optimizer (1-2 天)

**文件**: `runtime/optimizer/adamw.s`

```s
struct AdamW {
    lr: float                   // 学习率
    betas: (float, float)       // (beta1, beta2)
    eps: float                  // 数值稳定性
    weight_decay: float
    
    m: []{float}                // 一阶矩
    v: []{float}                // 二阶矩
}

func AdamW.step(params: []{Tensor}) {
    for i, param in params {
        if param.grad is None
            continue
        
        g = param.grad
        m[i] = beta1 * m[i] + (1 - beta1) * g
        v[i] = beta2 * v[i] + (1 - beta2) * g^2
        
        m_hat = m[i] / (1 - beta1^t)
        v_hat = v[i] / (1 - beta2^t)
        
        param -= lr * (m_hat / (sqrt(v_hat) + eps) + weight_decay * param)
    }
}
```

**验证**: 与 PyTorch AdamW 完全一致

---

### 1.7 Checkpoint & Save/Load (1-2 天)

**文件**: `runtime/checkpoint/checkpoint.s`

```s
struct TrainingCheckpoint {
    step: int
    epoch: int
    
    parameters: []Tensor
    optimizer_states: {
        m: []Tensor
        v: []Tensor
        t: int
    }
    
    loss: float
    metrics: {}
}

func save_checkpoint(path: string, checkpoint: TrainingCheckpoint) {
    // 二进制格式
    // 能快速加载
}

func load_checkpoint(path: string) → TrainingCheckpoint {
    // 恢复所有状态
}
```

**验证**: 恢复后能继续训练，loss 曲线连续

---

### 1.8 完整验证: 单个 Transformer Block (2 天)

**文件**: `reference/tests/test_block_alignment.s`

```s
// 从 HuggingFace 导出一个 Transformer Block 的全部中间值
// 在 S 中重现，逐层对比

func test_embedding_alignment() {
    // input: token ids
    // HF output: embeddings
    // S output: embeddings
    assert allclose(hf_emb, s_emb, atol=1e-5)
}

func test_attention_alignment() {
    // input: (batch, seq, hidden)
    // HF output: attention output
    // S output: attention output
    assert allclose(hf_attn, s_attn, atol=1e-4)
}

func test_mlp_alignment() {
    // input: (batch, seq, hidden)
    // HF output: mlp output
    // S output: mlp output
    assert allclose(hf_mlp, s_mlp, atol=1e-4)
}

func test_backward_alignment() {
    // 计算梯度，与 PyTorch 对比
    hf_grads = hf_block.backward(loss)
    s_grads = s_block.backward(loss)
    
    for name, grad in s_grads {
        assert allclose(hf_grads[name], grad, atol=1e-3)
    }
}
```

---

## 阶段 2 ⭐⭐⭐⭐: 单层 Transformer Block 完全对齐

**目标**: 一个完整的 Transformer Block 与 HuggingFace 完全一致

**验收标准**:
```
✓ Forward pass 对齐 (误差 < 1e-4)
✓ Backward pass 对齐 (误差 < 1e-3)
✓ 参数更新后 loss 继续下降
```

### 2.1 抽象化 Attention (1 天)

**文件**: `model/attention/attention_interface.s`

```s
interface Attention {
    func forward(Q: Tensor, K: Tensor, V: Tensor, mask: Tensor) → Tensor
    func backward(grad_output: Tensor) → (grad_Q, grad_K, grad_V)
}

struct StandardAttention: Attention {
    num_heads: int
    hidden_size: int
    
    func forward(...) → Tensor {
        scores = Q @ K.T / sqrt(head_dim)
        if mask is not None
            scores = scores + mask
        
        attn_weights = softmax(scores, axis=-1)
        output = attn_weights @ V
        return output
    }
}

struct MLAAttention: Attention {
    // 后期实现
}

struct KDAAttention: Attention {
    // 后期实现
}
```

**关键**: Transformer Block 只调用 Attention Interface，不关心具体实现

---

### 2.2 抽象化 FFN (1 天)

**文件**: `model/ffn/ffn_interface.s`

```s
interface FFN {
    func forward(x: Tensor) → Tensor
    func backward(grad_output: Tensor) → grad_x
}

struct DenseFNN: FFN {
    gate_proj: Linear
    up_proj: Linear
    down_proj: Linear
    
    func forward(x: Tensor) → Tensor {
        gate = swiglu(gate_proj(x))
        up = up_proj(x)
        return down_proj(gate * up)
    }
}

struct MoEFFN: FFN {
    // 后期实现
}

struct LatentMoEFFN: FFN {
    // 后期实现
}
```

---

### 2.3 Transformer Block (1 day)

**文件**: `model/transformer_block.s`

```s
struct TransformerBlock {
    attention: Attention       // 可以是 Standard/MLA/KDA
    ffn: FFN                   // 可以是 Dense/MoE/LatentMoE
    norm1: LayerNorm
    norm2: LayerNorm
    
    func forward(x: Tensor) → Tensor {
        // Pre-norm
        attn_out = attention.forward(norm1(x), ...)
        x = x + attn_out
        
        ffn_out = ffn.forward(norm2(x))
        x = x + ffn_out
        
        return x
    }
}
```

**关键**: Block 完全不知道 Attention/FFN 的具体实现，只调用接口

---

### 2.4 完整验证框架 (2 days)

**文件**: `reference/tests/test_block_full_cycle.s`

- [x] Forward 对齐
- [x] Backward 对齐
- [x] 优化器更新对齐
- [x] 训练 5 步，loss 下降

---

## 阶段 3 ⭐⭐⭐⭐: 完整 Qwen Forward Pass

**目标**: 24 层 Transformer + 输出 logits，与 HuggingFace 完全一致

**验收标准**:
```
✓ 完整 Forward 对齐 (误差 < 1e-4)
✓ 可以计算 loss
✓ Backward 对齐 (误差 < 1e-3)
```

### 3.1 SafeTensors 加载 (1-2 天)

**文件**: `serialization/safetensors/loader.s`

读取 Qwen2.5 model.safetensors，提取所有 24 层权重

### 3.2 HF-兼容 Tokenizer 加载 (1-2 天)

**文件**: `serialization/tokenizer/hf_tokenizer.s`

直接读 tokenizer.json，完全兼容 HuggingFace

---

### 3.3 完整训练循环 (1-2 天)

**文件**: `posttrain/trainer/train_loop.s`

```s
func train_epoch(model, data_loader, optimizer) {
    for batch in data_loader {
        input_ids = batch.input_ids
        labels = batch.labels
        
        // Forward
        logits = model.forward(input_ids)
        loss = cross_entropy(logits, labels)
        
        // Backward
        loss.backward()
        
        // Optimize
        optimizer.step()
        optimizer.zero_grad()
        
        print(f"loss={loss.item()}")
    }
}
```

**验收**:
- [x] Loss 真的下降（不是常数）
- [x] LoRA 权重真的在变化
- [x] 保存 checkpoint 可恢复

---

## 阶段 4 ⭐⭐⭐⭐: LoRA 训练

**目标**: 能用 LoRA 训练 Qwen，loss 收敛，推理正确

**验收**:
```
✓ LoRA 训练 10 步，loss 下降
✓ 权重合并后能推理
✓ 生成医学回答
```

---

## 阶段 5 ⭐⭐⭐⭐: FFN 切换（Dense → MoE）

**目标**: 通过配置切换 `ffn=dense` 或 `ffn=moe`，模型无需改动

**验收**:
```
✓ MoE 能训练
✓ Load balance 指标 (ideally > 0.9)
✓ 收敛速度与 Dense FFN 相当
```

**实现步骤**:
1. `model/ffn/moe_ffn.s` - 标准 Top2 MoE
2. 更新 config 支持 `ffn_type: dense|moe`
3. Transformer 从 config 选择实现

---

## 阶段 6 ⭐⭐⭐: Attention 切换（Standard → KDA）

**目标**: KDA Attention 替换 Standard Attention，训练收敛

**验收**:
```
✓ KDA Forward 数值正确
✓ KDA Backward 梯度正确
✓ 训练不发散，loss 下降
```

**实现步骤**:
1. `model/attention/kda_attention.s` - KDA 数学实现
2. 实现 Attention 接口
3. 通过 config 选择 `attention_type: standard|kda`

**分阶段做 KDA**:
- Phase 6.1: Delta Rule + Forget Gate（CPU，无优化）
- Phase 6.2: Log-space 稳定性
- Phase 6.3: Chunk Parallel（性能）
- Phase 6.4: GPU Kernel（后期）

---

## 阶段 7 ⭐⭐⭐: Distributed Training

**目标**: 多卡训练稳定

**关键**: 
- Gradient AllReduce
- Model parallelism
- Pipeline parallelism

---

## 阶段 8 ⭐⭐: RL + Agent 长上下文能力

**目标**: Agent 能在 NeurX 上推理

---

## 为什么这个顺序更稳健？

| 旧路线 | 新路线 | 区别 |
|--------|--------|------|
| SafeTensors → Embedding → Attention | **Runtime → Single Block → Full Model** | 从基础设施开始 |
| 每个模块自己管理梯度 | **统一 Autograd** | 避免重复代码 |
| KDA 紧跟 Attention | **KDA 在标准 Attention 之后** | 先验证基础 |
| 无对齐验证 | **自动化对齐测试框架** | 快速定位问题 |

---

## 关键文件 Checklist

### Runtime (Phase 1)
- [ ] `runtime/tensor/tensor.s`
- [ ] `runtime/operator/matmul.s`
- [ ] `runtime/operator/softmax.s`
- [ ] `runtime/operator/norm.s`
- [ ] `runtime/autograd/backward.s`
- [ ] `runtime/optimizer/adamw.s`
- [ ] `runtime/checkpoint/checkpoint.s`

### Reference (Phase 1)
- [ ] `reference/export_matmul.py`
- [ ] `reference/compare_matmul.s`
- [ ] `reference/tests/test_*.s`

### Model (Phase 2-3)
- [ ] `model/attention/attention_interface.s`
- [ ] `model/attention/standard_attention.s`
- [ ] `model/ffn/ffn_interface.s`
- [ ] `model/ffn/dense_ffn.s`
- [ ] `model/transformer_block.s`
- [ ] `model/transformer.s` (24-layer)

### Serialization (Phase 3)
- [ ] `serialization/safetensors/loader.s`
- [ ] `serialization/tokenizer/hf_tokenizer.s`

### Training (Phase 3-4)
- [ ] `posttrain/trainer/train_loop.s`
- [ ] `posttrain/evaluation/metrics.s`

---

## 时间估算

| 阶段 | 任务 | 时间 |
|------|------|------|
| 1 | Runtime + Autograd | 10-14 天 |
| 2 | 单层 Block 对齐 | 3-4 天 |
| 3 | 完整 Forward + 训练循环 | 3-4 天 |
| 4 | LoRA 训练 | 2-3 天 |
| 5 | MoE 切换 | 3-4 天 |
| 6 | KDA 切换 | 5-7 天 |
| 7 | Distributed | 5-7 天 |
| 8 | RL + Agent | 3-5 天 |
| **总计** | | **4-5 周** |

---

## 最重要的三个验证点

1. **Phase 1 验证**: 单个 MatMul 与 PyTorch 完全一致 → 整个 Runtime 就能信任
2. **Phase 2 验证**: Transformer Block Forward/Backward 与 HF 完全一致 → 24 层就是复制
3. **Phase 3 验证**: Loss 真的下降，权重真的变化 → 以后所有功能都能加

---

## 立即开始

```bash
# 创建目录结构
mkdir -p runtime/{tensor,operator,autograd,optimizer,checkpoint}
mkdir -p reference/{export,tests}
mkdir -p model/{attention,ffn}
mkdir -p serialization/{safetensors,tokenizer}

# 开始 Phase 1.1
touch runtime/tensor/tensor.s
```

**第一个关键决定**: Tensor 数据结构 + 梯度追踪能力

这决定了整个 Runtime 的设计。一旦做对，后面的 Operator/Autograd 都会自然而然地正确。
