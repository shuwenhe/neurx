#!/bin/bash
# 快速参考: S语言完整的ML实现
# Quick Reference: Complete ML Implementation in S Language

cat << 'EOF'

╔════════════════════════════════════════════════════════════════╗
║         S语言 - 完整的Attention、Gradient、Optimizer         ║
║                   快速参考 (Quick Reference)                  ║
╚════════════════════════════════════════════════════════════════╝

┌─ 📚 核心模块 ──────────────────────────────────────────────┐
│                                                              │
│  1️⃣  Math Ops (数学操作)                                    │
│      • 矩阵乘法、转置、缩放                                  │
│      • ReLU、GELU、Softmax                                 │
│      • Layer Norm、损失函数                                │
│      📍 文件: /neurx/ml/math_ops.s (300 行)               │
│                                                              │
│  2️⃣  Autodiff (自动微分)                                    │
│      • 计算图构建和管理                                      │
│      • 7种操作的前向传播                                     │
│      • 完整的反向传播规则                                    │
│      📍 文件: /neurx/ml/autodiff_complete.s (400 行)      │
│                                                              │
│  3️⃣  Attention (多头注意力)                                 │
│      • Query/Key/Value投影                                  │
│      • 缩放点积注意力                                        │
│      • 完整的前向和反向传播                                  │
│      📍 文件: /neurx/ml/attention_complete.s (350 行)     │
│                                                              │
│  4️⃣  Optimizer (AdamW优化器)                               │
│      • 一阶和二阶矩估计                                      │
│      • 权重衰减、梯度剪裁                                    │
│      • 学习率调度 (线性、余弦、预热)                        │
│      📍 文件: /neurx/ml/optimizer_adamw.s (350 行)        │
│                                                              │
│  5️⃣  Training Loop (训练循环)                               │
│      • 完整的Transformer块                                  │
│      • 前向/反向传播集成                                     │
│      • 多epoch训练和评估                                     │
│      📍 文件: /neurx/train/training_complete_integrated.s  │
│                                   (400 行)                  │
│                                                              │
└──────────────────────────────────────────────────────────────┘

┌─ 🎯 使用快速开始 ────────────────────────────────────────────┐
│                                                              │
│  【初始化模型】                                              │
│  ─────────────────────────────────────────────────────────  │
│  state := init_training_state(                              │
│      num_layers=2,                    # Transformer层数    │
│      d_model=32,                      # 隐藏维度           │
│      d_ff=64,                         # FFN维度            │
│      num_heads=2,                     # 注意力头数         │
│      opt_config=config                # 优化器配置         │
│  )                                                           │
│                                                              │
│  【训练单步】                                                │
│  ─────────────────────────────────────────────────────────  │
│  state := train_step(state, input_batch, label_batch)      │
│  loss := state.current_loss                                 │
│  step := state.global_step                                  │
│                                                              │
│  【多epoch训练】                                             │
│  ─────────────────────────────────────────────────────────  │
│  state := training_loop(                                     │
│      state,                                                  │
│      train_batches,     # 训练数据批次列表                 │
│      train_labels,      # 训练标签列表                     │
│      num_epochs=3,      # 训练轮数                         │
│      log_interval=10    # 日志记录间隔                     │
│  )                                                           │
│                                                              │
│  【保存检查点】                                              │
│  ─────────────────────────────────────────────────────────  │
│  save_checkpoint(state, "model_step_1000.ckpt")            │
│                                                              │
│  【加载检查点】                                              │
│  ─────────────────────────────────────────────────────────  │
│  state := load_checkpoint("model_step_1000.ckpt")          │
│                                                              │
│  【模型评估】                                                │
│  ─────────────────────────────────────────────────────────  │
│  eval_loss := evaluate(state, eval_batches, eval_labels)   │
│                                                              │
└──────────────────────────────────────────────────────────────┘

┌─ 📊 核心数据结构 ──────────────────────────────────────────┐
│                                                              │
│  【optimizer_config】优化器配置                             │
│  ├─ learning_rate: float          # 初始学习率             │
│  ├─ beta1: float                  # Adam β₁ (默认0.9)     │
│  ├─ beta2: float                  # Adam β₂ (默认0.999)   │
│  ├─ epsilon: float                # 数值稳定性 (默认1e-8) │
│  ├─ weight_decay: float           # L2正则化系数           │
│  ├─ warmup_steps: int             # 预热步数               │
│  └─ lr_schedule: string           # 学习率计划             │
│                                    # ("linear"/"cosine")    │
│                                                              │
│  【training_state】训练状态                                 │
│  ├─ blocks: []transformer_block   # Transformer层         │
│  ├─ optimizer: adam_state         # 优化器状态             │
│  ├─ tape: gradient_tape           # 计算图                 │
│  ├─ current_loss: float           # 当前损失               │
│  └─ global_step: int              # 全局步数               │
│                                                              │
│  【transformer_block】Transformer块                         │
│  ├─ attention: multihead_attention_state                    │
│  ├─ W_ff1, W_ff2: tensor          # FFN权重                │
│  ├─ b_ff1, b_ff2: tensor          # FFN偏置                │
│  └─ grad_*: tensor                # 对应梯度               │
│                                                              │
│  【multihead_attention_state】注意力状态                    │
│  ├─ num_heads: int                # 注意力头数             │
│  ├─ d_model: int                  # 模型维度               │
│  ├─ head_dim: int                 # 每头维度               │
│  ├─ W_Q, W_K, W_V, W_O: tensor   # 投影权重              │
│  ├─ b_Q, b_K, b_V, b_O: tensor   # 投影偏置              │
│  ├─ grad_*: tensor                # 权重梯度               │
│  └─ cache: attention_cache        # 前向缓存              │
│                                                              │
│  【adam_state】优化器状态                                   │
│  ├─ learning_rate: float          # 当前学习率             │
│  ├─ timestep: int                 # 时间步数               │
│  ├─ m: []tensor                   # 一阶矩 (梯度平均)      │
│  └─ v: []tensor                   # 二阶矩 (梯度平方平均)  │
│                                                              │
└──────────────────────────────────────────────────────────────┘

┌─ 🔀 关键算法总结 ──────────────────────────────────────────┐
│                                                              │
│  【MultiHead Attention】                                    │
│  ───────────────────────                                    │
│  1. Q = X @ W_Q + b_Q              # Query投影              │
│  2. K = X @ W_K + b_K              # Key投影                │
│  3. V = X @ W_V + b_V              # Value投影              │
│  4. Scores = (Q @ K^T) / √d_k      # 缩放点积               │
│  5. Weights = softmax(Scores)       # 注意力权重             │
│  6. Output = Weights @ V            # 加权求和              │
│  7. Final = Output @ W_O + b_O     # 输出投影              │
│                                                              │
│  【AdamW更新规则】                                           │
│  ─────────────────                                          │
│  m ← β₁ * m + (1-β₁) * g            # 一阶矩               │
│  v ← β₂ * v + (1-β₂) * g²           # 二阶矩               │
│  m̂ ← m / (1 - β₁^t)                 # 偏差修正              │
│  v̂ ← v / (1 - β₂^t)                 # 偏差修正              │
│  θ ← θ - α*(m̂/(√v̂+ε) + λθ)          # 参数更新 + weight decay │
│                                                              │
│  【反向传播】                                                │
│  ──────────                                                 │
│  对每个操作计算梯度:                                         │
│  • add:      ∇a=grad,  ∇b=grad                            │
│  • mul:      ∇a=grad*b, ∇b=grad*a                        │
│  • matmul:   ∇a=grad@b^T, ∇b=a^T@grad                    │
│  • softmax:  ∇x = p*(grad - (p*grad).sum())               │
│  • relu:     ∇x = grad if x>0 else 0                      │
│                                                              │
└──────────────────────────────────────────────────────────────┘

┌─ 💡 高级功能 ────────────────────────────────────────────────┐
│                                                              │
│  【梯度剪裁】                                                │
│  ───────────                                               │
│  clipped_grads = clip_grad_norm(gradients, max_norm=1.0)  │
│  • 计算梯度的L2范数                                         │
│  • 如果超过max_norm则按比例缩放                             │
│  • 防止梯度爆炸 (Gradient explosion)                       │
│                                                              │
│  【学习率调度】                                              │
│  ───────────                                               │
│  # Linear decay                                            │
│  lr = base_lr * (1 - progress)                            │
│                                                              │
│  # Cosine annealing                                        │
│  lr = base_lr * (1 + cos(π*progress)) / 2                 │
│                                                              │
│  # Linear warmup                                           │
│  if step < warmup_steps:                                   │
│    lr = base_lr * step / warmup_steps                      │
│                                                              │
│  【层归一化】                                                │
│  ───────────                                               │
│  LN(x) = (x - mean) / √(var + eps)                        │
│  • 数值稳定性: 小的epsilon值                                │
│  • 减少内部协变量转移 (Internal Covariate Shift)           │
│                                                              │
│  【数值稳定的Softmax】                                       │
│  ──────────────────                                        │
│  exp_stable = exp(x - max(x))                             │
│  softmax = exp_stable / sum(exp_stable)                   │
│  • 防止数值溢出                                              │
│  • 保持数值精度                                              │
│                                                              │
└──────────────────────────────────────────────────────────────┘

┌─ 🏗️ 完整训练管道示例 ────────────────────────────────────┐
│                                                              │
│  config := optimizer_config{                                │
│      learning_rate: 0.001,                                  │
│      beta1: 0.9, beta2: 0.999, epsilon: 1e-8,             │
│      weight_decay: 0.0001,                                  │
│      warmup_steps: 100,                                     │
│      lr_schedule: "cosine",                                 │
│  }                                                           │
│                                                              │
│  state := init_training_state(2, 32, 64, 2, config)       │
│                                                              │
│  # 训练循环                                                  │
│  state := training_loop(                                     │
│      state, train_batches, train_labels,                    │
│      num_epochs=3, log_interval=10                          │
│  )                                                           │
│                                                              │
│  # 评估                                                      │
│  eval_loss := evaluate(state, eval_batches, eval_labels)   │
│  println("Eval Loss: " + float_to_str(eval_loss))          │
│                                                              │
│  # 保存                                                      │
│  save_checkpoint(state, "final_model.ckpt")                │
│                                                              │
└──────────────────────────────────────────────────────────────┘

┌─ 📈 性能特性 ────────────────────────────────────────────────┐
│                                                              │
│  • Attention: O(seq² × d_model) 时间复杂度                 │
│  • Memory: O(num_layers × d_model²) 参数                   │
│  • Backward: ~2x 前向传播时间                              │
│  • Gradient Checkpointing: 框架就位                        │
│  • Distributed Training: 框架就位                          │
│                                                              │
└──────────────────────────────────────────────────────────────┘

┌─ 🔗 模块依赖关系 ──────────────────────────────────────────┐
│                                                              │
│  training_complete_integrated.s                             │
│    ├─→ attention_complete.s                                 │
│    │   └─→ math_ops.s                                       │
│    ├─→ autodiff_complete.s                                  │
│    │   └─→ math_ops.s                                       │
│    └─→ optimizer_adamw.s                                    │
│                                                              │
│  使用流程:                                                   │
│  1. 创建compute tape (autodiff)                             │
│  2. 前向传播 (math_ops + attention)                         │
│  3. 计算损失                                                 │
│  4. 反向传播 (autodiff)                                      │
│  5. 参数更新 (optimizer)                                     │
│                                                              │
└──────────────────────────────────────────────────────────────┘

┌─ 🎯 编译和运行 ────────────────────────────────────────────┐
│                                                              │
│  # 编译所有模块                                              │
│  $ bash build_ml_complete.sh                                │
│                                                              │
│  # 输出位置                                                  │
│  /Users/feifei/shuwen/neurx/build/ml_complete/             │
│  ├─ math_ops.ir                                             │
│  ├─ autodiff.ir                                             │
│  ├─ attention.ir                                            │
│  ├─ optimizer.ir                                            │
│  └─ training_integrated.ir                                  │
│                                                              │
│  # 源代码位置                                                │
│  /Users/feifei/shuwen/neurx/ml/                             │
│  /Users/feifei/shuwen/neurx/train/                          │
│                                                              │
└──────────────────────────────────────────────────────────────┘

╔════════════════════════════════════════════════════════════════╗
║                     实现完成! 🎉                               ║
║  一个完整的、可用于真实训练的深度学习框架，全部用S语言实现   ║
╚════════════════════════════════════════════════════════════════╝

EOF
