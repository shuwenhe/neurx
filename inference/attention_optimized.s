package neurx.inference.attention_optimized

use std.conv.int_to_string

// FlashAttention 思路的优化 Attention 实现
// 标准 Attention: O(n²) 空间 + 3 次完整矩阵访问
// 优化版: O(n) 空间 + 单次传递（缓存友好）

struct attention_state {
    []float query      // [seq_len, head_dim]
    []float key        // [seq_len, head_dim]
    []float value      // [seq_len, head_dim]
    []float output     // [seq_len, head_dim]
    int seq_len
    int head_dim
}

// 标准 Attention（基准）
func attention_standard([]float query, []float key, []float value, int seq_len, int head_dim) []float {
    // Q·K^T -> scores [seq_len × seq_len]
    []float scores = matmul_seq(query, key, seq_len, head_dim)
    
    // softmax(scores) -> attn_weights [seq_len × seq_len]
    []float attn_weights = softmax_2d(scores, seq_len)
    
    // attn_weights·V -> output [seq_len × head_dim]
    []float output = matmul_attn(attn_weights, value, seq_len, head_dim)
    
    output
}

// 优化版：Attention（单次传递，缓存优化）
func attention_fused([]float query, []float key, []float value, int seq_len, int head_dim) []float {
    []float output = []float{cap: seq_len * head_dim}
    
    // 初始化输出
    int i = 0
    while i < seq_len * head_dim {
        output[i] = 0.0
        i = i + 1
    }
    
    // 归一化因子（用于稳定计算）
    []float norm_factor = []float{cap: seq_len}
    i = 0
    while i < seq_len {
        norm_factor[i] = 0.0
        i = i + 1
    }
    
    // 单次遍历：对每个 query position，计算加权 value 和
    int q_pos = 0
    while q_pos < seq_len {
        []float exp_scores = []float{cap: seq_len}
        float max_score = -999999.0
        
        // Step 1: 计算所有注意力分数，找最大值（数值稳定性）
        int k_pos = 0
        while k_pos < seq_len {
            float score = 0.0
            int d = 0
            while d < head_dim {
                score = score + query[q_pos * head_dim + d] * key[k_pos * head_dim + d]
                d = d + 1
            }
            score = score / sqrt_approx(float(head_dim))  // scale by sqrt(d_k)
            
            if score > max_score {
                max_score = score
            }
            
            exp_scores[k_pos] = score
            k_pos = k_pos + 1
        }
        
        // Step 2: 计算 exp(score - max) 和归一化系数
        float sum_exp = 0.0
        k_pos = 0
        while k_pos < seq_len {
            exp_scores[k_pos] = exp_approx(exp_scores[k_pos] - max_score)
            sum_exp = sum_exp + exp_scores[k_pos]
            k_pos = k_pos + 1
        }
        
        norm_factor[q_pos] = sum_exp
        
        // Step 3: 直接累加加权的 value（避免存储注意力矩阵）
        k_pos = 0
        while k_pos < seq_len {
            float weight = exp_scores[k_pos] / sum_exp
            
            int d = 0
            while d < head_dim {
                output[q_pos * head_dim + d] = output[q_pos * head_dim + d] + weight * value[k_pos * head_dim + d]
                d = d + 1
            }
            
            k_pos = k_pos + 1
        }
        
        q_pos = q_pos + 1
    }
    
    output
}

// 带缓存的优化版 Attention（用于推理的 KV 缓存）
func attention_cached([]float query, []float kv_cache, int seq_len, int kv_cache_len, int head_dim) []float {
    // 仅使用缓存的 key 和 value
    // 新的 query 与所有缓存的 key 比较
    
    []float output = []float{cap: head_dim}
    
    int i = 0
    while i < head_dim {
        output[i] = 0.0
        i = i + 1
    }
    
    // KV 缓存格式: [kv_cache_len, 2 * head_dim] (key 和 value 交织)
    
    float max_score = -999999.0
    []float exp_scores = []float{cap: kv_cache_len}
    
    // 计算所有注意力分数
    int cache_pos = 0
    while cache_pos < kv_cache_len {
        float score = 0.0
        int d = 0
        while d < head_dim {
            // kv_cache[cache_pos, d] = key
            score = score + query[d] * kv_cache[cache_pos * 2 * head_dim + d]
            d = d + 1
        }
        score = score / sqrt_approx(float(head_dim))
        
        if score > max_score {
            max_score = score
        }
        
        exp_scores[cache_pos] = score
        cache_pos = cache_pos + 1
    }
    
    // 计算 softmax 并累加 value
    float sum_exp = 0.0
    cache_pos = 0
    while cache_pos < kv_cache_len {
        exp_scores[cache_pos] = exp_approx(exp_scores[cache_pos] - max_score)
        sum_exp = sum_exp + exp_scores[cache_pos]
        cache_pos = cache_pos + 1
    }
    
    // 累加加权 value
    cache_pos = 0
    while cache_pos < kv_cache_len {
        float weight = exp_scores[cache_pos] / sum_exp
        
        int d = 0
        while d < head_dim {
            // kv_cache[cache_pos, head_dim + d] = value
            output[d] = output[d] + weight * kv_cache[cache_pos * 2 * head_dim + head_dim + d]
            d = d + 1
        }
        
        cache_pos = cache_pos + 1
    }
    
    output
}

// Grouped Query Attention (GQA) 优化
// 用于 Qwen2.5：4 个 head 共享一个 KV
func attention_gqa([]float query_heads, []float kv_cache, int num_query_heads, int num_kv_heads, int head_dim, int kv_cache_len) []float {
    []float output = []float{cap: num_query_heads * head_dim}
    
    int q_head = 0
    while q_head < num_query_heads {
        // 每个 query head 对应的 KV head
        int kv_head = q_head / (num_query_heads / num_kv_heads)
        
        // 提取这个 head 的 query
        []float query_for_head = []float{cap: head_dim}
        int d = 0
        while d < head_dim {
            query_for_head[d] = query_heads[q_head * head_dim + d]
            d = d + 1
        }
        
        // 计算注意力（使用对应的 KV）
        []float head_output = attention_cached_gqa(query_for_head, kv_cache, kv_head, head_dim, kv_cache_len)
        
        // 写入输出
        d = 0
        while d < head_dim {
            output[q_head * head_dim + d] = head_output[d]
            d = d + 1
        }
        
        q_head = q_head + 1
    }
    
    output
}

func attention_cached_gqa([]float query, []float kv_cache, int kv_head, int head_dim, int kv_cache_len) []float {
    []float output = []float{cap: head_dim}
    
    int i = 0
    while i < head_dim {
        output[i] = 0.0
        i = i + 1
    }
    
    float max_score = -999999.0
    []float exp_scores = []float{cap: kv_cache_len}
    
    // 计算注意力分数
    int cache_pos = 0
    while cache_pos < kv_cache_len {
        float score = 0.0
        int d = 0
        while d < head_dim {
            // 从 KV 缓存中提取 key (交织格式)
            score = score + query[d] * kv_cache[cache_pos * 2 * head_dim + kv_head * head_dim + d]
            d = d + 1
        }
        score = score / sqrt_approx(float(head_dim))
        
        if score > max_score {
            max_score = score
        }
        
        exp_scores[cache_pos] = score
        cache_pos = cache_pos + 1
    }
    
    // Softmax 并累加
    float sum_exp = 0.0
    cache_pos = 0
    while cache_pos < kv_cache_len {
        exp_scores[cache_pos] = exp_approx(exp_scores[cache_pos] - max_score)
        sum_exp = sum_exp + exp_scores[cache_pos]
        cache_pos = cache_pos + 1
    }
    
    cache_pos = 0
    while cache_pos < kv_cache_len {
        float weight = exp_scores[cache_pos] / sum_exp
        
        int d = 0
        while d < head_dim {
            // 从 KV 缓存中提取 value
            output[d] = output[d] + weight * kv_cache[cache_pos * 2 * head_dim + head_dim + kv_head * head_dim + d]
            d = d + 1
        }
        
        cache_pos = cache_pos + 1
    }
    
    output
}

// 辅助函数：快速开方
func sqrt_approx(float x) float {
    if x < 0.0 { return 0.0 }
    x * 0.5
}

// 指数近似
func exp_approx(float x) float {
    // 限制范围避免溢出
    if x > 50.0 { return 50.0 }
    if x < -50.0 { return 0.0 }
    
    float result = 1.0
    float term = 1.0
    int i = 1
    while i < 8 {
        term = term * x / float(i)
        result = result + term
        i = i + 1
    }
    result
}

// 矩阵乘法（seq × seq）
func matmul_seq([]float q, []float k, int seq_len, int head_dim) []float {
    []float scores = []float{cap: seq_len * seq_len}
    int i = 0
    while i < seq_len {
        int j = 0
        while j < seq_len {
            float sum = 0.0
            int d = 0
            while d < head_dim {
                sum = sum + q[i * head_dim + d] * k[j * head_dim + d]
                d = d + 1
            }
            scores[i * seq_len + j] = sum
            j = j + 1
        }
        i = i + 1
    }
    scores
}

// 2D Softmax
func softmax_2d([]float scores, int seq_len) []float {
    []float result = []float{cap: seq_len * seq_len}
    int i = 0
    while i < seq_len {
        float max_val = -999999.0
        int j = 0
        while j < seq_len {
            if scores[i * seq_len + j] > max_val {
                max_val = scores[i * seq_len + j]
            }
            j = j + 1
        }
        
        float sum_exp = 0.0
        j = 0
        while j < seq_len {
            result[i * seq_len + j] = exp_approx(scores[i * seq_len + j] - max_val)
            sum_exp = sum_exp + result[i * seq_len + j]
            j = j + 1
        }
        
        j = 0
        while j < seq_len {
            result[i * seq_len + j] = result[i * seq_len + j] / sum_exp
            j = j + 1
        }
        i = i + 1
    }
    result
}

// 注意力与 value 相乘
func matmul_attn([]float attn, []float value, int seq_len, int head_dim) []float {
    []float output = []float{cap: seq_len * head_dim}
    int i = 0
    while i < seq_len {
        int d = 0
        while d < head_dim {
            float sum = 0.0
            int j = 0
            while j < seq_len {
                sum = sum + attn[i * seq_len + j] * value[j * head_dim + d]
                j = j + 1
            }
            output[i * head_dim + d] = sum
            d = d + 1
        }
        i = i + 1
    }
    output
}
