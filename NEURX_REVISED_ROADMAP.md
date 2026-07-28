# NeurX Runtime - 务实路线图 (Revised 2026-07-28)

**哲学**: MVP 优先。每个阶段都是可验证、可演示、有真实需求驱动。

**对标**: PyTorch、JAX、MindSpore

---

## 为什么要重新设计路线？

### 之前的问题

```
12 层架构 + Compiler + Dispatcher + Device Runtime
    ↓
太多 "以后需要" 的模块
    ↓
没有真实需求驱动
    ↓
风险：6 个月后发现设计错误，推倒重来
```

### 现在的方法

```
先跑起来
    ↓
遇到瓶颈
    ↓
再优化
    ↓
演进而非重写
```

---

## 11 阶段路线图

### Phase -1: 架构原则与 API 契约 (3-5 天)

**目标**: 冻结接口，达成共识

**交付物**:
- `ARCHITECTURE_PRINCIPLES.md` ✅ (刚创建)
- `contracts/tensor_api.s`
- `contracts/kernel_api.s`
- `contracts/dispatcher_api.s`
- `contracts/autograd_api.s`
- `contracts/optimizer_api.s`

**验收标准**:
```
✓ 所有接口冻结（之后不再大改）
✓ 团队对约束达成共识
✓ 代码审查团队都读过
```

**不做什么**:
- ❌ 不实现功能
- ❌ 不设计 Compiler（太早）
- ❌ 不设计复杂 Dispatcher（先简单的 switch）

---

### Phase 0: 测试框架 + 参考系统 (4-5 天)

**目标**: 建立开发基础设施和对标系统

**交付物**:

1. **CI 框架**
```
├── ci/
│   ├── Makefile.test
│   ├── test.sh
│   └── benchmark.sh
```

2. **Reference System**
```
├── reference/
│   ├── pytorch/
│   │   ├── ops/
│   │   │   ├── matmul.py
│   │   │   ├── linear.py
│   │   │   └── ...
│   │   └── reference_model.py
│   ├── export/
│   │   ├── export_forward.py
│   │   ├── export_gradient.py
│   │   └── golden_dataset.py
│   └── compare/
│       ├── compare_forward.s
│       ├── compare_backward.s
│       └── compare_utils.s
```

3. **测试框架**
```
├── test/
│   ├── functional/
│   │   └── test_base.s
│   ├── numerical/
│   │   └── test_numerical_utils.s
│   ├── gradient/
│   │   └── gradient_checker.s
│   └── integration/
│       └── test_integration_base.s
```

4. **Profiler 骨架**
```
├── profiler/
│   ├── timer.s
│   ├── memory_tracker.s
│   └── reporter.s
```

**验收标准**:
```
✓ make test 能运行
✓ make benchmark 能运行
✓ PyTorch reference 能导出数据
✓ Compare 工具能对比结果
```

**不做什么**:
- ❌ 不实现 Tensor 本体
- ❌ 不实现 Operator
- ❌ 不实现 Training Loop

**为什么这很重要?**

与其花时间在华丽的架构设计上，不如先建立"对标系统"：
- PyTorch 作为地面真实
- Export 工具确保可对比
- Compare 工具自动检查
- 之后每个 Operator 都有严格的数值验证

---

### Phase 1: Tensor Runtime (4-5 天)

**目标**: Tensor 正确操作，支持梯度

**交付物**:
```
├── runtime/
│   ├── core/
│   │   ├── tensor.s          # Tensor 数据结构
│   │   ├── storage.s         # 内存存储
│   │   └── dtype.s           # 数据类型
│   ├── device/
│   │   ├── device.s          # Device 接口
│   │   └── cpu/
│   │       └── cpu_device.s  # CPU 实现（简单）
│   └── shape/
│       ├── shape.s           # Shape 操作
│       └── strides.s         # Stride 布局
```

**核心 API**:
```s
// Tensor 创建
func tensor_zeros(shape: []int) → Tensor
func tensor_ones(shape: []int) → Tensor
func tensor_randn(shape: []int) → Tensor

// Tensor 操作
func reshape(t: Tensor, shape: []int) → Tensor
func transpose(t: Tensor, axes: []int) → Tensor
func view(t: Tensor, shape: []int) → Tensor

// 属性
func shape(t: Tensor) → []int
func dtype(t: Tensor) → DataType
func device(t: Tensor) → Device
```

**测试**:
```
test/functional/test_tensor.s
├── test_shape_operations
├── test_reshape
├── test_transpose
├── test_view
└── test_memory_layout
```

**演示**:
```s
// demo/tensor_demo.s
func main() {
    x = tensor_randn([2, 3, 4])
    y = reshape(x, [6, 4])
    z = transpose(y, [1, 0])
    
    print("x shape: ", shape(x))
    print("y shape: ", shape(y))
    print("z shape: ", shape(z))
}

// make tensor-demo
// Output:
// x shape:  [2, 3, 4]
// y shape:  [6, 4]
// z shape:  [4, 6]
```

**验收标准**:
```
✓ make test-tensor 全部通过
✓ Shape 操作正确
✓ Memory layout 正确（stride 不复制数据）
✓ make tensor-demo 输出正确
```

**关键点**:
- 只支持 CPU 设备
- 只支持基础 shape 操作
- 暂不支持梯度（Phase 4）
- 尽量简洁（< 500 行 S 代码）

---

### Phase 2: Kernel + 最小 Dispatcher (3-4 天)

**目标**: 实现最简单的 Kernel 和 Dispatcher。没有 Compiler、没有复杂调度。

**交付物**:
```
├── runtime/
│   ├── kernel/
│   │   └── cpu/
│   │       ├── matmul.s      # Matrix multiplication
│   │       ├── add.s         # Element-wise add
│   │       ├── mul.s         # Element-wise mul
│   │       └── softmax.s     # Softmax
│   └── dispatcher/
│       ├── dispatcher.s      # 简单 switch(device)
│       └── registry.s        # 注册表
```

**Dispatcher 实现** (< 50 行):
```s
func dispatcher_select_kernel(op_name: string, device_type: string) → Kernel {
    switch op_name {
    case "matmul":
        switch device_type {
        case "cpu":
            return cpu_matmul_kernel
        case "cuda":
            return cuda_matmul_kernel  // Phase 3 再加
        }
    case "add":
        switch device_type {
        case "cpu":
            return cpu_add_kernel
        }
    ...
    }
}
```

**Kernel 接口** (简单):
```s
interface Kernel {
    func execute(inputs: []Tensor) → Tensor
}

impl CPU_MatMul {
    func execute(inputs: []Tensor) → Tensor {
        a = inputs[0]
        b = inputs[1]
        c = malloc(a.shape[0], b.shape[1])
        
        // 简单的三层循环
        for i in 0..a.shape[0] {
            for j in 0..b.shape[1] {
                for k in 0..a.shape[1] {
                    c[i][j] += a[i][k] * b[k][j]
                }
            }
        }
        return c
    }
}
```

**测试**:
```
test/numerical/test_matmul.s
├── test_matmul_against_pytorch
├── test_matmul_forward
└── test_matmul_shapes
```

**演示**:
```s
// demo/matmul_demo.s
func main() {
    a = tensor_randn([2, 3])
    b = tensor_randn([3, 4])
    
    kernel = dispatcher_select_kernel("matmul", "cpu")
    c = kernel.execute([a, b])
    
    // 与 PyTorch 对比
    c_pt = load_pytorch_result("matmul_ref.json")
    assert_close(c, c_pt, eps=1e-4)
}
```

**验收标准**:
```
✓ CPU MatMul 前向正确（vs PyTorch）
✓ 其他 Kernel（Add、Mul、Softmax）前向正确
✓ Dispatcher 能正确路由
✓ make test-kernel 全部通过
```

**关键点**:
- CPU 实现即可（CUDA 留到后期）
- Dispatcher 就是 switch，不要复杂
- 只验证前向，梯度留到 Phase 4
- 没有融合、没有编译、没有优化

---

### Phase 3: Autograd (自动求导) (3-4 天)

**目标**: Backward pass 工作。梯度计算正确。

**交付物**:
```
├── runtime/
│   └── autograd/
│       ├── operation.s       # 操作记录
│       ├── backward.s        # 反向传播
│       ├── graph.s           # 计算图
│       └── gradient_check.s  # 梯度检查工具
```

**核心 API**:
```s
struct Operation {
    name: string
    inputs: []Tensor
    backward_fn: func(grad: Tensor) → []Tensor
}

func backward(output: Tensor, wrt: Tensor) → Tensor {
    // 链式法则
    // 从输出回传梯度到 wrt
}

func gradient_check(fn: func(x: Tensor) → Tensor, x: Tensor) → bool {
    // 数值梯度 vs 符号梯度
    // eps < 1e-3 为通过
}
```

**每个 Kernel 必须实现**:
```s
// kernel/cpu/matmul.s
impl CPU_MatMul {
    func backward(grad_output: Tensor, inputs: []Tensor) → []Tensor {
        // 返回 [grad_a, grad_b]
        grad_a = matmul(grad_output, transpose(inputs[1]))
        grad_b = matmul(transpose(inputs[0]), grad_output)
        return [grad_a, grad_b]
    }
}
```

**测试**:
```
test/gradient/test_gradient_check.s
├── test_matmul_gradient
├── test_add_gradient
├── test_softmax_gradient
└── test_complex_graph
```

**演示**:
```s
// demo/autograd_demo.s
func main() {
    x = tensor_randn([2, 3], requires_grad=true)
    w = tensor_randn([3, 4], requires_grad=true)
    
    y = matmul(x, w)
    loss = sum(y)
    
    grad_x = backward(loss, wrt=x)
    grad_w = backward(loss, wrt=w)
    
    // 数值梯度检查
    assert gradient_check(
        func(x_test) { return sum(matmul(x_test, w)) },
        x
    )
}
```

**验收标准**:
```
✓ 所有 Operator 的梯度正确（Gradient Check 通过）
✓ 复杂计算图的梯度正确
✓ 梯度精度 < 1e-3
✓ make test-autograd 全部通过
```

**关键点**:
- 梯度计算必须精确，这是后续训练的基础
- Gradient Check 是强制性的
- 没有 Optimizer（Phase 5）

---

### Phase 4: Linear Layer + Loss (2-3 天)

**目标**: 能计算 Loss。能验证 Loss 下降。

**交付物**:
```
├── runtime/
│   └── operator/
│       ├── linear.s          # MatMul + Bias + Activation
│       ├── loss.s            # CrossEntropy Loss
│       └── embedding.s       # Embedding（Optional）
```

**Linear Operator**:
```s
func linear(x: Tensor, weight: Tensor, bias: Tensor) → Tensor {
    // x: [batch, in_features]
    // weight: [in_features, out_features]
    // bias: [out_features]
    
    kernel = dispatcher_select_kernel("matmul", x.device)
    output = kernel.execute(x, weight)
    
    // Add bias
    kernel_add = dispatcher_select_kernel("add", x.device)
    output = kernel_add.execute(output, bias)
    
    // Track for backward
    output.op = LinearOp(x, weight, bias)
    
    return output
}
```

**Loss 计算**:
```s
func cross_entropy_loss(logits: Tensor, labels: Tensor) → Tensor {
    // logits: [batch, num_classes]
    // labels: [batch]
    
    // 1. Softmax
    kernel_softmax = dispatcher_select_kernel("softmax", logits.device)
    probs = kernel_softmax.execute(logits)
    
    // 2. Negative log likelihood
    loss = -log(probs[batch, labels])
    
    // 3. Mean
    return mean(loss)
}
```

**测试**:
```
test/integration/test_linear.s
├── test_linear_forward
├── test_linear_backward
└── test_loss_computation
```

**演示**:
```s
// demo/linear_demo.s
func main() {
    // Generate random data
    x = tensor_randn([32, 10])      // batch=32, features=10
    y = tensor_zeros([32, 5])       // num_classes=5
    
    w = tensor_randn([10, 5])
    b = tensor_zeros([5])
    
    // Forward
    logits = linear(x, w, b)
    loss = cross_entropy_loss(logits, y)
    
    print("Loss: ", loss.value)
    
    // Backward
    grad_w = backward(loss, wrt=w)
    
    // Verify gradient
    assert gradient_check(
        func(w_test) { 
            logits_test = linear(x, w_test, b)
            return cross_entropy_loss(logits_test, y)
        },
        w
    )
}
```

**验收标准**:
```
✓ Linear forward 正确
✓ Linear backward 正确（梯度检查通过）
✓ Loss 计算正确
✓ make test-linear 全部通过
```

**关键点**:
- Linear 是第一个"复合 Operator"
- 展示了 Dispatcher 的使用
- Loss 计算是训练的基础

---

### Phase 5: Optimizer + 训练循环 (2-3 天)

**目标**: 能进行完整的训练循环。Loss 能持续下降。

**交付物**:
```
├── runtime/
│   ├── optimizer/
│   │   ├── optimizer.s       # Optimizer 接口
│   │   └── adamw.s           # AdamW 实现
│   └── training/
│       ├── trainer.s         # 训练循环
│       ├── dataloader.s      # 数据加载
│       └── checkpoint.s      # Save/Load
```

**Optimizer 接口**:
```s
interface Optimizer {
    func step(grads: map[string]Tensor)  // 更新参数
}

impl AdamW {
    func step(grads: map[string]Tensor) {
        for param_name in grads {
            grad = grads[param_name]
            
            // Adam 更新逻辑
            m = beta1 * m + (1 - beta1) * grad       // 一阶动量
            v = beta2 * v + (1 - beta2) * grad^2    // 二阶动量
            param = param - lr * m / (sqrt(v) + eps)
        }
    }
}
```

**训练循环**:
```s
func train_epoch(model, dataloader, optimizer, loss_fn) {
    total_loss = 0.0
    
    for batch_idx in 0..dataloader.num_batches {
        x, y = dataloader.next_batch()
        
        // Forward
        logits = model.forward(x)
        loss = loss_fn(logits, y)
        
        // Backward
        grad_loss = tensor_ones(loss.shape)
        grads = backward(loss, grad_loss)
        
        // Optimizer step
        optimizer.step(grads)
        
        total_loss += loss.value
    }
    
    avg_loss = total_loss / dataloader.num_batches
    return avg_loss
}
```

**Checkpoint**:
```s
func save_checkpoint(path: string, model, optimizer, step: int) {
    checkpoint = {
        "model_state": model.state_dict(),
        "optimizer_state": optimizer.state_dict(),
        "step": step
    }
    save_json(path, checkpoint)
}

func load_checkpoint(path: string) → (model, optimizer, step) {
    checkpoint = load_json(path)
    model.load_state_dict(checkpoint["model_state"])
    optimizer.load_state_dict(checkpoint["optimizer_state"])
    return model, optimizer, checkpoint["step"]
}
```

**演示: MNIST Training**:
```s
// demo/mnist_train.s
func main() {
    // 简单的 2 层网络
    model = create_model()   // Linear(784) → Linear(128) → Linear(10)
    optimizer = AdamW(lr=0.001)
    
    dataloader = MNIST_DataLoader("train", batch_size=32)
    
    for epoch in 0..5 {
        avg_loss = train_epoch(model, dataloader, optimizer, cross_entropy_loss)
        print("Epoch ", epoch, " Loss: ", avg_loss)
    }
    
    // 验证 Loss 下降
    assert first_loss > last_loss  // 必须下降！
}
```

**测试**:
```
test/integration/test_training.s
├── test_optimizer_step
├── test_loss_decreases
├── test_gradient_accumulation
└── test_checkpoint_save_load
```

**验收标准**:
```
✓ 训练循环能运行 100 步
✓ Loss 持续下降（不能保证收敛，但不能上升）
✓ Checkpoint save/load 正确
✓ 恢复后 loss 曲线连续
✓ make test-training 全部通过
```

**关键点**:
- 这是第一个"能工作的系统"
- Loss 下降是最重要的指标
- Checkpoint/Resume 必须正确

---

### Phase 6: MLP 验证 (1-2 天)

**目标**: 验证多层网络能正确训练。MNIST 收敛。

**交付物**:
```
├── models/
│   ├── mlp.s               # 多层感知机
│   └── configs/
│       └── mnist.yaml
```

**MLP 模型**:
```s
struct MLP {
    layer1: Linear          // 784 → 256
    layer2: Linear          // 256 → 128
    layer3: Linear          // 128 → 10
}

func mlp_forward(model: MLP, x: Tensor) → Tensor {
    x = linear(x, model.layer1.weight, model.layer1.bias)
    x = relu(x)
    x = linear(x, model.layer2.weight, model.layer2.bias)
    x = relu(x)
    x = linear(x, model.layer3.weight, model.layer3.bias)
    return x
}
```

**MNIST 训练脚本**:
```s
// train_mnist.s
func main() {
    model = MLP()
    optimizer = AdamW(lr=0.001)
    
    train_loader = MNIST_DataLoader("train", batch_size=32)
    test_loader = MNIST_DataLoader("test", batch_size=32)
    
    for epoch in 0..10 {
        // Train
        train_loss = train_epoch(model, train_loader, optimizer)
        
        // Evaluate
        test_acc = evaluate(model, test_loader)
        
        print("Epoch ", epoch, " Train Loss: ", train_loss, " Test Acc: ", test_acc)
    }
    
    // 最终精度应该 > 95%
    assert final_accuracy > 0.95
}
```

**演示**:
```
make train-mnist
# Epoch 0 Train Loss: 2.301 Test Acc: 0.10
# Epoch 1 Train Loss: 2.105 Test Acc: 0.35
# Epoch 2 Train Loss: 1.823 Test Acc: 0.65
# ...
# Epoch 9 Train Loss: 0.102 Test Acc: 0.97
```

**验收标准**:
```
✓ MNIST 训练收敛到 > 95% 精度
✓ Loss 稳定下降
✓ 没有异常（NaN、Inf）
✓ 训练速度可接受（< 10s/epoch）
```

**关键点**:
- 这是第一个"真实应用"
- 证明整个系统工作正常

---

### Phase 7: Transformer Block (3-4 天)

**目标**: 单个 Transformer Block 与 HuggingFace 对齐。

**交付物**:
```
├── models/
│   └── transformer.s
├── reference/
│   └── pytorch/
│       └── transformer_block.py
└── test/
    └── numerical/
        └── test_transformer_block_alignment.s
```

**Transformer Block**:
```s
struct TransformerBlock {
    // Self-Attention
    q_proj: Linear      // [hidden] → [head_dim * num_heads]
    k_proj: Linear
    v_proj: Linear
    out_proj: Linear
    
    // FFN
    ffn_expand: Linear  // [hidden] → [4 * hidden]
    ffn_reduce: Linear  // [4 * hidden] → [hidden]
    
    // Normalization
    ln1: LayerNorm
    ln2: LayerNorm
}

func transformer_block_forward(block: TransformerBlock, x: Tensor) → Tensor {
    // Pre-norm
    x_norm = layer_norm(x)
    
    // Self-Attention
    q = linear(x_norm, block.q_proj)
    k = linear(x_norm, block.k_proj)
    v = linear(x_norm, block.v_proj)
    
    attn_output = scaled_dot_product_attention(q, k, v)
    attn_output = linear(attn_output, block.out_proj)
    
    // Residual
    x = x + attn_output
    
    // FFN
    x_norm = layer_norm(x)
    ffn = linear(x_norm, block.ffn_expand)
    ffn = gelu(ffn)
    ffn = linear(ffn, block.ffn_reduce)
    
    // Residual
    x = x + ffn
    
    return x
}
```

**验证**:
```
对标 HuggingFace Qwen2
├── Forward pass 一致性 (误差 < 1e-4)
├── Backward pass 一致性 (误差 < 1e-3)
└── Attention pattern 一致性
```

**演示**:
```s
// demo/transformer_block_demo.s
func main() {
    block = create_transformer_block_from_pretrained()  // 加载 HF 权重
    
    x = tensor_randn([2, 16, 768])  // [batch, seq_len, hidden]
    
    // Forward
    y_s = transformer_block_forward(block, x)
    y_pt = load_pytorch_forward()
    
    // 验证一致性
    assert_close(y_s, y_pt, eps=1e-4)
    
    // 验证梯度
    loss_s = sum(y_s)
    grad_s = backward(loss_s, x)
    grad_pt = load_pytorch_gradient()
    assert_close(grad_s, grad_pt, eps=1e-3)
}
```

**验收标准**:
```
✓ Forward 与 HF 对齐 (误差 < 1e-4)
✓ Backward 与 HF 对齐 (误差 < 1e-3)
✓ Gradient Check 通过
✓ make test-transformer-block 全部通过
```

**关键点**:
- 这是第一个与 PyTorch 模型对齐的真实 Operator
- 数值精度验证是关键

---

### Phase 8: Qwen 完整训练 (3-5 天)

**目标**: 完整的 Qwen 训练闭环。能进行 SFT 训练。

**交付物**:
```
├── models/
│   └── qwen.s                    # 24 层 Transformer
├── training/
│   ├── sft_trainer.s             # SFT 训练脚本
│   └── data_loader.s             # JSONL 数据加载
└── scripts/
    └── train_qwen.s
```

**完整训练闭环**:
```
JSONL Dataset
    ↓
Tokenize
    ↓
DataLoader (batch processing)
    ↓
Forward Pass (24 层 Transformer)
    ↓
Loss Computation (CrossEntropy)
    ↓
Backward Pass (Autograd)
    ↓
Optimizer Step (AdamW)
    ↓
Checkpoint Save
    ↓
Resume Training (验证一致性)
```

**验收标准**:
```
✓ 能完整训练 100 步
✓ Loss 持续下降
✓ Checkpoint/Resume 正确
✓ Memory 使用合理
✓ 训练速度可接受（< 1s/step）
```

**演示**:
```
make train-qwen
# Step 1: Loss = 3.245
# Step 2: Loss = 3.187
# ...
# Step 100: Loss = 2.102
# Checkpoint saved to: checkpoints/step_100.json
```

---

### Phase 9: LoRA (1-2 天)

**目标**: LoRA 适配器训练。能微调 Qwen。

**交付物**:
```
├── adapter/
│   └── lora.s
└── training/
    └── lora_trainer.s
```

**验收标准**:
```
✓ LoRA 权重更新正确
✓ Merge 后模型与全参数微调接近
✓ 恢复正确
```

---

### Phase 10: 分布式训练 (5-7 天)

**目标**: 多卡训练稳定。梯度同步正确。

**交付物**:
```
├── distributed/
│   ├── process_group.s
│   ├── all_reduce.s
│   ├── tensor_parallel.s
│   └── pipeline_parallel.s
```

**验收标准**:
```
✓ AllReduce 梯度同步正确
✓ Tensor Parallel 前向/反向正确
✓ 单卡 vs 多卡结果一致
```

---

### Phase 11: Compiler & 性能优化 (5-7 天)

**目标**: 图融合、编译优化。性能提升 20%+。

**交付物**:
```
├── compiler/
│   ├── graph_optimizer.s
│   ├── fusion.s
│   ├── memory_planner.s
│   └── layout_optimizer.s
```

**验收标准**:
```
✓ 融合后数值精度不变
✓ 性能提升 > 20%
✓ 内存使用 < 原来 80%
```

---

## 时间估算 (更务实)

| Phase | 任务 | 时间 | 累计 |
|-------|------|------|------|
| -1 | Principles + Contracts | 3-5 天 | 3-5 天 |
| 0 | CI + Reference + Profiler | 4-5 天 | 7-10 天 |
| 1 | Tensor Runtime | 4-5 天 | 11-15 天 |
| 2 | Kernel + Min Dispatcher | 3-4 天 | 14-19 天 |
| 3 | Autograd | 3-4 天 | 17-23 天 |
| 4 | Linear + Loss | 2-3 天 | 19-26 天 |
| 5 | Optimizer + Training Loop | 2-3 天 | 21-29 天 |
| 6 | MLP + MNIST | 1-2 天 | 22-31 天 |
| 7 | Transformer Block | 3-4 天 | 25-35 天 |
| 8 | Qwen Training | 3-5 天 | 28-40 天 |
| 9 | LoRA | 1-2 天 | 29-42 天 |
| 10 | Distributed | 5-7 天 | 34-49 天 |
| 11 | Compiler | 5-7 天 | 39-56 天 |

**总计: 39-56 天 (5-8 周)**

**相比之前**: 
- 之前: 12 层 + 太多"以后需要"的东西 (43-61 天)
- 现在: 11 个可验证的阶段 (39-56 天)
- **改进**: 时间短，风险低，每阶段都有明确的 Demo

---

## 关键差异 (vs 之前的设计)

### 之前的问题

```
12 层架构，很漂亮
    ↓
但：Compiler 需要 Graph IR、Shape Inference、Alias Analysis
    ↓
Device Runtime 看起来完整，但没有真实需求
    ↓
Dispatcher 设计很复杂，但最初只需要 switch
    ↓
结果：花了 30% 的时间设计不必要的东西
```

### 现在的方式

```
Phase 1: Tensor 能跑
    ↓
Phase 2: Kernel 能用（最简单的 Dispatcher）
    ↓
Phase 3: 梯度正确（Gradient Check）
    ↓
Phase 4: Loss 能算
    ↓
Phase 5: 训练能循环
    ↓
Phase 6: MNIST 收敛
    ↓
Phase 7: Transformer Block 与 HF 对齐
    ↓
Phase 8: Qwen 能训练
    ↓
**然后** 再考虑：Distributed、Compiler、Plugin
```

**关键**: 每个阶段都是上一阶段的自然演进，没有"以后再做"的负债。

---

## 最终对比表

| 指标 | 之前 | 现在 |
|------|------|------|
| 总 Phase 数 | 12 | 11 |
| 预计时间 | 43-61 天 | 39-56 天 |
| Compiler Phase | 6 | 11 |
| Dispatcher 复杂度 | 复杂 | 简单 |
| 每阶段 Demo | 无 | 有 |
| 风险 | 高（无验证） | 低（每阶段验证） |
| 代码行数 | ~30K | ~20K（Phase 8） |
| 可维护性 | 需要改进 | 更好 |
| 实用价值 | 架构美 | 能用 |

---

## 核心成功指标

1. **Phase -1**: ✅ 原则冻结
2. **Phase 0**: ✅ 对标系统工作
3. **Phase 1**: ✅ Tensor 测试全绿
4. **Phase 2**: ✅ MatMul 与 PyTorch 对齐
5. **Phase 3**: ✅ Gradient Check 通过
6. **Phase 4**: ✅ Linear Layer 工作
7. **Phase 5**: ✅ 训练循环运行
8. **Phase 6**: ✅ **MNIST 收敛到 > 95%**
9. **Phase 7**: ✅ **Transformer Block 与 HF 完全对齐**
10. **Phase 8**: ✅ **Qwen 完整训练闭环**
11. **Phase 11**: ✅ 性能提升 > 20%

---

## 与世界级框架的关系

| Framework | 路线 | 时间 |
|-----------|------|------|
| PyTorch | Tensor → Autograd → Optimizer → Distributed | 5+ 年 |
| JAX | Transforms → JIT → Distributed | 3+ 年 |
| TensorFlow | Graph → Eager → Compiler | 4+ 年 |
| **NeurX (现在)** | **Tensor → Autograd → Training → Block → Qwen → Distributed** | **6-8 周** |

NeurX 的优势：
- ✅ 从"能训练模型"开始（不是"能算一个 Op"）
- ✅ 每阶段对标 PyTorch（不是"自己玩"）
- ✅ 代码清晰（纯 S 语言）
- ✅ 架构稳定（遵守原则）

---

## 最后的话

这个路线图是：

1. **可行的** - 时间合理，风险可控
2. **可验证的** - 每个阶段都有 Demo、Test、Benchmark
3. **可演进的** - 每个新功能都是之前的自然延伸
4. **对标的** - 所有 Operator 都对齐 PyTorch/HF
5. **可维护的** - 遵守 ARCHITECTURE_PRINCIPLES.md

这才是对得起"世界级框架"这个目标的做法。

准备好开始 Phase -1 了吗？

下一步：
1. ✅ 阅读 ARCHITECTURE_PRINCIPLES.md
2. ✅ 阅读本路线图
3. ❓ 确认是否按这个方向开始
