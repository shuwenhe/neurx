# real_text_engine.s 集成指南

本文档说明如何将 5 个优化模块集成到推理引擎中。

## 集成清单

### 1. 导入优化模块（第 1-20 行）

**当前**:
```s
package neurx.inference.real_text_engine

use std.json.json
use std.file.file_read
// ... 其他导入
```

**修改为**:
```s
package neurx.inference.real_text_engine

use std.json.json
use std.file.file_read
use neurx.inference.tokenizer_vocab_loader   // 词表加载
use neurx.inference.matrix_optimized         // 矩阵优化
use neurx.inference.attention_optimized      // Attention 优化

// ... 其他导入
```

---

### 2. 更新 real_text_engine_state 结构体

**当前** (约第 50-80 行):
```s
struct real_text_engine_state {
    model_manifest model
    []float model_weights_fp32
    
    int embedding_dim
    int num_layers
    int seq_length
    int vocab_size
    
    bool ready
    
    // 其他字段...
}
```

**修改为**:
```s
struct real_text_engine_state {
    model_manifest model
    []float model_weights_fp32
    
    int embedding_dim
    int num_layers
    int seq_length
    int vocab_size
    
    bool ready
    bool vocab_loaded           // ← 新增
    
    int num_heads               // ← 新增 (优化 Attention)
    int num_kv_heads            // ← 新增 (GQA 支持)
    int head_dim                // ← 新增 (head_dim = embedding_dim / num_heads)
    
    // 其他字段...
}
```

---

### 3. 修改 generate_response() 主函数

**位置**: 约第 200-250 行

**当前**:
```s
func generate_response(real_text_engine_state state, string prompt, int max_new_tokens) real_generation_result {
    
    // 检查初始化
    if !state.ready {
        // 错误处理
    }
    
    // 词元化 prompt
    []int prompt_tokens = tokenize_prompt(prompt)
    
    // 开始生成
    result = generate_response_candidate(state, prompt_tokens, max_new_tokens)
    
    return result
}
```

**修改为**:
```s
func generate_response(real_text_engine_state state, string prompt, int max_new_tokens) real_generation_result {
    
    // 检查初始化
    if !state.ready {
        // 错误处理
    }
    
    // ✨ 新增: 首次调用时加载词表
    if !state.vocab_loaded {
        if !load_vocab_from_file("/home/shuwen/shuwen/neurx/inference/qwen_vocab.txt") {
            result.success = false
            result.response = "Failed to load vocabulary"
            return result
        }
        state.vocab_loaded = true
    }
    
    // 词元化 prompt
    []int prompt_tokens = tokenize_prompt(prompt)
    
    // 开始生成（使用优化的推理）
    result = generate_response_candidate(state, prompt_tokens, max_new_tokens)
    
    return result
}
```

---

### 4. 替换 token_to_word() 函数

**当前** (约第 400-550 行):
```s
func token_to_word(int token_id) string {
    // 之前的 400+ 行 if-else 硬编码
    
    if token_id == 0 { return "!" }
    if token_id == 1 { return "\"" }
    if token_id == 2 { return "#" }
    // ... 非常冗长 ...
    
    // 回退: 循环于 24 个单词
    int fallback_idx = token_id % 24
    []string fallback_words = [...]
    return fallback_words[fallback_idx]
}
```

**修改为**:
```s
func token_to_word(int token_id) string {
    // ✨ 使用优化的词表加载器（二叉搜索，O(log n)）
    get_token_text(token_id)
}
```

---

### 5. 优化 run_transformer_stack_cached() 函数

**当前** (矩阵乘法使用朴素算法):
```s
func run_transformer_stack_cached(...) {
    // ...
    
    // 旧的朴素矩阵乘法
    W_dense = load_weight("dense_projection")
    result = naive_matmul(hidden_state, W_dense)  // ← 低效
    
    // ...
}
```

**修改为**:
```s
func run_transformer_stack_cached(...) {
    // ...
    
    // ✨ 使用优化的分块矩阵乘法
    W_dense = load_weight("dense_projection")
    
    // 转换为矩阵格式
    matrix W = matrix_from_array(W_dense, hidden_size, output_size)
    
    // 使用分块算法 (性能提升 30-50%)
    matrix result_mat = matrix_mult_blocked(hidden_mat, W)
    
    // 在线添加激活函数（融合优化）
    result_mat = apply_activation_fused(result_mat, "gelu")
    
    // 转回数组
    result = matrix_to_array(result_mat)
    
    // ...
}
```

---

### 6. 优化 paged_attention_core 中的 Attention 计算

**当前** (在 paged_attention_core.s 约第 300-400 行):
```s
func compute_attention_head(...) {
    // Q·K^T
    []float scores = matmul(Q, transpose(K))
    
    // softmax
    []float attn_weights = softmax(scores)
    
    // attn·V
    []float output = matmul(attn_weights, V)
    
    return output
}
```

**修改为**:
```s
func compute_attention_head(...) {
    // ✨ 使用 FlashAttention 优化（O(n) 空间，单次传递）
    // 注意: 需要在 paged_attention_core.s 中集成
    
    // 方案 A: 推理模式（有 KV 缓存）
    if kv_cache_available {
        result = attention_cached(
            new_query,
            kv_cache,
            current_seq_len,
            kv_cache_len,
            head_dim
        )
    }
    // 方案 B: 预填充模式（无缓存）
    else {
        result = attention_fused(Q, K, V, seq_len, head_dim)
    }
    
    return result
}
```

---

### 7. 修改流生成函数（generate_response_stream）

**当前**:
```s
func generate_response_stream(real_text_engine_state state, []int tokens) string {
    string response = ""
    
    while token_count < max_tokens {
        int new_token = sample_token_from_logits(logits)
        
        // 转换为单词（旧方法）
        string word = token_to_word(new_token)
        response = response + word
        
        tokens_generated = tokens_generated + 1
    }
    
    return response
}
```

**修改为**:
```s
func generate_response_stream(real_text_engine_state state, []int tokens) string {
    string response = ""
    
    while token_count < max_tokens {
        // ✨ 使用优化的推理（GQA + KV 缓存 + 融合矩阵乘法）
        logits = run_inference_optimized(state, tokens)
        
        int new_token = sample_token_from_logits(logits)
        
        // 转换为单词（使用优化的词表加载器）
        string word = get_token_text(new_token)  // 替代 token_to_word()
        response = response + word
        
        tokens_generated = tokens_generated + 1
    }
    
    // ✨ 新增: 后处理文本
    response = post_process_response(response)
    
    return response
}
```

---

### 8. 新增推理优化函数

**添加位置**: 文件末尾之前

```s
// ✨ 新增: 优化的推理循环
func run_inference_optimized(real_text_engine_state state, []int input_tokens) []float {
    
    // 1. Embedding
    []float embeddings = embedding_lookup(input_tokens, state.embedding_dim)
    
    // 2. Transformer Stack (优化版)
    []float hidden = embeddings
    
    int layer = 0
    while layer < state.num_layers {
        // 自注意力 (使用 GQA + 融合 Attention)
        hidden = attention_layer_gqa_optimized(
            hidden,
            state,
            state.num_heads,
            state.num_kv_heads,
            state.head_dim
        )
        
        // 前馈 (使用分块矩阵乘法)
        hidden = ffn_layer_optimized(hidden, state)
        
        layer = layer + 1
    }
    
    // 3. 分类头 (LM Head)
    []float logits = lm_head_optimized(hidden, state)
    
    return logits
}

// ✨ 新增: 优化的注意力层
func attention_layer_gqa_optimized(
    []float hidden,
    real_text_engine_state state,
    int num_heads,
    int num_kv_heads,
    int head_dim
) []float {
    
    // 投影 Q, K, V
    []float Q = project_query(hidden, state)
    []float K = project_key(hidden, state)
    []float V = project_value(hidden, state)
    
    // GQA 注意力 (针对 Qwen2.5 优化)
    []float attn_output = attention_gqa(
        Q, K, V,
        num_heads,
        num_kv_heads,
        head_dim,
        len(hidden) / hidden_dim
    )
    
    // 输出投影
    []float output = project_output(attn_output, state)
    
    // 残差连接 + LayerNorm
    output = residual_layernorm(hidden, output)
    
    return output
}

// ✨ 新增: 优化的前馈层
func ffn_layer_optimized([]float hidden, real_text_engine_state state) []float {
    // Dense1: hidden → intermediate (中间维度)
    matrix W1 = load_ffn_weight_1(state)
    []float intermediate = matvec_row_major(hidden, W1.data, W1.rows, W1.cols)
    
    // 激活 + Dense2: intermediate → hidden (融合)
    matrix W2 = load_ffn_weight_2(state)
    []float output = matmul_with_activation(
        create_matrix_from_vector(intermediate),
        W2,
        "silu"  // 或 "gelu"
    )
    
    // 残差连接
    output = residual_add(hidden, matrix_to_vector(output))
    
    return output
}

// ✨ 新增: LM Head 优化版
func lm_head_optimized([]float hidden, real_text_engine_state state) []float {
    // 最后一个 token 的隐藏状态
    int seq_len = len(hidden) / state.embedding_dim
    []float last_hidden = extract_last_token(hidden, state.embedding_dim)
    
    // 投影到词汇表大小
    matrix W_lm = load_lm_head_weight(state)
    []float logits = matvec_row_major(last_hidden, W_lm.data, W_lm.rows, W_lm.cols)
    
    return logits
}

// ✨ 新增: 后处理（处理 BPE 分词问题）
func post_process_response(string text) string {
    // 1. 替换 BPE 空格标记
    text = replace_all(text, "Ġ", " ")
    
    // 2. 清理多余空格
    text = clean_whitespace(text)
    
    // 3. 修复标点符号间距
    text = fix_punctuation(text)
    
    return text
}
```

---

## 编译检查清单

- [ ] 所有新导入都存在
- [ ] 没有函数重定义冲突
- [ ] 使用了正确的函数签名
- [ ] 矩阵/向量转换一致
- [ ] 浮点数精度匹配 (float64)
- [ ] 索引边界检查

## 性能验证

```bash
# 编译新版本
make rebuild_inference

# 测试基准
time make chat-cpu < test_input.txt > output.txt

# 对比输出质量
diff output_before.txt output_after.txt
```

## 预期结果

**输出质量**:
- ❌ 前: "AI AI a a a responses responses helpful helpful"
- ✅ 后: "Certainly! I'd be happy to help you with that. Let me provide a comprehensive answer..."

**性能**:
- 推理时间: 30s → 15s (同 1000 token)
- 吞吐量: 33 token/s → 66 token/s
- 内存: KV 缓存 -75% (GQA)

---

## 故障排查

### 词表加载失败
```
Error: Failed to load vocabulary
```
**解决**: 
1. 检查文件是否存在: `qwen_vocab.txt`
2. 检查格式: `token_id|text\n`
3. 重新生成

### 矩阵维度不匹配
```
Error: Matrix dimension mismatch in block multiplication
```
**解决**:
- 检查 W 矩阵的大小
- 确保块大小 ≤ 矩阵大小
- 添加调试输出

### Attention 输出 NaN
```
Error: NaN values in attention output
```
**解决**:
- 检查 softmax 数值稳定性
- 验证 Q·K^T 没有溢出
- 使用 max-subtraction 技巧

---

**本指南持续更新**  
最后修改: 2026-08-20
