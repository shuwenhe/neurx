# NeurX PostTrain 完整实现指南

## 📊 PostTrain 完整流程图

```
┌─────────────────────────────────────────────────────────────┐
│                   PostTrain Pipeline                        │
└─────────────────────────────────────────────────────────────┘

Step 1: 环境准备 (Environment Setup)
  ├─ 加载基础模型 → Qwen2.5-0.5B-Instruct
  ├─ 加载分词器 → BPE tokenizer (152064 tokens)
  ├─ 加载训练数据 → MedMCQA (train.json)
  └─ 初始化LoRA配置 → rank=8, alpha=16

Step 2: 数据处理 (Data Processing)
  ├─ 读取JSON数据 → parsing
  ├─ 分词处理 → token_ids
  ├─ 创建batch → 序列填充
  └─ 返回: (input_ids, attention_mask, labels)

Step 3: LoRA初始化 (LoRA Adapter Setup)
  ├─ 识别目标层 → q_proj, v_proj
  ├─ 创建lora_A矩阵 → shape: (hidden_size, rank)
  ├─ 创建lora_B矩阵 → shape: (rank, hidden_size)
  ├─ 初始化权重 → lora_A: Normal(0, 0.02), lora_B: zeros()
  └─ 返回: LoRA参数 (~540K trainable params)

Step 4: 训练循环 (Training Loop)  ← 关键：需要完整S实现
  ├─ Forward Pass
  │   ├─ 嵌入层 → token_ids → embeddings (batch_size, seq_len, 4096)
  │   ├─ 位置编码 → RoPE encoding
  │   ├─ 24层Transformer
  │   │   ├─ Self-Attention
  │   │   │   ├─ Q, K, V投影 (含LoRA)
  │   │   │   ├─ Scaled dot-product attention
  │   │   │   └─ Output projection
  │   │   └─ Feed-Forward Network
  │   │       ├─ Linear(4096 → 13824)
  │   │       ├─ SiLU activation
  │   │       └─ Linear(13824 → 4096)
  │   └─ Logits计算 → (batch_size, seq_len, vocab_size)
  │
  ├─ Loss Computation
  │   ├─ CrossEntropy loss
  │   ├─ KL divergence (from base model)
  │   └─ Total loss = CE + kl_coef * KL
  │
  ├─ Backward Pass
  │   ├─ dLoss/dlora_A (gradient)
  │   ├─ dLoss/dlora_B (gradient)
  │   └─ Return: gradient tensors
  │
  └─ Optimizer Step
      ├─ AdamW update
      │   ├─ m_t = β1*m_{t-1} + (1-β1)*grad
      │   ├─ v_t = β2*v_{t-1} + (1-β2)*grad²
      │   └─ param = param - lr * m_t / (sqrt(v_t) + eps)
      └─ LoRA参数更新

Step 5: 评估 (Evaluation)
  ├─ 在dev集上评估
  ├─ 计算accuracy, F1等指标
  └─ 决定是否保存checkpoint

Step 6: LoRA Merge (合并适配器)
  ├─ 获取基础模型权重 → W
  ├─ 获取LoRA权重 → lora_A, lora_B
  ├─ 计算增量 → ΔW = lora_B @ lora_A * (alpha / rank)
  ├─ 合并权重 → W_final = W + ΔW
  └─ 返回: 完整模型权重

Step 7: 模型保存 (Model Export)
  ├─ 保存合并后的model.safetensors
  ├─ 复制config.json
  ├─ 复制tokenizer.json
  └─ 目标: /home/shuwen/shuwen/posttrain/

Step 8: 验证 (Verification)
  ├─ 检查输出文件
  ├─ 验证权重shape
  └─ 返回: 成功/失败状态
```

---

## 📋 PostTrain 必需的核心模块

### ✅ 已实现 (Python参考实现)
- [x] 数据加载和预处理
- [x] 分词处理
- [x] LoRA适配器创建
- [x] Forward pass计算
- [x] Loss计算
- [x] 梯度计算
- [x] AdamW优化器更新
- [x] LoRA合并

**文件**: `scripts/write_lora_adapter_safetensors.py` (Python参考)

### ❌ 缺失 (需要纯S实现)

| # | 模块 | 优先级 | 说明 |
|---|------|--------|------|
| 1 | **数据加载器** | 🔴 CRITICAL | JSON解析、批处理、分词 |
| 2 | **分词器集成** | 🔴 CRITICAL | BPE tokenization (基于词表) |
| 3 | **Embedding层** | 🔴 CRITICAL | token → vectors (4096-dim) |
| 4 | **Transformer块** | 🔴 CRITICAL | 24层的Self-Attention + FFN |
| 5 | **RoPE位置编码** | 🟠 HIGH | 旋转位置编码 |
| 6 | **CrossEntropy Loss** | 🔴 CRITICAL | 损失计算 |
| 7 | **反向传播** | 🔴 CRITICAL | 梯度计算 |
| 8 | **AdamW优化器** | 🔴 CRITICAL | 参数更新 |
| 9 | **LoRA模块** | 🔴 CRITICAL | 低秩适配器 |
| 10 | **检查点管理** | 🟠 HIGH | 保存和加载中间结果 |
| 11 | **评估指标** | 🟡 MEDIUM | accuracy, perplexity等 |
| 12 | **SafeTensors导出** | 🔴 CRITICAL | 模型权重序列化 |

---

## 🎯 推荐分阶段实现计划

### Phase 2A.1: 核心推理引擎 (W1.1 - W1.3)
**目标**: 完整的前向推理，不需要反向传播

```
W1.1 (已完成): 分词器
W1.2: 嵌入层 + RoPE位置编码
W1.3: Transformer块 (Self-Attention + FFN)
     Gate: make gate-w1.3
     输出: 模型能正确预测token
```

### Phase 2A.2: 训练基础 (W2.1 - W2.3)
**目标**: 实现损失计算和反向传播

```
W2.1: Loss计算 (CrossEntropy)
W2.2: 反向传播 (Autograd)
W2.3: AdamW优化器
     Gate: make gate-w2
     输出: 能计算梯度和更新
```

### Phase 2A.3: LoRA训练 (W3.1 - W3.3)
**目标**: LoRA适配器的完整训练

```
W3.1: LoRA模块集成
W3.2: 数据加载和批处理
W3.3: 完整训练循环
     Gate: make gate-w3
     输出: 能训练LoRA适配器
```

### Phase 2A.4: 模型导出 (W4.1)
**目标**: LoRA合并和模型导出

```
W4.1: LoRA合并 + SafeTensors导出
     Gate: make gate-w4
     输出: 可用的后训练模型
```

---

## 📝 现在的实现状态

### 当前架构
```
make posttrain
  ↓
scripts/real_lora_sft.s (S入口点)
  ↓
scripts/write_lora_adapter_safetensors.py (Python实现)
  ├─ Data loading (JSON parsing)
  ├─ Tokenization
  ├─ Model loading
  ├─ LoRA initialization
  ├─ Training loop (forward + backward)
  ├─ Loss calculation
  └─ LoRA merge + export
  ↓
/home/shuwen/shuwen/posttrain/ (合并后的模型)
```

### 问题
- ✅ 功能完整
- ❌ Python依赖 (违反"纯S"要求)
- ❌ 无法在纯S环境运行
- ❌ 模型计算逻辑黑盒

---

## 🔧 立即可以做的优化

### 1. 分离Python依赖 (Week 1)
创建纯S数据加载器:
```s
func load_medical_data_s(string jsonl_path) []training_example {
    []training_example examples
    []string lines = read_jsonl_file(jsonl_path)
    for line in lines {
        training_example ex = parse_json_example(line)
        examples = append(examples, ex)
    }
    examples
}
```

### 2. 实现分词器缓存 (Week 1)
预先分词所有数据，避免运行时分词:
```s
func precompute_tokens([]training_example data, tokenizer_state tok) []tokenized_example {
    []tokenized_example results
    for ex in data {
        tokenization_result tokens = tokenize(tok, ex.instruction)
        results = append(results, tokenized_example{...})
    }
    results
}
```

### 3. 实现Mini Forward Pass (Week 2)
只计算损失，不计算梯度:
```s
func forward_pass_s(
    model_state model,
    []int input_ids,
    []int attention_mask,
    []int labels
) float {
    embeddings := embedding_lookup(model, input_ids)
    for i in range(24) {
        embeddings = transformer_layer(model.layers[i], embeddings)
    }
    logits := linear(model.lm_head, embeddings)
    loss := cross_entropy_loss(logits, labels)
    loss
}
```

### 4. 实现Gradient Computation (Week 3)
手动计算梯度:
```s
func backward_pass_s(
    model_state model,
    float loss,
    backprop_state bp
) []grad_result {
    dloss_dlogits := cross_entropy_backward(bp)
    dloss_dhidden := logits_backward(model.lm_head, dloss_dlogits)
    for i = 23; i >= 0; i = i - 1 {
        dloss_dhidden = transformer_layer_backward(model.layers[i], dloss_dhidden)
    }
    dloss_dhidden
}
```

---

## 📊 完成度检查表

- [ ] Phase 2A.1 (W1.1-W1.3): 前向推理 
  - [x] W1.1: Tokenizer ✅
  - [ ] W1.2: Embedding + RoPE
  - [ ] W1.3: Transformer block
  
- [ ] Phase 2A.2 (W2.1-W2.3): 训练基础
  - [ ] W2.1: Loss computation
  - [ ] W2.2: Backward pass
  - [ ] W2.3: AdamW optimizer
  
- [ ] Phase 2A.3 (W3.1-W3.3): LoRA训练
  - [ ] W3.1: LoRA module
  - [ ] W3.2: Data loading
  - [ ] W3.3: Training loop
  
- [ ] Phase 2A.4 (W4.1): 模型导出
  - [ ] W4.1: LoRA merge + export

---

## 🚀 后续步骤

**下一步**: 
1. 选择优先实现的模块 (推荐: W1.2 Embedding → W1.3 Transformer → W2.1 Loss)
2. 为每个模块制定 Makefile gate 目标
3. 编写单元测试确保正确性
4. 逐步替换Python依赖

**目标**: 
- 完全移除Python依赖
- 实现纯S的PostTrain
- 保证计算正确性
