# NeurX 世界级训练框架 - 11 阶段工程路线图 (2026-07-28)

**核心哲学**: 构建经得起时间考验的系统，而非快速迭代的功能列表

**指导原则**:
- Runtime 优先 > 模型优先
- 工程稳定性 > 功能新颖性
- 完整闭环 > 孤立功能
- 自动化验证 > 手动测试
- 模块边界清晰 > 功能积压

---

## 项目最终结构（深层次分解）

```
neurx/
├── runtime/                          # ⭐⭐⭐⭐⭐ 核心基础设施
│   ├── core/                         # 最底层
│   │   ├── tensor.s                  # Tensor 定义 (metadata: shape, stride, data_ptr)
│   │   ├── storage.s                 # 原始数据存储
│   │   ├── allocator.s               # 内存分配器（支持 pool 分配）
│   │   ├── device.s                  # Device 抽象 (CPU/GPU/TPU)
│   │   └── stream.s                  # 异步执行流（预留）
│   │
│   ├── graph/                        # 计算图层
│   │   ├── autograd.s                # 自动求导核心（拓扑排序 + 反向传播）
│   │   ├── graph.s                   # 动态计算图 (for debugging)
│   │   ├── node.s                    # 计算节点
│   │   └── scheduler.s               # 执行调度（预留）
│   │
│   ├── operator/                     # 算子库
│   │   ├── linear.s                  # MatMul, Bias, etc.
│   │   ├── attention.s               # Scaled Dot-Product Attention 基础
│   │   ├── norm.s                    # LayerNorm, RMSNorm
│   │   ├── activation.s              # ReLU, SwiGLU, Tanh, etc.
│   │   ├── loss.s                    # CrossEntropy, MSE, etc.
│   │   ├── rope.s                    # RoPE（属于算子库，不是 model）
│   │   └── broadcast.s               # 广播、view、reshape 等内存操作
│   │
│   ├── executor/                     # 执行引擎
│   │   ├── eager.s                   # Eager execution (Phase 1-6)
│   │   └── compiled.s                # Compiled execution (Phase 8+ 后续)
│   │
│   └── distributed/                  # 分布式（Phase 8）
│       ├── process_group.s           # 进程通信
│       ├── communicator.s            # AllReduce, AllGather 等
│       ├── tensor_parallel.s         # 张量并行
│       ├── pipeline_parallel.s       # 流水线并行
│       └── zero.s                    # ZeRO 优化（后期）
│
├── model/                            # ⭐⭐⭐ 应用层（简单编排）
│   ├── components/                   # 组件库（组装用）
│   │   ├── embedding.s               # Token/Position Embedding
│   │   └── rotary_position.s         # RoPE 集成
│   │
│   ├── transformer_block.s           # Transformer Block（组装）
│   ├── transformer.s                 # 标准 Transformer（24层）
│   ├── qwen.s                        # Qwen2.5 具体实现
│   ├── llama.s                       # Llama（后期移植）
│   └── kimi.s                        # Kimi-K3（后期集成）
│
├── interface/                        # ⭐⭐⭐ 可插拔接口层
│   ├── attention/
│   │   ├── interface.s               # Attention 接口
│   │   ├── standard.s                # 标准 Attention
│   │   ├── mla.s                     # Multi-Head Latent Attention
│   │   └── kda.s                     # Kimi Delta Attention
│   │
│   ├── ffn/
│   │   ├── interface.s               # FFN 接口
│   │   ├── dense.s                   # 标准 MLP
│   │   ├── moe.s                     # 标准 MoE
│   │   └── latent_moe.s              # LatentMoE
│   │
│   └── optimizer/
│       ├── interface.s               # Optimizer 接口
│       ├── adamw.s                   # AdamW
│       ├── sgd.s                     # SGD（后期）
│       └── lamb.s                    # LAMB（后期）
│
├── serialization/                    # 序列化
│   ├── safetensors/
│   │   └── loader.s                  # SafeTensors 读取
│   │
│   ├── checkpoint/
│   │   ├── saver.s                   # Checkpoint 保存
│   │   ├── loader.s                  # Checkpoint 加载
│   │   └── resume.s                  # Resume 逻辑（关键）
│   │
│   └── tokenizer/
│       └── hf_tokenizer.s            # HF 兼容 tokenizer loader
│
├── reference/                        # ⭐⭐⭐ 验证与参考实现
│   ├── export/
│   │   ├── export_tensor.py          # 导出 HF 张量
│   │   ├── export_forward.py         # 导出 Forward 结果
│   │   ├── export_gradient.py        # 导出 Backward 结果
│   │   ├── export_optimizer.py       # 导出 Optimizer 更新
│   │   └── export_checkpoint.py      # 导出 Checkpoint 数据
│   │
│   ├── compare/
│   │   ├── compare_forward.s         # Forward 对齐
│   │   ├── compare_backward.s        # Backward 对齐
│   │   ├── compare_optimizer.s       # Optimizer 对齐
│   │   ├── compare_checkpoint.s      # Checkpoint 对齐
│   │   └── compare_resume.s          # Resume 一致性对齐（关键）
│   │
│   └── tests/
│       ├── test_tensor.s             # Tensor 操作
│       ├── test_operators.s          # 算子正确性
│       ├── test_autograd.s           # 梯度计算
│       ├── test_block.s              # Block 完整性
│       ├── test_checkpoint_resume.s  # Resume 一致性（关键）
│       └── golden_test.s             # Golden test（已知输出）
│
├── ci/                               # CI/自动化测试
│   ├── Makefile.test                 # 测试目标
│   ├── benchmark.s                   # 性能基准
│   ├── profiler.s                    # 性能分析
│   └── golden_dataset.s              # 黄金数据集
│
├── posttrain/
│   ├── trainer/
│   │   └── train_loop.s              # 训练主循环
│   │
│   ├── evaluation/
│   │   └── metrics.s                 # Loss、精度等指标
│   │
│   └── dataloaders/
│       └── jsonl_loader.s            # JSONL 数据加载
│
└── config.yaml                       # 所有配置（模型、训练、Runtime）
```

---

## 完整训练闭环（所有阶段围绕这个推进）

```
JSONL 文件
    ↓
Tokenizer (HF-compatible)
    ├─ Text → Token IDs
    └─ Token IDs ← Text
    ↓
DataLoader
    ├─ Batch tokenization
    └─ Batch shape (batch_size, seq_len)
    ↓
Embedding
    ├─ Token ID → Embedding
    └─ Add RoPE
    ↓
Forward Pass (Transformer 24 layers)
    ├─ Attention (pluggable: Standard/MLA/KDA)
    ├─ FFN (pluggable: Dense/MoE/LatentMoE)
    └─ Output logits (batch, seq_len, vocab_size)
    ↓
Loss Computation (CrossEntropy)
    ├─ Logits vs. Labels
    └─ Loss scalar
    ↓
Backward Pass
    ├─ dL/dLogits
    ├─ dL/dAttention
    ├─ dL/dFFN
    ├─ dL/dEmbedding
    └─ Gradient accumulation
    ↓
Optimizer Step (AdamW)
    ├─ Momentum update
    ├─ Velocity update
    ├─ Parameter update
    └─ Learning rate schedule
    ↓
Checkpoint Save
    ├─ Model weights
    ├─ Optimizer state (m, v)
    ├─ Training state (step, epoch, loss)
    └─ Config snapshot
    ↓
Resume Training (关键验证点)
    ├─ Load all state
    ├─ Continue training N steps
    ├─ Verify loss curve continuity
    └─ Checkpoint loss == Resume loss
    ↓
Inference
    ├─ Load trained weights
    ├─ Forward pass (no grad)
    └─ Generate outputs
```

---

## 11 个阶段路线图（每个阶段对应一个能力里程碑）

### Phase 0 ⭐⭐⭐⭐⭐: CI、测试、基准框架 (2-3 天)

**为什么这么早？**: 没有良好的测试体系，后续所有工作都是盲目的。

**关键组件**:
- [ ] 自动化单元测试框架
- [ ] Golden test dataset (已知输入→已知输出)
- [ ] 性能基准测试
- [ ] Continuous integration pipeline

**验收标准**:
```
✓ make test 能运行所有单元测试
✓ make benchmark 能生成性能报告
✓ make golden 能验证已知输入输出一致性
✓ 单个模块改动 < 5% 性能下降
```

**文件**:
- `ci/Makefile.test` - 测试编排
- `reference/tests/test_base.s` - 基础测试
- `ci/benchmark.s` - 性能基准
- `ci/golden_test.s` - 黄金测试
- `ci/golden_dataset.s` - 黄金数据

---

### Phase 1 ⭐⭐⭐⭐⭐: Tensor Runtime (3-4 天)

**目标**: Tensor 能正确存储、管理、追踪，支持梯度计算

**关键设计**:

```s
struct Tensor {
    // 数据
    data: []byte              // 原始数据指针
    
    // 元数据
    shape: []int              // [batch, seq, hidden]
    stride: []int             // 行优先/列优先（支持 reshape 不 copy）
    offset: int               // 数据起始位置
    
    // 梯度追踪
    grad: Tensor              // 梯度张量
    requires_grad: bool
    
    // 计算图追踪
    op: Operation             // 产生这个张量的操作
    parent_tensors: []Tensor  // 输入张量
    
    // 设备
    device: Device            // CPU/GPU/TPU（预留）
}
```

**关键操作** (支持 stride，不 copy 数据):
```s
func reshape(shape: []int) → Tensor
func transpose(axes: []int) → Tensor  
func view(shape: []int) → Tensor
func slice(start: []int, end: []int) → Tensor
func contiguous() → Tensor  // 整理内存
func broadcast(shape: []int) → Tensor
```

**验证**:
```
✓ reshape 不增加内存使用
✓ transpose 正确追踪 stride
✓ view 与 reshape 对齐
✓ broadcast 支持自动扩展
✓ contiguous 能正确整理内存
```

**文件**:
- `runtime/core/tensor.s` - Tensor 定义
- `runtime/core/storage.s` - 数据存储
- `runtime/core/allocator.s` - 内存管理
- `runtime/core/device.s` - Device 抽象
- `reference/tests/test_tensor.s` - Tensor 单元测试

---

### Phase 2 ⭐⭐⭐⭐⭐: Operator Library (4-5 天)

**目标**: 基础算子与 HF 数值完全一致

**关键算子**:

```
Linear (MatMul + Bias)
  ✓ Forward 数值对齐
  ✓ Backward 梯度对齐
  
Softmax
  ✓ Forward 数值稳定
  ✓ Backward 梯度正确
  
LayerNorm / RMSNorm
  ✓ Forward 对齐 HF (误差 < 1e-5)
  ✓ Backward 对齐 HF (误差 < 1e-3)
  
Activation (ReLU, SwiGLU, Gelu, etc.)
  ✓ Forward 对齐
  ✓ Backward 对齐
  
Loss (CrossEntropy)
  ✓ 数值稳定（防止 inf/nan）
  ✓ 支持 ignore_index
  
RoPE (Rotary Position Encoding)
  ✓ Forward 对齐
  ✓ Backward 对齐
```

**验收标准**:
```
✓ 每个算子与 HF 对齐 (误差 < 1e-4)
✓ 每个算子支持 backward
✓ make test-operators 全部通过
```

**文件**:
- `runtime/operator/*.s` - 所有算子实现
- `reference/export/export_tensor.py` - 导出 HF 中间值
- `reference/compare/compare_forward.s` - Forward 对比

---

### Phase 3 ⭐⭐⭐⭐⭐: Autograd Engine (2-3 天)

**目标**: 自动求导系统完全工作

**核心逻辑**:

```s
interface Operation {
    func backward(grad_output: Tensor) → []Tensor {
        // 接收上层梯度，返回对输入的梯度
    }
}

func backward(loss: Tensor) {
    // 1. 初始化 loss.grad = ones(loss.shape)
    // 2. 拓扑排序（从 loss 回溯到叶子节点）
    // 3. 对每个节点调用其 operation.backward()
    // 4. 梯度自动累积
    // 5. 返回所有叶子节点的梯度
}
```

**验收标准**:
```
✓ 梯度计算与 PyTorch 完全一致 (误差 < 1e-3)
✓ 支持梯度累积
✓ 支持复杂计算图
✓ make test-autograd 全部通过
```

**文件**:
- `runtime/graph/autograd.s` - 自动求导核心
- `runtime/graph/node.s` - 计算节点
- `reference/export/export_gradient.py` - 导出 PyTorch 梯度
- `reference/compare/compare_backward.s` - Backward 对比

---

### Phase 4 ⭐⭐⭐⭐⭐: Optimizer + Checkpoint (2-3 天)

**目标**: 能保存和加载训练状态，Resume 一致性验证通过

**Optimizer**:
```s
struct AdamW {
    lr: float
    betas: (float, float)
    eps: float
    weight_decay: float
    
    m: []Tensor    // 一阶矩
    v: []Tensor    // 二阶矩
}

func step(params: []Tensor) {
    // 标准 AdamW 更新
}
```

**Checkpoint**:
```s
struct Checkpoint {
    step: int
    epoch: int
    
    // 模型
    model_params: []Tensor
    
    // 优化器
    optimizer_state: {
        m: []Tensor
        v: []Tensor
        beta1_t: float
        beta2_t: float
    }
    
    // 训练状态
    loss: float
    metrics: {}
}

func save_checkpoint(path: string, checkpoint: Checkpoint)
func load_checkpoint(path: string) → Checkpoint
```

**Resume 一致性验证** (关键！):
```
1. 训练 100 步 → 保存 Checkpoint
2. 从 Checkpoint 恢复 → 继续训练 100 步
3. 对比: Loss 曲线是否连续？
   ✓ loss[99] ≈ loss_resume[0]
   ✓ loss[100:200] ≈ loss_resume[1:100]
```

**验收标准**:
```
✓ Checkpoint 包含所有必需的状态
✓ Resume 后 loss 曲线连续
✓ 参数完全一致
✓ Optimizer 状态完全一致
✓ make test-checkpoint-resume 通过
```

**文件**:
- `runtime/optimizer/adamw.s` - AdamW
- `runtime/checkpoint/saver.s` - 保存
- `runtime/checkpoint/loader.s` - 加载
- `runtime/checkpoint/resume.s` - Resume 逻辑
- `reference/compare/compare_checkpoint.s` - Checkpoint 对比
- `reference/compare/compare_resume.s` - Resume 一致性对比（关键）

---

### Phase 5 ⭐⭐⭐⭐: Transformer Block (2-3 天)

**目标**: 单个 Block 与 HF 完全对齐，Forward/Backward/Optimizer 都一致

**Block 结构**:

```s
struct TransformerBlock {
    attention: AttentionInterface     // 接口（标准化）
    ffn: FFNInterface               // 接口（标准化）
    norm1: LayerNorm
    norm2: LayerNorm
    
    func forward(x: Tensor) → Tensor {
        attn_out = attention.forward(norm1(x), x, x)
        x = x + attn_out              // Residual
        
        ffn_out = ffn.forward(norm2(x))
        x = x + ffn_out               // Residual
        
        return x
    }
}
```

**标准实现** (Phase 5 内):
```s
struct StandardAttention: AttentionInterface {
    // Scaled Dot-Product Attention
}

struct DenseFFN: FFNInterface {
    // Standard MLP: gate_proj → SwiGLU → up_proj → down_proj
}
```

**验收标准**:
```
✓ Forward 与 HF 对齐 (误差 < 1e-4)
✓ Backward 与 HF 对齐 (误差 < 1e-3)
✓ 训练 10 步，loss 下降
✓ Checkpoint/Resume 一致性验证通过
✓ make test-block 全部通过
```

**文件**:
- `model/transformer_block.s` - Block 定义
- `interface/attention/interface.s` - Attention 接口
- `interface/attention/standard.s` - 标准实现
- `interface/ffn/interface.s` - FFN 接口
- `interface/ffn/dense.s` - 标准实现
- `reference/compare/compare_block.s` - Block 对比

---

### Phase 6 ⭐⭐⭐⭐⭐: Qwen 训练闭环 (3-4 天)

**目标**: 完整的训练闭环（JSONL → Forward → Loss → Backward → Optimizer → Checkpoint → Resume → Inference）

**关键流程**:

```
Load JSONL Dataset
    ↓
Tokenize (HF-compatible)
    ↓
Create Batches
    ↓
Forward 24 Blocks
    ├─ Embedding + RoPE
    ├─ Block[0] to Block[23]
    └─ Output projection to logits
    ↓
Compute Loss (CrossEntropy)
    ↓
Backward (自动梯度)
    ↓
Optimizer.step() (AdamW)
    ↓
Save Checkpoint
    ↓
Resume from Checkpoint (验证一致性)
    ↓
Inference (生成输出)
```

**验收标准**:
```
✓ 完整训练循环运行无误
✓ Loss 真的在下降（不是常数）
✓ LoRA 权重真的在变化
✓ Checkpoint 保存成功
✓ Resume 后 loss 曲线连续
✓ Inference 能生成合理输出
✓ make posttrain 全部成功
```

**文件**:
- `model/qwen.s` - Qwen2.5 具体实现
- `serialization/safetensors/loader.s` - 权重加载
- `serialization/tokenizer/hf_tokenizer.s` - Tokenizer 加载
- `posttrain/dataloaders/jsonl_loader.s` - 数据加载
- `posttrain/trainer/train_loop.s` - 训练主循环
- `posttrain/evaluation/metrics.s` - 指标计算

---

### Phase 7 ⭐⭐⭐⭐: LoRA / PEFT (1-2 天)

**目标**: 用 LoRA 适配器训练 Qwen，参数高效

**关键**:
```s
// LoRA 线性层
struct LoRALinear {
    weight: Tensor          // 原始权重 (fixed)
    lora_a: Tensor          // 秩为 8
    lora_b: Tensor          // 秩为 8
    scaling: float
    
    func forward(x: Tensor) → Tensor {
        // 标准计算 + LoRA 计算
        return linear(x, weight) + scaling * linear(linear(x, lora_a), lora_b)
    }
}
```

**验收标准**:
```
✓ LoRA 训练参数减少 99%+
✓ Loss 收敛不变
✓ Checkpoint 正确保存 LoRA 权重
✓ 推理性能不下降
```

---

### Phase 8 ⭐⭐⭐⭐⭐: Distributed Runtime (5-7 天)

**目标**: 多卡训练稳定，通信正确

**关键组件**:
```
Process Group
    ↓
AllReduce (梯度同步)
    ↓
Tensor Parallel (模型并行)
    ↓
Pipeline Parallel (流水线并行)
    ↓
ZeRO（可选，后期优化）
```

**验收标准**:
```
✓ 单卡与多卡 loss 一致
✓ AllReduce 正确同步梯度
✓ 多卡训练不发散
```

---

### Phase 9 ⭐⭐⭐: Attention 插件化 (3-5 天)

**目标**: 通过接口实现 Standard/MLA/KDA，支持无缝切换

**接口定义**:
```s
interface AttentionInterface {
    func forward(Q, K, V, mask) → Output
    func backward(grad_output) → (grad_Q, grad_K, grad_V)
}
```

**实现**:
```s
impl StandardAttention: AttentionInterface { ... }
impl MLAAttention: AttentionInterface { ... }
impl KDAAttention: AttentionInterface { ... }
```

**配置切换**:
```yaml
model:
  attention_type: standard  # 或 mla, kda
```

**验收标准**:
```
✓ 三种 Attention 都能训练
✓ 三种 Attention 都能收敛
✓ 切换 Attention 类型，模型无需修改
```

---

### Phase 10 ⭐⭐⭐: MoE / LatentMoE (3-5 天)

**目标**: FFN 插件化，支持 Dense/MoE/LatentMoE

**接口**:
```s
interface FFNInterface {
    func forward(x) → Output
    func backward(grad) → grad_x
}
```

**实现**:
```s
impl DenseFFN: FFNInterface { ... }
impl MoEFFN: FFNInterface { ... }
impl LatentMoEFFN: FFNInterface { ... }
```

**配置**:
```yaml
model:
  ffn_type: dense  # 或 moe, latent_moe
  num_experts: 8
```

**验收标准**:
```
✓ MoE 能训练，loss 收敛
✓ Load balance > 0.9
✓ Expert assignment 均衡
✓ LatentMoE 性能对标 MoE
```

---

### Phase 11 ⭐⭐⭐: RLHF、GRPO、Agent (5-7 天)

**目标**: 高级训练能力

**关键**:
- RLHF (Reinforcement Learning from Human Feedback)
- GRPO (Group Relative Policy Optimization)
- Agent 长上下文推理

---

## 关键验证点总结

| 检查项 | 何时 | 为什么重要 |
|--------|------|----------|
| Tensor 内存管理 | Phase 1 | 所有后续操作都依赖这个 |
| Operator 数值一致 | Phase 2 | 一旦对齐，后续梯度自动正确 |
| Autograd 梯度正确 | Phase 3 | 优化器依赖这个 |
| Resume 一致性 | Phase 4 | 很多框架都失败在这里 |
| Block Forward/Backward | Phase 5 | 24 层只是复制 |
| 完整训练闭环 | Phase 6 | 证明整个系统能工作 |
| Attention 切换 | Phase 9 | 验证接口设计是否正确 |
| FFN 切换 | Phase 10 | 验证接口设计是否正确 |

---

## 为什么这个顺序更稳健？

**旧思路的问题**:
- ❌ 先实现功能，后补测试
- ❌ Phase 1 就想完成训练（太贪心）
- ❌ Attention/FFN 紧耦合，不能切换
- ❌ Resume 一致性问题隐藏到后期才暴露
- ❌ 没有自动化验证（Gold Test）

**新思路的优点**:
- ✅ Phase 0 建立测试体系（先保证质量）
- ✅ Phase 1-4 专注 Runtime 基础（一个月内完成）
- ✅ Phase 5-6 验证完整训练闭环
- ✅ Phase 9-10 验证接口设计正确性
- ✅ Phase 8 分布式作为可选优化，而非依赖

---

## 时间估算

| 阶段 | 任务 | 时间 | 累计 |
|------|------|------|------|
| 0 | CI/Test/Benchmark | 2-3 天 | 2-3 天 |
| 1 | Tensor Runtime | 3-4 天 | 5-7 天 |
| 2 | Operator Library | 4-5 天 | 9-12 天 |
| 3 | Autograd | 2-3 天 | 11-15 天 |
| 4 | Optimizer + Checkpoint | 2-3 天 | 13-18 天 |
| 5 | Transformer Block | 2-3 天 | 15-21 天 |
| 6 | Qwen 闭环 | 3-4 天 | 18-25 天 |
| 7 | LoRA | 1-2 天 | 19-27 天 |
| 8 | Distributed | 5-7 天 | 24-34 天 |
| 9 | Attention 插件 | 3-5 天 | 27-39 天 |
| 10 | MoE 插件 | 3-5 天 | 30-44 天 |
| 11 | RLHF/GRPO/Agent | 5-7 天 | 35-51 天 |
| **总计** | | | **5-7 周** |

---

## 立即开始（Phase 0 + Phase 1）

```bash
# 创建完整目录结构
mkdir -p runtime/{core,graph,operator,executor,distributed}
mkdir -p interface/{attention,ffn}
mkdir -p model/components
mkdir -p serialization/{safetensors,checkpoint,tokenizer}
mkdir -p reference/{export,compare,tests}
mkdir -p ci

# Phase 0: 建立测试框架
touch ci/Makefile.test
touch ci/benchmark.s
touch reference/tests/test_base.s

# Phase 1.1: Tensor 定义
touch runtime/core/tensor.s
touch runtime/core/storage.s
```

**关键决策**: Tensor 数据结构 + Memory Layout 支持（stride, broadcast, view）

这个设计决定了整个 Runtime 的性能和灵活性。一旦做对，后续 20+ 阶段都能放心推进。

---

## 核心哲学总结

> **世界级框架 = 扎实的 Runtime + 清晰的接口 + 完善的测试 + 详细的文档**

不是：
- 最多的功能
- 最快的性能
- 最新的论文实现

而是：
- 经得起时间考验的系统设计
- 每个模块都能独立验证
- 新模块能无缝集成
- 团队能长期维护

NeurX 的目标不是赶上 PyTorch，而是成为**一个可信任的、可维护的、可扩展的 ML Runtime**。

这需要时间，但一旦完成，价值是无限的。
