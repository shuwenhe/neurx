# NeurX Phase 2A: 正确的优先级排列

**日期**: 2026-07-27 (修订版)  
**基于**: 用户反馈的工程最佳实践  
**重点**: Framework/Implementation/Validation 严格分离

---

## 📌 核心洞察

### Reference vs Pure S Pipeline

```
Reference Pipeline (Python)            Pure S Pipeline (目标)
├─ Model Loader                        ├─ W1: Tensor Runtime ⭐ NEW
├─ Tokenizer                           ├─ W2: Tokenizer
├─ Dataset                             ├─ W3: Embedding
├─ Forward Pass                        ├─ W4: RoPE
├─ Loss                                ├─ W5: Attention
├─ Backward                            ├─ W6: Transformer Block
├─ Optimizer                           ├─ W7: Loss
├─ Checkpoint/Export                   ├─ W8: Backward (Autograd) ⭐ KEY
└─ ✅ DONE                             ├─ W9: Optimizer
                                       ├─ W10: Checkpoint
                                       ├─ W11: Evaluation
                                       └─ Numerical Validation ⭐ NEW
```

### 三个被重新评估的决定

| 原决定 | 新决定 | 理由 |
|--------|--------|------|
| math_utils 最高优先 | Tensor Runtime 最高优先 | 基础设施优先 |
| SafeTensors 第2周 | SafeTensors 第4周 | 不影响训练逻辑 |
| JSON Parser 第1周 | JSON Parser 简化版第1周 | 只支持训练格式 |

### 三个关键新增模块

| # | 模块 | 为什么关键 | 工作量 |
|---|------|----------|--------|
| 1 | **Tensor Runtime** | 结构化数据表示，为CUDA/NPU预留接口 | 大 |
| 2 | **Autograd** | 系统化梯度计算，防止手写Backward |  |
| 3 | **Numerical Validation** | Golden tests + gradient check = 防止隐藏bug | 中 |

---

## 🎯 新的优先级排列 (W1-W11)

### W1: Tensor Runtime ⭐ FOUNDATION
**目标**: 结构化张量表示，未来CUDA/NPU/SIMD支持

```
任务:
  ✓ tensor_s struct with shape/strides/dtype/device
  ✓ compute_strides_s (行主序/列主序)
  ✓ tensor_reshape_s, tensor_transpose_s
  ✓ tensor_slice_s, tensor_cat_s
  □ Memory layout abstraction (for CUDA later)
  □ dtype support (float32, bfloat16, int8)

Acceptance:
  □ Framework: 100% (所有接口定义)
  □ Implementation: 100% (所有操作实现)
  □ Validation: 80% (单元测试)

Estimated: 1-2 days
Blocks: W2-W11 (所有其他)
```

**当前进展**: 
- ✅ tensor_s struct 定义完成
- ✅ compute_strides_s, reshape, transpose 框架完成
- ⏳ 需要完整实现和单元测试

---

### W2: Tokenizer (W1.1已完成的升级版)
**目标**: 基于Tensor Runtime的分词

```
任务:
  ✓ 集成W1 Tensor Runtime
  ✓ 使用tensor_s而非[][]float
  ✓ Batch tokenization
  ✓ 验证与Python版本一致

Acceptance:
  □ Framework: 100%
  □ Implementation: 100%
  □ Validation: 95% (golden test vs Python)

Estimated: 1 day
Depends on: W1 PASS
```

---

### W3: Embedding
**目标**: token_ids → embeddings using Tensor Runtime

```
任务:
  ✓ embedding_lookup_s using tensor indexing
  ✓ embedding_scale_s for stability
  ✓ Position encoding preparation
  
Acceptance:
  □ Framework: 100%
  □ Implementation: 100%
  □ Validation: 100% (golden: compare embeddings)

Estimated: 1 day
Depends on: W1, W2
Golden test:
  input: [1, 2, 3, ...] (token IDs)
  ↓
  embedding_lookup_s(tokens, vocab)
  ↓
  expected: shape (seq_len, 4096)
  ↓
  compare vs Python: RMSError < 1e-5
```

---

### W4: RoPE (Rotary Position Encoding)
**目标**: 准确的位置编码

```
任务:
  ✓ compute_rope_freqs_s (需要cos/sin)
  ✓ apply_rope_s to Q, K matrices
  ✓ Numerical validation
  
需要: math_utils (sin, cos)

Acceptance:
  □ Framework: 100%
  □ Implementation: 100%
  □ Validation: 100% (gradient check)

Estimated: 2 days
Depends on: W1, W3

Golden test:
  input: random tensor (batch, seq, dim)
  ↓
  apply_rope_s
  ↓
  检查正交性: Q @ Q.T ≈ I
  检查梯度: ∂loss/∂input 数值检查
```

---

### W5: Attention
**目标**: Self-Attention完整实现

```
分解:
  ├─ Q, K, V 投影 (使用lora_module)
  ├─ Scaled dot-product: softmax(Q @ K.T / √d)
  ├─ Attention weights @ V
  └─ Output projection + residual
  
需要: W1 (Tensor), W4 (RoPE), Autograd framework

Acceptance:
  □ Framework: 100% (所有函数签名)
  □ Implementation: 100% (完整算法)
  □ Validation: 100% (numerical gradient check)

Estimated: 3 days
Depends on: W1, W3, W4, Autograd框架

Golden test:
  input: shape (batch, seq, 4096)
  ↓
  attention_forward_s
  ↓
  output: same shape
  ↓
  numerical_gradient_check: pass
```

---

### W6: Transformer Block
**目标**: Single layer = Attention + MLP

```
分解:
  ├─ LayerNorm (需要sqrt)
  ├─ Attention (from W5)
  ├─ Residual connection
  ├─ MLP (gate, up, down projections)
  └─ LayerNorm + Residual
  
24 layers stacked

Acceptance:
  □ Framework: 100%
  □ Implementation: 100%
  □ Validation: 95% (forward path working)

Estimated: 4 days
Depends on: W1-W5, math_utils (sqrt)

Golden test:
  24层ForwardPass
  output shape: input shape
  numerical gradient check: pass
```

---

### W7: Loss (CrossEntropy)
**目标**: 分类损失计算

```
任务:
  ✓ softmax_s (需要exp)
  ✓ log_softmax_s (log)
  ✓ cross_entropy_loss_s
  ✓ KL divergence (optional)

需要: math_utils (exp, log)

Acceptance:
  □ Framework: 100%
  □ Implementation: 100%
  □ Validation: 100% (golden: vs Python)

Estimated: 1 day
Depends on: W1, math_utils

Golden test:
  logits: shape (batch, seq, vocab)
  labels: shape (batch, seq)
  ↓
  cross_entropy_loss_s
  ↓
  expected: scalar loss value
  ↓
  RMSError vs Python < 1e-4
```

---

### W8: Backward (Autograd) ⭐ CRITICAL
**目标**: 系统化的自动微分 (防止手写100+行backward)

```
架构:
  ├─ computation_node_s (operation记录)
  ├─ gradient_tape_s (operation序列)
  ├─ backward_matmul_s
  ├─ backward_add_s
  ├─ backward_mul_s
  ├─ backward_softmax_s
  ├─ backward_layer_norm_s
  ├─ backward_relu_s
  └─ chain_rule_s (连锁法则)

核心理念:
  forward时记录operations
  backward时遍历反向执行

Acceptance:
  □ Framework: 100% (tape机制完成)
  □ Implementation: 80% (基础ops完成)
  □ Validation: 100% (numerical gradient check)

Estimated: 3 days
Depends on: W1, numerical_validation框架

Validation:
  对每个op:
    analytical_grad = backward_XXX_s(...)
    numerical_grad = finite_diff(...)
    assert: || analytical - numerical || < 1e-4
```

---

### W9: Optimizer (AdamW) ✅
**目标**: 参数优化

```
现状: 已完成 100% (见posttrain/core/adamw_optimizer.s)

需要加入:
  ✓ 集成Tensor Runtime
  ✓ Gradient clipping
  ✓ Weight decay application
  ✓ Learning rate scheduling
  
Acceptance:
  □ Framework: 100%
  □ Implementation: 100%
  □ Validation: 100% (parameter trajectory check)

Estimated: 0.5 days (升级现有代码)
Depends on: W1, W8
```

---

### W10: Checkpoint/Export
**目标**: 模型持久化

```
分解:
  ├─ Save tensor_s to binary format
  ├─ Load tensor_s from binary
  ├─ 简化SafeTensors写入
  ├─ LoRA adapter save/load
  └─ Model merge (W base + LoRA delta)

简化策略:
  不写完整SafeTensors解析器
  而是写NeurX内部格式
  再由Python包装器转SafeTensors

Acceptance:
  □ Framework: 100%
  □ Implementation: 80%
  □ Validation: 90% (save/load roundtrip)

Estimated: 2 days
Depends on: W1, W9
```

---

### W11: Evaluation
**目标**: 指标计算

```
任务:
  ✓ Accuracy on dev set
  ✓ Perplexity
  ✓ Loss tracking
  ✓ Training curves
  
使用existing指标计算代码
集成到training loop

Acceptance:
  □ Framework: 100%
  □ Implementation: 100%
  □ Validation: 100%

Estimated: 1 day
Depends on: W1-W10
```

---

## 📊 完成度评估标准

**每个模块必须满足三项条件**:

### Framework (接口层)
- [ ] 所有struct定义完成
- [ ] 所有函数签名定义完成
- [ ] 功能分解明确
**判定**: 接口齐全，可独立测试

### Implementation (算法层)
- [ ] 核心算法完整实现
- [ ] 没有TODO/FIXME
- [ ] 与Python版本算法一致
**判定**: 逻辑完整，不依赖外部

### Validation (验证层)
- [ ] Golden test通过 (vs Python)
- [ ] Numerical gradient check通过
- [ ] 单元测试覆盖主路径
- [ ] 集成测试通过
**判定**: 结果正确，可信赖

---

## 🔄 修订的完成度表

```
当前状态 (2026-07-27):

W1 Tensor Runtime
  ├─ Framework: 50% (基本完成，需shape/stride完善)
  ├─ Implementation: 40% (框架完成，细节缺失)
  └─ Validation: 0% (无测试)
  OVERALL: 30% (🔴 BLOCKING 所有其他)

W2 Tokenizer
  ├─ Framework: 100% (W1.1已完成) ✓
  ├─ Implementation: 100% ✓
  └─ Validation: 95% (vs Python) ✓
  OVERALL: 98% (⏳ 等待W1升级)

W3 Embedding
  ├─ Framework: 80% (框架完成)
  ├─ Implementation: 40% (RoPE待完善)
  └─ Validation: 0%
  OVERALL: 40%

W4-W6 Transformer
  ├─ Framework: 30% (设计文档完成)
  ├─ Implementation: 0%
  └─ Validation: 0%
  OVERALL: 10%

W7 Loss
  ├─ Framework: 100%
  ├─ Implementation: 60% (需exp/log)
  └─ Validation: 0%
  OVERALL: 53%

W8 Autograd ⭐
  ├─ Framework: 60% (tape机制框架)
  ├─ Implementation: 20% (基础ops)
  └─ Validation: 0%
  OVERALL: 27% (🔴 CRITICAL)

W9 Optimizer
  ├─ Framework: 100%
  ├─ Implementation: 100%
  └─ Validation: 30% (无集成测试)
  OVERALL: 77%

W10 Checkpoint
  ├─ Framework: 50%
  ├─ Implementation: 0%
  └─ Validation: 0%
  OVERALL: 17%

W11 Evaluation
  ├─ Framework: 80%
  ├─ Implementation: 50%
  └─ Validation: 0%
  OVERALL: 43%

新增: Numerical Validation
  ├─ Framework: 80% (regression suite框架完成)
  ├─ Implementation: 40% (golden test基础完成)
  └─ Validation: 0% (无自验证)
  OVERALL: 40%
```

---

## 📅 修订的时间表

### Phase 2A-I: Foundation (Week 1)
```
Day 1-2: W1 Tensor Runtime
  ├─ 完整shape/stride计算
  ├─ Memory layout abstraction
  └─ 单元测试 (100+ test cases)
  
Day 3: math_utils (exp/log/sqrt/sin/cos)
  ├─ 高精度实现
  └─ 精度验证
  
Day 4: W2-W3 Embedding
  ├─ 集成Tensor Runtime
  └─ Golden test vs Python
  
Day 5: Numerical Validation Framework
  ├─ Golden test runner
  └─ Numerical gradient checker
```

### Phase 2A-II: Core Training (Week 2-3)
```
Week 2:
  W4 RoPE (1 day)
  W5 Attention (2 days)
  W6 Transformer Block (2 days)

Week 3:
  W7 Loss (1 day)
  W8 Autograd (2 days)
  W9 Optimizer upgrade (1 day)
  W10 Checkpoint (1 day)
  W11 Evaluation (1 day)
```

### Phase 2A-III: Validation (Week 4)
```
Mini-batch training:
  10 samples, 3 steps
  ├─ Forward pass ✓
  ├─ Loss decrease ✓
  ├─ Gradient norm > 0 ✓
  └─ Checkpoint save/load ✓

Full training:
  MedMCQA 3 epochs
  ├─ Loss curve ✓
  ├─ Model merge ✓
  └─ Output validation ✓
```

---

## ✨ 下一步行动 (立即)

1. **完成W1 (Tensor Runtime)**
   ```bash
   优先级: 🔴 CRITICAL
   工作:
     - 完善shape/stride计算
     - 添加单元测试 (50+ cases)
     - 验证所有reshape/transpose/slice操作正确
   ```

2. **实现math_utils.s**
   ```bash
   优先级: 🔴 CRITICAL
   函数: exp, log, sqrt, rsqrt, sin, cos
   ```

3. **创建Numerical Validation单元测试**
   ```bash
   优先级: 🟠 HIGH
   任务:
     - Golden embedding test
     - Golden RoPE test
     - Golden attention test
   ```

---

## 📝 关键度量

### 进度指标
- ✅ **Framework完成度**: 所有struct/接口定义
- 📊 **Implementation完成度**: 算法正确性
- ✓ **Validation完成度**: Golden tests通过率

### 阻塞关系 (Dependency Graph)
```
W1 (Tensor Runtime) - 阻塞所有
  ├─ W2 (Tokenizer)
  ├─ W3 (Embedding)
  │   ├─ W4 (RoPE)
  │   │   └─ W5 (Attention)
  │   │       └─ W6 (Transformer)
  │   │           └─ W7 (Loss)
  │   │               └─ W8 (Backward)
  │   │                   └─ W9 (Optimizer)
  │   │                       └─ W10 (Checkpoint)
  │   │                           └─ W11 (Evaluation)
  └─ Numerical Validation (parallel)
```

### 质量关键指标
- 数值误差: < 1e-4 (vs Python)
- 梯度检查: < 1e-3 (analytical vs numerical)
- 收敛性: loss下降 > 0% 在3 steps内

---

**最后的话**: 这个调整强调了**正确性优先于速度**。通过Numerical Validation, Autograd框架, Tensor Runtime,我们建立的不仅是一个能"跑"的系统，而是一个能"验证"和"维护"的系统。

