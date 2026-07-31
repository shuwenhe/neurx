# 🏭 工业级 Pretrain/Posttrain 基础设施路线图

**当前状态**: ✅ LoRA 训练真正工作（2026-07-31）  
**目标**: 成为生产级的预训练/后训练基础设施

---

## 📊 当前成就 vs 工业标准

| 组件 | 当前状态 | 工业标准 | 差距 |
|------|---------|---------|------|
| **损失函数** | MSE Loss | CrossEntropy | ❌ 类型错误 |
| **模型前向** | Mock vectors | 24层Transformer | ❌ 完全缺失 |
| **数据流程** | init_gaussian() | Tokenizer+DataLoader | ❌ 完全缺失 |
| **优化器** | 手动梯度更新 | AdamW (momentum+variance) | ⚠️ 简化版 |
| **性能** | ~8秒/step (简化) | <1秒/step (GPU) | ❌ 1000× 慢 |
| **保存加载** | 跳过 | Safetensors | ❌ 未实现 |
| **评估** | 无 | Perplexity, MMLU | ❌ 完全缺失 |
| **分布式** | 单机 | DDP/FSDP | ❌ 完全缺失 |

---

## 🎯 三阶段路线图

### 🔴 **Phase 1: 核心训练管道（1-2周）** ← **当前焦点**

#### 任务 1.1: 集成 CrossEntropy Loss（1天）
**为什么最优先**: MSE 用于回归，CrossEntropy 用于分类（LLM每个位置预测下一个token）

**当前代码**:
```s
// neurx/posttrain/trainer/posttrain_main.s (Line 398-410)
float loss = 0.0
int out_idx = 0
while out_idx < output_size {
    float diff = q_output[out_idx] - target_q[out_idx]  // ❌ MSE
    loss = loss + diff * diff
    out_idx = out_idx + 1
}
loss = loss / output_size
```

**目标代码**:
```s
// 使用 neurx/loss/nn_losses.s 中的 cross_entropy_loss
use neurx.loss.nn_losses

// 假设 logits: []float (batch * seq_len * vocab_size)
//      targets: []int (batch * seq_len) 
tensor logits_tensor = neurx.tensor.new(logits, [batch, seq, vocab_size], true)
tensor target_tensor = neurx.tensor.new_int(targets, [batch, seq])
tensor loss_tensor = cross_entropy_loss(logits_tensor, target_tensor)
float loss = loss_tensor.data[0]
```

**实施步骤**:
1. ✅ 确认 `neurx/loss/nn_losses.s::cross_entropy_loss` 可用
2. ⏳ 在 `posttrain_main.s` 添加 `use neurx.loss.nn_losses`
3. ⏳ 修改 loss 计算代码（替换 MSE）
4. ⏳ 验证 loss 值合理（应该从 log(vocab_size)≈11.9 下降到 <5.0）

---

#### 任务 1.2: 实现真实 Tokenization（2-3天）
**当前**: `[]float prompt_vec = init_gaussian(hidden_size, 0.01)` (Mock数据)  
**需要**: 从文本 → token IDs

**加载 Tokenizer**:
```s
// 文件: neurx/tokenizer/qwen_tokenizer.s
use neurx.runtime.io

struct qwen_tokenizer {
    vocab: map<string, int>        // 词表 "糖尿病" → 12345
    vocab_size: int                 // 151,936
    bos_token_id: int              // <|begin_of_text|>
    eos_token_id: int              // <|end_of_text|>
}

func load_tokenizer(string model_dir) qwen_tokenizer {
    // 读取 tokenizer.json
    string vocab_path = model_dir + "/vocab.json"
    string vocab_json = read_file_to_string(vocab_path)
    
    // 解析 JSON (需要实现简单的 JSON parser)
    map<string, int> vocab = parse_vocab_json(vocab_json)
    
    qwen_tokenizer{
        vocab: vocab,
        vocab_size: 151936,
        bos_token_id: 151643,
        eos_token_id: 151645
    }
}

func tokenize(qwen_tokenizer tok, string text) []int {
    // 简化版: 按空格分词
    []string words = split_by_space(text)
    []int token_ids = []int{cap: len(words)}
    
    int i = 0
    while i < len(words) {
        string word = words[i]
        if has_key(tok.vocab, word) {
            token_ids[i] = tok.vocab[word]
        } else {
            token_ids[i] = 0  // <unk>
        }
        i = i + 1
    }
    token_ids
}
```

**DataLoader**:
```s
// 文件: neurx/data/medical_dataloader.s
struct training_sample {
    input_ids: []int       // [123, 456, 789, ...]
    labels: []int          // [456, 789, ..., eos] (shifted by 1)
    seq_len: int
}

func load_medical_dataset(
    string dataset_path,
    qwen_tokenizer tok,
    int max_samples
) []training_sample {
    // 读取 dataset/medical/train.json
    string json_str = read_file_to_string(dataset_path)
    
    // 解析 JSON
    []map<string, string> records = parse_json_array(json_str)
    
    []training_sample samples = []training_sample{cap: max_samples}
    int i = 0
    while i < max_samples and i < len(records) {
        string question = records[i]["question"]
        string answer = records[i]["answer"]
        string text = question + " " + answer
        
        []int token_ids = tokenize(tok, text)
        []int labels = shift_left(token_ids, 1)  // 下一个token预测
        
        samples[i] = training_sample{
            input_ids: token_ids,
            labels: labels,
            seq_len: len(token_ids)
        }
        i = i + 1
    }
    samples
}
```

---

#### 任务 1.3: 实现完整 Transformer Forward（5-7天）⚠️ **最关键**
**当前**: 跳过模型计算  
**需要**: Token → Embedding → 24层 → Logits

**架构**:
```
Input: [batch_size, seq_len] token IDs
  ↓
Embedding: [batch_size, seq_len, 896]
  ↓
24× Transformer Layer:
  - RMSNorm (Pre-Norm)
  - Multi-Head Attention (8 heads, RoPE position encoding)
  - Residual Connection
  - RMSNorm
  - MLP (SwiGLU activation: gate_proj, up_proj, down_proj)
  - Residual Connection
  ↓
Final RMSNorm
  ↓
LM Head: [batch_size, seq_len, 151936] logits
```

**文件结构**:
```
neurx/model/
  ├── qwen_config.s          # 模型配置
  ├── qwen_embedding.s       # Embedding层
  ├── qwen_attention.s       # Multi-Head Attention + RoPE
  ├── qwen_mlp.s             # SwiGLU MLP
  ├── qwen_layer.s           # 单个Transformer层
  ├── qwen_model.s           # 完整模型
  └── lora_integration.s     # LoRA注入
```

**实施步骤**:

**第1步: 加载权重** (1-2天)
```s
// neurx/model/weight_loader.s
use neurx.runtime.io

struct model_weights {
    // Embedding
    embed_tokens: []float  // [151936, 896]
    
    // 24 layers
    layers: []layer_weights
    
    // Final norm
    norm_weight: []float   // [896]
    
    // LM head
    lm_head: []float       // [151936, 896]
}

struct layer_weights {
    // Attention
    q_proj: []float        // [896, 896]
    k_proj: []float        // [896, 896]
    v_proj: []float        // [896, 896]
    o_proj: []float        // [896, 896]
    
    // MLP
    gate_proj: []float     // [896, 4864]
    up_proj: []float       // [896, 4864]
    down_proj: []float     // [4864, 896]
    
    // Norms
    input_layernorm: []float    // [896]
    post_attention_layernorm: []float  // [896]
}

func load_safetensors(string model_path) model_weights {
    // 使用 neurx/checkpoint/safetensors_reader.s
    safetensors_file sf = open_safetensors(model_path + "/model.safetensors")
    
    model_weights weights = model_weights{
        embed_tokens: get_tensor(sf, "model.embed_tokens.weight"),
        layers: []layer_weights{cap: 24},
        norm_weight: get_tensor(sf, "model.norm.weight"),
        lm_head: get_tensor(sf, "lm_head.weight")
    }
    
    int i = 0
    while i < 24 {
        string prefix = "model.layers." + i + "."
        weights.layers[i] = layer_weights{
            q_proj: get_tensor(sf, prefix + "self_attn.q_proj.weight"),
            k_proj: get_tensor(sf, prefix + "self_attn.k_proj.weight"),
            v_proj: get_tensor(sf, prefix + "self_attn.v_proj.weight"),
            o_proj: get_tensor(sf, prefix + "self_attn.o_proj.weight"),
            gate_proj: get_tensor(sf, prefix + "mlp.gate_proj.weight"),
            up_proj: get_tensor(sf, prefix + "mlp.up_proj.weight"),
            down_proj: get_tensor(sf, prefix + "mlp.down_proj.weight"),
            input_layernorm: get_tensor(sf, prefix + "input_layernorm.weight"),
            post_attention_layernorm: get_tensor(sf, prefix + "post_attention_layernorm.weight")
        }
        i = i + 1
    }
    
    weights
}
```

**第2步: RMSNorm** (0.5天)
```s
// neurx/nn/rms_norm.s
func rms_norm(
    []float x,          // Input: [batch, seq, hidden_size]
    []float weight,     // Learned weights: [hidden_size]
    int batch_size,
    int seq_len,
    int hidden_size,
    float eps           // 1e-6
) []float {
    []float output = []float{cap: batch_size * seq_len * hidden_size}
    
    int b = 0
    while b < batch_size {
        int s = 0
        while s < seq_len {
            int offset = (b * seq_len + s) * hidden_size
            
            // 计算 RMS
            float sum_sq = 0.0
            int h = 0
            while h < hidden_size {
                float val = x[offset + h]
                sum_sq = sum_sq + val * val
                h = h + 1
            }
            float rms = sqrt(sum_sq / (hidden_size as float) + eps)
            
            // Normalize + Scale
            h = 0
            while h < hidden_size {
                output[offset + h] = x[offset + h] / rms * weight[h]
                h = h + 1
            }
            
            s = s + 1
        }
        b = b + 1
    }
    output
}
```

**第3步: RoPE (Rotary Position Embedding)** (1天)
```s
// neurx/model/rope.s
func apply_rope(
    []float q,          // Query: [batch, seq, num_heads, head_dim]
    []float k,          // Key: [batch, seq, num_heads, head_dim]
    int batch_size,
    int seq_len,
    int num_heads,      // 14
    int head_dim,       // 64
    float theta         // 10000.0
) ([]float, []float) {
    // 预计算频率
    []float freqs = []float{cap: head_dim / 2}
    int i = 0
    while i < head_dim / 2 {
        freqs[i] = 1.0 / pow(theta, (2.0 * i) / (head_dim as float))
        i = i + 1
    }
    
    // 应用旋转
    []float q_rotated = []float{cap: len(q)}
    []float k_rotated = []float{cap: len(k)}
    
    int b = 0
    while b < batch_size {
        int s = 0
        while s < seq_len {
            int h = 0
            while h < num_heads {
                int offset = ((b * seq_len + s) * num_heads + h) * head_dim
                
                int d = 0
                while d < head_dim / 2 {
                    float angle = (s as float) * freqs[d]
                    float cos_val = cos(angle)
                    float sin_val = sin(angle)
                    
                    float q0 = q[offset + 2 * d]
                    float q1 = q[offset + 2 * d + 1]
                    q_rotated[offset + 2 * d] = q0 * cos_val - q1 * sin_val
                    q_rotated[offset + 2 * d + 1] = q0 * sin_val + q1 * cos_val
                    
                    float k0 = k[offset + 2 * d]
                    float k1 = k[offset + 2 * d + 1]
                    k_rotated[offset + 2 * d] = k0 * cos_val - k1 * sin_val
                    k_rotated[offset + 2 * d + 1] = k0 * sin_val + k1 * cos_val
                    
                    d = d + 1
                }
                h = h + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    
    (q_rotated, k_rotated)
}
```

**第4步: Multi-Head Attention** (2天)
```s
// neurx/model/qwen_attention.s
func multi_head_attention(
    []float hidden_states,  // [batch, seq, 896]
    layer_weights weights,
    int batch_size,
    int seq_len,
    int num_heads,          // 14
    int head_dim            // 64
) []float {
    int hidden_size = 896
    
    // Q, K, V projections
    []float q = matmul(hidden_states, weights.q_proj, batch_size * seq_len, hidden_size, hidden_size)
    []float k = matmul(hidden_states, weights.k_proj, batch_size * seq_len, hidden_size, hidden_size)
    []float v = matmul(hidden_states, weights.v_proj, batch_size * seq_len, hidden_size, hidden_size)
    
    // Reshape: [batch, seq, hidden] → [batch, seq, num_heads, head_dim]
    // (省略 reshape 代码，实际需要实现)
    
    // Apply RoPE
    (q, k) = apply_rope(q, k, batch_size, seq_len, num_heads, head_dim, 10000.0)
    
    // Attention scores: Q @ K^T / sqrt(head_dim)
    []float scores = attention_scores(q, k, batch_size, seq_len, num_heads, head_dim)
    
    // Softmax
    []float attn_weights = softmax_attention(scores, batch_size, seq_len, num_heads)
    
    // Attention @ V
    []float context = attention_weighted_sum(attn_weights, v, batch_size, seq_len, num_heads, head_dim)
    
    // Output projection
    []float output = matmul(context, weights.o_proj, batch_size * seq_len, hidden_size, hidden_size)
    
    output
}
```

**第5步: SwiGLU MLP** (1天)
```s
// neurx/model/qwen_mlp.s
func swiglu_mlp(
    []float hidden_states,  // [batch, seq, 896]
    layer_weights weights,
    int batch_size,
    int seq_len
) []float {
    int hidden_size = 896
    int intermediate_size = 4864
    
    // gate_proj (for SwiGLU activation)
    []float gate = matmul(hidden_states, weights.gate_proj, 
                          batch_size * seq_len, hidden_size, intermediate_size)
    
    // up_proj
    []float up = matmul(hidden_states, weights.up_proj,
                        batch_size * seq_len, hidden_size, intermediate_size)
    
    // SwiGLU: gate * silu(up)
    []float activated = []float{cap: len(gate)}
    int i = 0
    while i < len(gate) {
        float silu_val = up[i] / (1.0 + exp(-up[i]))  // SiLU activation
        activated[i] = gate[i] * silu_val
        i = i + 1
    }
    
    // down_proj
    []float output = matmul(activated, weights.down_proj,
                            batch_size * seq_len, intermediate_size, hidden_size)
    
    output
}
```

**第6步: 完整 Transformer Layer** (1天)
```s
// neurx/model/qwen_layer.s
func transformer_layer(
    []float hidden_states,
    layer_weights weights,
    int batch_size,
    int seq_len,
    int num_heads,
    int head_dim
) []float {
    int hidden_size = 896
    
    // Pre-norm for attention
    []float normed = rms_norm(hidden_states, weights.input_layernorm,
                               batch_size, seq_len, hidden_size, 1e-6)
    
    // Attention
    []float attn_output = multi_head_attention(normed, weights,
                                               batch_size, seq_len, num_heads, head_dim)
    
    // Residual connection
    []float after_attn = add_tensors(hidden_states, attn_output)
    
    // Pre-norm for MLP
    normed = rms_norm(after_attn, weights.post_attention_layernorm,
                      batch_size, seq_len, hidden_size, 1e-6)
    
    // MLP
    []float mlp_output = swiglu_mlp(normed, weights, batch_size, seq_len)
    
    // Residual connection
    []float output = add_tensors(after_attn, mlp_output)
    
    output
}
```

**第7步: 完整模型** (1天)
```s
// neurx/model/qwen_model.s
func forward(
    []int input_ids,         // [batch, seq]
    model_weights weights,
    int batch_size,
    int seq_len
) []float {
    int hidden_size = 896
    int vocab_size = 151936
    int num_heads = 14
    int head_dim = 64
    
    // Embedding lookup
    []float hidden_states = embedding_lookup(input_ids, weights.embed_tokens,
                                             batch_size, seq_len, hidden_size, vocab_size)
    
    // 24 Transformer layers
    int layer_idx = 0
    while layer_idx < 24 {
        hidden_states = transformer_layer(hidden_states, weights.layers[layer_idx],
                                         batch_size, seq_len, num_heads, head_dim)
        layer_idx = layer_idx + 1
    }
    
    // Final norm
    hidden_states = rms_norm(hidden_states, weights.norm_weight,
                            batch_size, seq_len, hidden_size, 1e-6)
    
    // LM head: [batch, seq, hidden_size] → [batch, seq, vocab_size]
    []float logits = matmul(hidden_states, weights.lm_head,
                           batch_size * seq_len, hidden_size, vocab_size)
    
    logits
}
```

---

#### 任务 1.4: 保存 LoRA Adapter（1-2天）
**当前**: 跳过（错误地认为有 struct bug）  
**今天证明**: Struct 赋值完全正常！

**实施**:
```s
// neurx/checkpoint/adapter_saver.s
use neurx.checkpoint.safetensors_writer

func save_lora_adapter(
    []named_lora_module modules,
    string output_dir,
    lora_config config
) bool {
    // 1. 创建 safetensors 文件
    safetensors_writer writer = create_writer()
    
    int i = 0
    while i < len(modules) {
        named_lora_module mod = modules[i]
        
        // 保存 lora_A
        string a_key = mod.name + ".lora_A.weight"
        []int a_shape = [config.rank, mod.in_dim]
        add_tensor(writer, a_key, mod.lora_A, a_shape)
        
        // 保存 lora_B
        string b_key = mod.name + ".lora_B.weight"
        []int b_shape = [mod.out_dim, config.rank]
        add_tensor(writer, b_key, mod.lora_B, b_shape)
        
        i = i + 1
    }
    
    // 写入文件
    string safetensors_path = output_dir + "/adapter_model.safetensors"
    write_safetensors(writer, safetensors_path)
    
    // 2. 创建 adapter_config.json (PEFT 格式)
    string config_json = "{\n"
    config_json = config_json + "  \"peft_type\": \"LORA\",\n"
    config_json = config_json + "  \"r\": " + config.rank + ",\n"
    config_json = config_json + "  \"lora_alpha\": " + config.alpha + ",\n"
    config_json = config_json + "  \"lora_dropout\": " + config.dropout + ",\n"
    config_json = config_json + "  \"target_modules\": [\"q_proj\", \"v_proj\"],\n"
    config_json = config_json + "  \"base_model_name_or_path\": \"Qwen/Qwen2.5-0.5B-Instruct\"\n"
    config_json = config_json + "}\n"
    
    string config_path = output_dir + "/adapter_config.json"
    write_file(config_path, config_json)
    
    true
}
```

---

### 🟡 **Phase 2: 性能优化（2-3周）**

#### 任务 2.1: 实现矩阵运算（1周）
**当前**: 元素级循环（131,072 iterations，~8秒）  
**需要**: `matmul`, `softmax`, `layer_norm` 高效实现

**优先级**:
1. **matmul** (最关键，80%的计算)
2. **softmax** (Attention + Loss)
3. **layer_norm / rms_norm**

**实施**:
```s
// neurx/ops/matmul.s
func matmul_naive(
    []float A,    // [M, K]
    []float B,    // [K, N]
    int M,
    int K,
    int N
) []float {
    []float C = []float{cap: M * N}
    
    int m = 0
    while m < M {
        int n = 0
        while n < N {
            float sum = 0.0
            int k = 0
            while k < K {
                sum = sum + A[m * K + k] * B[k * N + n]
                k = k + 1
            }
            C[m * N + n] = sum
            n = n + 1
        }
        m = m + 1
    }
    C
}

// 优化版本（分块，向量化）
func matmul_optimized([]float A, []float B, int M, int K, int N) []float {
    // TODO: 实现 Tiling/Blocking 优化
    // TODO: 调用 BLAS 库（如果S支持FFI）
}
```

#### 任务 2.2: 内存优化（3-5天）
- In-place 操作
- 内存池
- Gradient Checkpointing

#### 任务 2.3: 编译器优化（需S编译器团队支持）
- JIT 编译
- 循环展开
- SIMD 向量化

---

### 🟢 **Phase 3: 生产化（1-2月）**

#### 任务 3.1: 分布式训练
- Data Parallel
- Model Parallel
- ZeRO Optimizer

#### 任务 3.2: 评估系统
- Perplexity
- MMLU
- HumanEval

#### 任务 3.3: Checkpoint 管理
- 定期保存
- 断点恢复
- 多版本管理

---

## 📋 本周行动计划（2026-07-31 ~ 2026-08-06）

### Day 1-2: CrossEntropy Loss + Tokenization
- [ ] 集成 `neurx.loss.nn_losses::cross_entropy_loss`
- [ ] 实现简单的 tokenizer（读取 vocab.json）
- [ ] 测试: Loss 从 ~11.9 → <5.0

### Day 3-5: Transformer Forward (Part 1)
- [ ] 实现 Safetensors 权重加载
- [ ] 实现 RMSNorm
- [ ] 实现 Embedding lookup
- [ ] 测试: 单层前向传播无 NaN

### Day 6-7: Transformer Forward (Part 2)
- [ ] 实现 RoPE
- [ ] 实现 Multi-Head Attention（简化版）
- [ ] 测试: 完整前向传播

---

## ✅ 成功标准

**Phase 1 完成标志**:
```bash
# 1. 训练运行
make posttrain
# 输出:
# Epoch 1/3, Step 10: loss=11.234 → 5.678 → 2.345 (下降趋势)
# Perplexity: 123.45 → 45.67 → 10.23

# 2. Adapter 保存
ls -lh /home/shuwen/shuwen/posttrain/
# 输出:
# adapter_model.safetensors   45M
# adapter_config.json         1K

# 3. 推理验证（Python）
python test_inference.py
# 输出: 
# Input: "糖尿病的症状是什么？"
# Output: "糖尿病的常见症状包括多饮、多尿、多食和体重下降..."
```

---

## 🎯 关键指标

| 阶段 | Loss | Perplexity | 训练速度 | 推理质量 |
|------|------|-----------|---------|---------|
| **当前** | 29.41 (MSE) | N/A | ~8s/step | N/A |
| **Phase 1** | <5.0 (CE) | <150 | ~10s/step | 可读 |
| **Phase 2** | <3.0 | <20 | <1s/step | 合理 |
| **Phase 3** | <2.0 | <7 | <0.1s/step (GPU) | 优秀 |

---

## 📚 参考资料

- **Qwen2.5 架构**: https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct
- **LoRA 论文**: https://arxiv.org/abs/2106.09685
- **RoPE 位置编码**: https://arxiv.org/abs/2104.09864
- **SwiGLU 激活**: https://arxiv.org/abs/2002.05202

---

## 🔄 更新日志

- **2026-07-31**: 创建文档
  - ✅ LoRA 训练真正工作（Loss=29.41，权重更新）
  - ✅ 修复 lora_B 冷启动问题
  - ✅ 证明 Struct 赋值没问题
  - 🎯 下一步: CrossEntropy Loss + Tokenization
