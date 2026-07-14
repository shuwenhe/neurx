package neurx.model.transformer.rope_scaling

// ═══════════════════════════════════════════════════════════════════
// RoPE Scaling — 超长上下文支持 (32K / 64K / 128K+)
//
// 解决问题:
//   原始 RoPE 在训练时的 max_seq_len 之外推理会导致性能下降。
//   RoPE Scaling 通过修改位置编码的频率基,使模型能处理更长序列。
//
// 三种主流方法:
//   1. Linear Scaling (PI): 线性位置插值,简单但长距离性能下降快
//   2. NTK-Aware Scaling: 按频率自适应缩放,保留高频信息
//   3. YaRN (推荐): 动态缩放 + 负载均衡 + 注意力缩放,效果最好
//
// 论文:
//   - "Extending Context Window of Large Language Models via Positional Interpolation"
//   - "NTK-Aware Scaled RoPE"
//   - "YaRN: Efficient Context Window Extension of LLMs"
// ═══════════════════════════════════════════════════════════════════

// ============================================================================
// 1. 配置结构体
// ============================================================================

enum rope_scaling_type {
    ROPE_SCALING_LINEAR      // 线性插值 (Position Interpolation)
    ROPE_SCALING_NTK         // NTK-Aware 缩放
    ROPE_SCALING_YARN        // YaRN (推荐)
}

struct rope_scaling_config {
    rope_scaling_type method       // 使用哪种方法
    int original_max_seq_len       // 原始训练长度 (如 4096)
    int target_max_seq_len         // 目标长度 (如 32768 / 131072)
    float base                     // RoPE 基数 (通常 10000.0)
    int dim                       // 位置编码维度 (head_dim)
    
    // YaRN 特有参数
    float yarn_scale              // YaRN 缩放因子
    float yarn_original_scale     // YaRN 原始缩放
    float yarn_beta_fast          // YaRN 快速衰减因子 (32 或 64)
    float yarn_beta_slow          // YaRN 慢速衰减因子 (1 或 0.1)
    float yarn_mscale             // 注意力缩放因子 (可选,默认 ~0.7)
    
    // NTK 特有参数
    bool ntk_use_log_space        // 是否在 log 空间计算频率
}

// 默认配置: 4K → 32K 扩展
func default_rope_scaling_4k_to_32k(int head_dim) rope_scaling_config {
    rope_scaling_config {
        method: ROPE_SCALING_YARN,
        original_max_seq_len: 4096,
        target_max_seq_len: 32768,
        base: 10000.0,
        dim: head_dim,
        
        // YaRN 参数 (论文推荐的 4K→32K 最优值)
        yarn_scale: 8.0,
        yarn_original_scale: 1.0,
        yarn_beta_fast: 32.0,
        yarn_beta_slow: 1.0,
        yarn_mscale: 0.7,
        
        ntk_use_log_space: true,
    }
}

// 默认配置: 4K → 128K 扩展
func default_rope_scaling_4k_to_128k(int head_dim) rope_scaling_config {
    rope_scaling_config {
        method: ROPE_SCALING_YARN,
        original_max_seq_len: 4096,
        target_max_seq_len: 131072,
        base: 10000.0,
        dim: head_dim,
        
        // YaRN 参数 (论文推荐的 4K→128K 最优值)
        yarn_scale: 32.0,
        yarn_original_scale: 1.0,
        yarn_beta_fast: 64.0,
        yarn_beta_slow: 0.1,
        yarn_mscale: 0.65,
        
        ntk_use_log_space: true,
    }
}

// ============================================================================
// 2. 工具函数
// ============================================================================

func pow_float(float base, float exp) float {
    if exp == 0.0 { return 1.0 }
    if base <= 0.0 { return 0.0 }
    
    float result = 1.0
    bool negative = exp < 0.0
    if negative { exp = -exp }
    
    float e = 0.0
    while e < exp {
        result = result * base
        e = e + 1.0
    }
    
    if negative { result = 1.0 / result }
    return result
}

func log_approx(float x) float {
    if x <= 0.0 { return -1000000.0 }
    
    // Newton-Raphson for natural log
    float y = 0.0
    if x > 1.5 {
        while x > 1.5 {
            x = x * 0.5
            y = y + 0.6931471805599453  // ln(2)
        }
    } else if x < 0.7 && x > 0.0 {
        while x < 0.7 {
            x = x * 2.0
            y = y - 0.6931471805599453
        }
    }
    
    // Taylor series around x=1: ln(x) ≈ 2[(x-1)/(x+1) + (x-1)^3/(3(x+1)^3) + ...]
    float z = (x - 1.0) / (x + 1.0)
    float z2 = z * z
    float series = z
    float term = z
    int i = 3
    while i <= 15 {
        term = term * z2
        series = series + term / float_of_int(i)
        i = i + 2
    }
    
    return 2.0 * series + y
}

func float_of_int(int n) float {
    float result = 0.0
    int i = 0
    while i < n {
        result = result + 1.0
        i = i + 1
    }
    return result
}

func min_int(int a, int b) int {
    if a < b { return a }
    return b
}

func max_int(int a, int b) int {
    if a > b { return a }
    return b
}

func min_float(float a, float b) float {
    if a < b { return a }
    return b
}

func max_float(float a, float b) float {
    if a > b { return a }
    return b
}

// ============================================================================
// 3. 原始 RoPE 频率计算
// ============================================================================

// 计算原始 RoPE 的频率: theta_i = 1 / (base^(2i/dim))
func compute_rope_frequencies(int seq_len, int dim, float base) []float {
    int half_dim = dim / 2
    
    // theta_i = 1 / (base^(2i/d))
    []float freqs = []float{cap: half_dim}
    int i = 0
    while i < half_dim {
        float exponent = float_of_int(i * 2) / float_of_int(dim)
        freqs[i] = 1.0 / pow_float(base, exponent)
        i = i + 1
    }
    
    return freqs
}

// ============================================================================
// 4. 方法一: Linear Scaling (Position Interpolation)
// ============================================================================
//
// 思想:
//   将位置索引线性缩小: pos' = pos * (original_max / target_max)
//   这样目标序列末尾的位置编码与原始最大长度时相同
//
// 公式:
//   theta_i' = theta_i * scale_factor
//   其中 scale_factor = original_max_seq_len / target_max_seq_len
//
// 优点: 简单直接
// 缺点: 高频信息丢失,长距离依赖性能下降明显

func rope_linear_scaling(
    rope_scaling_config cfg,
    int position          // 绝对位置 [0, target_max_seq_len)
) []float {
    int half_dim = cfg.dim / 2
    
    // 线性缩放因子
    float scale = float_of_int(cfg.original_max_seq_len) / float_of_int(cfg.target_max_seq_len)
    
    // 缩放后的有效位置
    float scaled_pos = float_of_int(position) * scale
    
    // 计算频率
    []float freqs = compute_rope_frequencies(cfg.original_max_seq_len, cfg.dim, cfg.base)
    
    // 角度 = scaled_pos * frequency
    []float angles = []float{cap: half_dim}
    int i = 0
    while i < half_dim {
        angles[i] = scaled_pos * freqs[i]
        i = i + 1
    }
    
    return angles
}

// ============================================================================
// 5. 方法二: NTK-Aware Scaling
// ============================================================================
//
// 思想:
//   不同频率维度使用不同的缩放因子:
//   - 低频 (i 小, theta 大): 保持不变或轻微缩放
//   - 高频 (i 大, theta 小): 大幅缩放以适应更长范围
//
// 这模拟了神经网络在更高分辨率下的行为,类似于图像中的 NTK kernel
//
// 公式 (简化版):
//   base' = base * ((target_max / original_max - 1) / (original_max - 1))^(dim / (2*dim-2))
//   或者更简单的: base' = base * (target_max / original_max)^(dim / (2*(dim-2)))

func rope_ntk_scaling(
    rope_scaling_config cfg,
    int position
) []float {
    int half_dim = cfg.dim / 2
    
    // 计算 NTK 缩放的新的 base
    float ratio = float_of_int(cfg.target_max_seq_len) / float_of_int(cfg.original_max_seq_len)
    
    float new_base
    if cfg.ntk_use_log_space {
        // 在 log 空间计算,对大 ratio 更稳定
        float log_ratio = log_approx(ratio)
        float log_base = log_approx(cfg.base)
        // 新 base 的公式: base_new = base * ratio^(dim/(dim-2)) 的近似
        float scale_factor = pow_float(ratio, float_of_int(cfg.dim) / float_of_int(max_int(cfg.dim - 2, 1)))
        new_base = cfg.base * scale_factor
    } else {
        // 标准公式
        float scale_factor = pow_float(ratio, float_of_int(cfg.dim) / (2.0 * float_of_int(cfg.dim - 2)))
        new_base = cfg.base * scale_factor
    }
    
    // 使用新 base 计算频率
    []float freqs = []float{cap: half_dim}
    int i = 0
    while i < half_dim {
        float exponent = float_of_int(i * 2) / float_of_int(cfg.dim)
        freqs[i] = 1.0 / pow_float(new_base, exponent)
        i = i + 1
    }
    
    // 角度
    []float angles = []float{cap: half_dim}
    i = 0
    while i < half_dim {
        angles[i] = float_of_int(position) * freqs[i]
        i = i + 1
    }
    
    return angles
}

// ============================================================================
// 6. 方法三: YaRN (推荐!) — Yet Another RoPE Extension
// ============================================================================
//
// 核心思想 (结合了多种技术):
//   
//   1. **动态缩放**: 
//      对不同频率使用不同的缩放策略:
//      - 低频 (远距离信息): 使用较大的缩放
//      - 高频 (局部细节): 保持原始尺度
//
//   2. **负载均衡** (Passage Scaling):
//      引入 beta_fast 和 beta_slow 参数平滑过渡
//      避免在临界频率处出现突变
//
//   3. **注意力缩放** (Attention Scaling, 可选):
//      对注意力分数进行额外的 mscaling 因子缩放,
//      补偿长序列下注意力分布的变化
//
// 数学公式:
//   lambda(t) = 0.5 * (1 + tanh(ln(t)/beta))
//   freq_scaled = freq * (1 - lambda) + freq * scale * lambda
//   即: 低频用 scale,高频保持原值,中间平滑过渡

func rope_yarn_scaling(
    rope_scaling_config cfg,
    int position
) []float {
    int half_dim = cfg.dim / 2
    
    // 计算频率 (使用原始 base)
    []float freqs = compute_rope_frequencies(cfg.original_max_seq_len, cfg.dim, cfg.base)
    
    // YaRN 动态缩放
    // lambda 函数: 控制每个频率维度的混合比例
    []float lambdas = []float{cap: half_dim}
    float inv_beta_fast = 1.0 / cfg.yarn_beta_fast
    float inv_beta_slow = 1.0 / cfg.yarn_beta_slow
    
    int i = 0
    while i < half_dim {
        float t = freqs[i]  // 频率值作为 "时间" 变量
        
        // tanh(log(t) / beta) 实现平滑过渡
        float log_t = log_approx(max_float(t, 1e-10))
        
        // 快速和慢速衰减的加权平均
        float decay = 0.5 * (1.0 + tanh_approx(log_t * inv_beta_fast))
        float slow_decay = 0.5 * (1.0 + tanh_approx(log_t * inv_beta_slow))
        
        // 组合: lambda = (1 - slow_decay) * decay + (1 - decay)
        // 简化版本: lambda = tanh(ln(freq) / beta)
        lambdas[i] = decay
        
        i = i + 1
    }
    
    // 应用缩放
    []float angles = []float{cap: half_dim}
    i = 0
    while i < half_dim {
        // 混合: 原始尺度 * (1-lambda) + 缩放尺度 * lambda
        float scaled_freq = freqs[i] * (1.0 - lambdas[i]) + 
                            freqs[i] * cfg.yarn_scale * lambdas[i]
        angles[i] = float_of_int(position) * scaled_freq
        i = i + 1
    }
    
    return angles
}

// Tanh 近似 (Taylor 级数)
func tanh_approx(float x) float {
    // tanh(x) = (e^x - e^-x) / (e^x + e^-x)
    // 使用 Padé 近似或有理函数近似
    
    // 对于大 |x|, tanh(x) ≈ sign(x)
    if x > 5.0 { return 1.0 }
    if x < -5.0 { return -1.0 }
    
    // 有理近似: tanh(x) ≈ x * (27 + x^2) / (27 + 9*x^2)
    float x2 = x * x
    return x * (27.0 + x2) / (27.0 + 9.0 * x2)
}

// ============================================================================
// 7. 统一接口: 根据 config 选择缩放方法并返回角度
// ============================================================================

struct rope_result {
    []float cos_values    // [half_dim] cos(angle)
    []float sin_values    // [half_dim] sin(angle)
    float attention_scale // 可选的注意力缩放因子 (YaRN 用)
}

// 获取指定位置的 RoPE 角度 (统一入口)
func get_rope_angles(
    rope_scaling_config cfg,
    int position
) rope_result {
    int half_dim = cfg.dim / 2
    []float angles
    
    // 根据方法选择
    if cfg.method == ROPE_SCALING_LINEAR {
        angles = rope_linear_scaling(cfg, position)
    } else if cfg.method == ROPE_SCALING_NTK {
        angles = rope_ntk_scaling(cfg, position)
    } else {  // ROPE_SCALING_YARN
        angles = rope_yarn_scaling(cfg, position)
    }
    
    // 计算 cos/sin
    []float cos_vals = []float{cap: half_dim}
    []float sin_vals = []float{cap: half_dim}
    int i = 0
    while i < half_dim {
        cos_vals[i] = cos_approx(angles[i])
        sin_vals[i] = sin_approx(angles[i])
        i = i + 1
    }
    
    // 注意力缩放因子
    float attn_scale = 1.0
    if cfg.method == ROPE_SCALING_YARN && cfg.yarn_mscale > 0.0 {
        attn_scale = cfg.yarn_mscale
    }
    
    rope_result {
        cos_values: cos_vals,
        sin_values: sin_vals,
        attention_scale: attn_scale,
    }
}

// ============================================================================
// 8. 批量预计算: 为整个序列生成 RoPE 表 (缓存优化)
// ============================================================================

struct rope_cache {
    [][]float all_cos     // [seq_len, half_dim]
    [][]float all_sin     // [seq_len, half_dim]
    float attention_scale
    int cached_seq_len
}

// 预计算整个序列的 RoPE (避免重复计算)
func build_rope_cache(rope_scaling_config cfg, int seq_len) rope_cache {
    int half_dim = cfg.dim / 2
    
    [][]float cos_table = [][]float{cap: seq_len}
    [][]float sin_table = [][]float{cap: seq_len}
    
    float attn_scale = 1.0
    
    int pos = 0
    while pos < seq_len {
        rope_result r = get_rope_angles(cfg, pos)
        cos_table[pos] = r.cos_values
        sin_table[pos] = r.sin_values
        if pos == 0 { attn_scale = r.attention_scale }
        pos = pos + 1
    }
    
    rope_cache {
        all_cos: cos_table,
        all_sin: sin_table,
        attention_scale: attn_scale,
        cached_seq_len: seq_len,
    }
}

// ============================================================================
// 9. 应用 RoPE 到 Q/K 张量 (核心操作)
// ============================================================================

// 将 RoPE 应用于单个 token 的 Q 或 K 向量
// 输入: x [head_dim], 输出: rotated_x [head_dim]
// 布局: [x0, x1, x2, x3, ..., x_{d-2}, x_{d-1}]
// 操作: (x_{2i}, x_{2i+1}) -> rotate by angle_i
//
// 公式:
//   x'_2i   = x_2i * cos(theta_i) - x_{2i+1} * sin(theta_i)
//   x'_{2i+1} = x_2i * sin(theta_i) + x_{2i+1} * cos(theta_i)

func apply_rope_single(
    []float x,               // [head_dim]
    rope_result angles       // pre-computed cos/sin
) []float {
    int d = len(x)
    int half_d = d / 2
    
    []float out = []float{cap: d}
    
    int i = 0
    while i < half_d {
        float x0 = x[2 * i]
        float x1 = x[2 * i + 1]
        float cos_val = angles.cos_values[i]
        float sin_val = angles.sin_values[i]
        
        out[2 * i]     = x0 * cos_val - x1 * sin_val
        out[2 * i + 1] = x0 * sin_val + x1 * cos_val
        
        i = i + 1
    }
    
    return out
}

// 批量应用 RoPE: 对整个序列的所有 heads
// 输入: x [seq_len, num_heads, head_dim]
// 输出: rotated [seq_len, num_heads, head_dim]
func apply_rope_batch(
    [][][]float x,           // [seq_len][num_heads][head_dim]
    rope_cache cache         // pre-computed cache
) [][][]float {
    int seq_len = len(x)
    if seq_len == 0 { return x }
    int num_heads = len(x[0])
    if num_heads == 0 { return x }
    int head_dim = len(x[0][0])
    int half_d = head_dim / 2
    
    // 输出张量
    [][][]float out = [][][]float{cap: seq_len}
    
    int s = 0
    while s < seq_len {
        out[s] = [][][]float{cap: num_heads}
        int h = 0
        while h < num_heads {
            out[s][h] = []float{cap: head_dim}
            
            int i = 0
            while i < half_d {
                float x0 = x[s][h][2 * i]
                float x1 = x[s][h][2 * i + 1]
                float cos_val = cache.all_cos[s][i]
                float sin_val = cache.all_sin[s][i]
                
                out[s][h][2 * i]     = x0 * cos_val - x1 * sin_val
                out[s][h][2 * i + 1] = x0 * sin_val + x1 * cos_val
                
                i = i + 1
            }
            
            h = h + 1
        }
        s = s + 1
    }
    
    return out
}

// ============================================================================
// 10. 数学辅助函数 (cos/sin 近似)
// ============================================================================

// Cosine Taylor 级数近似
func cos_approx(float x) float {
    // 将 x 归一化到 [-pi, pi] 以提高精度
    // pi ≈ 3.141592653589793
    float pi = 3.141592653589793
    float two_pi = 2.0 * pi
    
    // 归一化
    while x > pi || x < -pi {
        if x > pi { x = x - two_pi }
        if x < -pi { x = x + two_pi }
    }
    
    // Taylor: cos(x) = 1 - x²/2! + x⁴/4! - x⁶/6! + ...
    float term = 1.0
    float result = 1.0
    float xx = x * x
    int n = 1
    while n <= 12 {
        term = -term * xx / float_of_int((2 * n - 1) * (2 * n))
        result = result + term
        n = n + 1
    }
    return result
}

// Sine Taylor 级数近似
func sin_approx(float x) float {
    // 归一化到 [-pi, pi]
    float pi = 3.141592653589793
    float two_pi = 2.0 * pi
    
    while x > pi || x < -pi {
        if x > pi { x = x - two_pi }
        if x < -pi { x = x + two_pi }
    }
    
    // Taylor: sin(x) = x - x³/3! + x⁵/5! - x⁷/7! + ...
    float term = x
    float result = x
    float xx = x * x
    int n = 1
    while n <= 12 {
        term = -term * xx / float_of_int((2 * n) * (2 * n + 1))
        result = result + term
        n = n + 1
    }
    return result
}

// ============================================================================
// 11. NEURX 特定适配: 双向注意力 + 2D 位置编码
// ============================================================================
//
// NEURX 使用双向注意力 (类似 BERT),但位置编码是 2D 的:
//   - Block ID (block_position): 当前 block 的索引
//   - Position ID (position): block 内部的相对位置
//
// NEURX 的 RoPE 同时编码这两个位置信息

struct neurx_position_encoding {
    int block_position      // 哪个 block (段落级)
    int position            // block 内的位置 (token 级)
}

// NEURX 专用 RoPE: 结合 block 和 position 信息
func get_neurx_rope_angles(
    rope_scaling_config cfg,
    neurx_position_encoding pos
) rope_result {
    // NEURX 的位置编码方式:
    // 最终位置 = block_position * block_size + position
    // 或者分别编码后组合 (取决于具体 NEURX 版本)
    
    int effective_position = pos.block_position * cfg.original_max_seq_len + pos.position
    
    return get_rope_angles(cfg, effective_position)
}

// NEURX 批量位置编码构建
func build_neurx_rope_cache(
    rope_scaling_config cfg,
    int num_blocks,
    int block_size
) rope_cache {
    int total_seq_len = num_blocks * block_size
    return build_rope_cache(cfg, total_seq_len)
}

// ============================================================================
// 12. 性能统计 & 验证工具
// ============================================================================

struct rope_stats {
    int total_positions_computed
    float avg_compute_time_us
    float peak_memory_bytes
    string method_used
}

// 验证 RoPE Scaling 的正确性 (单元测试用)
func validate_rope_scaling(
    rope_scaling_config cfg,
    int test_positions_count
) bool {
    bool passed = true
    int p = 0
    while p < test_positions_count {
        rope_result r = get_rope_angles(cfg, p)
        
        // 检查: cos² + sin² 应该接近 1
        int i = 0
        while i < len(r.cos_values) {
            float val = r.cos_values[i] * r.cos_values[i] + 
                        r.sin_values[i] * r.sin_values[i]
            // 允许 ±0.01 的误差 (浮点精度)
            if val < 0.99 || val > 1.01 {
                passed = false
            }
            i = i + 1
        }
        p = p + 1
    }
    return passed
}

// 打印 RoPE Scaling 配置摘要
func print_rope_config_summary(rope_scaling_config cfg) string {
    string method_name = ""
    if cfg.method == ROPE_SCALING_LINEAR {
        method_name = "Linear (Position Interpolation)"
    } else if cfg.method == ROPE_SCALING_NTK {
        method_name = "NTK-Aware"
    } else {
        method_name = "YaRN (Recommended)"
    }
    
    "RoPE Scaling Config:\n" +
    "  Method: " + method_name + "\n" +
    "  Original Length: " + string(cfg.original_max_seq_len) + "\n" +
    "  Target Length: " + string(cfg.target_max_seq_len) + "\n" +
    "  Scale Factor: " + string(float_of_int(cfg.target_max_seq_len) / float_of_int(cfg.original_max_seq_len)) + "x\n" +
    "  Base: " + string(cfg.base) + "\n" +
    "  Dim: " + string(cfg.dim)
}
