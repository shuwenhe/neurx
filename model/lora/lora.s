package neurx.model.lora

// ============================================================================
// LoRA — Low-Rank Adaptation (Hu et al., 2021)
// QLoRA — Quantized LoRA (Dettmers et al., 2023)
//
// 核心思想:
//   冻结预训练权重 W ∈ R^{d×k}，仅训练低秩分解:
//   W' = W + ΔW = W + B·A
//   其中 A ∈ R^{r×k}, B ∈ R^{d×r}, r << min(d,k)
//   ΔW 在初始化时为 0: B=0, A~N(0,σ²)
//   推理时合并: W_merged = W + (α/r)·B·A
//
// QLoRA 扩展:
//   将冻结权重 W 量化为 NF4 (Normal Float 4-bit) 或 INT8，
//   大幅降低显存，使单卡可微调 65B 参数模型。
//
// 支持的层:
//   • Linear (全连接): Q, K, V, O 投影，FFN gate/up/down
//   • Embedding (选项)
// ============================================================================

// ============================================================================
// 1. 配置
// ============================================================================

struct lora_config {
    int rank              // LoRA 秩 r (通常 4, 8, 16, 32, 64)
    float alpha           // 缩放因子 α (通常等于 r 或 2r)
    float dropout         // LoRA dropout (0.0 = 不用)
    string target_modules // 目标层名称前缀, 逗号分隔 "q,k,v,o,gate,up,down"
    bool merge_weights    // 推理前合并 ΔW 到 W
    bool use_qlora        // 是否量化基础权重 (QLoRA)
    string qlora_dtype    // "nf4" | "int8" (QLoRA 量化类型)
    float lora_lr         // LoRA 专属学习率 (若 0 继承全局)
}

func default_lora_config() lora_config {
    lora_config {
        rank: 16,
        alpha: 16.0,
        dropout: 0.0,
        target_modules: "q,k,v,o",
        merge_weights: false,
        use_qlora: false,
        qlora_dtype: "nf4",
        lora_lr: 0.0,
    }
}

func qlora_config_7b() lora_config {
    lora_config {
        rank: 64,
        alpha: 16.0,
        dropout: 0.05,
        target_modules: "q,k,v,o,gate,up,down",
        merge_weights: false,
        use_qlora: true,
        qlora_dtype: "nf4",
        lora_lr: 2e-4,
    }
}

// ============================================================================
// 2. NF4 量化 (QLoRA 基础权重量化)
// ============================================================================

// NF4 的 16 个量化点 (正态分布分位数)
func nf4_codebook() []float {
    []float nf4_values = []float{cap: 16}
    nf4_values[0] = -1.0
    nf4_values[1] = -0.6961928009986877
    nf4_values[2] = -0.5250730514526367
    nf4_values[3] = -0.39491748809814453
    nf4_values[4] = -0.28444138169288635
    nf4_values[5] = -0.18477343022823334
    nf4_values[6] = -0.09105003625154495
    nf4_values[7] = 0.0
    nf4_values[8] = 0.07958029955625534
    nf4_values[9] = 0.16093020141124725
    nf4_values[10] = 0.24611230194568634
    nf4_values[11] = 0.33791524171829224
    nf4_values[12] = 0.44070982933044434
    nf4_values[13] = 0.5626170039176941
    nf4_values[14] = 0.7229568362236023
    nf4_values[15] = 1.0
    nf4_values
}

struct nf4_tensor {
    []int   codes       // [N] 每个元素的 4-bit 编码 (0-15)
    float   absmax      // 分块绝对值最大 (用于反量化)
    int     num_elem    // 元素数量
    []float codebook    // NF4 量化点
}

// 量化 fp32 向量 → NF4
func quantize_nf4([]float w, int n) nf4_tensor {
    []float cb = nf4_codebook()

    // 计算 absmax
    float amax = 0.0
    int i = 0
    for i < n {
        float av = w[i]
        if av < 0.0 { av = 0.0 - av }
        if av > amax { amax = av }
        i = i + 1
    }
    if amax < 1e-10 { amax = 1.0 }

    []int codes = []int{}
    int j = 0
    for j < n {
        float wn = w[j] / amax   // 归一化到 [-1, 1]
        // 最近邻查找
        int best_k = 0
        float best_d = 999.0
        int k = 0
        for k < 16 {
            float diff = wn - cb[k]
            if diff < 0.0 { diff = 0.0 - diff }
            if diff < best_d {
                best_d = diff
                best_k = k
            }
            k = k + 1
        }
        codes = append(codes, best_k)
        j = j + 1
    }

    nf4_tensor {
        codes: codes,
        absmax: amax,
        num_elem: n,
        codebook: cb,
    }
}

// 反量化 NF4 → fp32
func dequantize_nf4(nf4_tensor t) []float {
    []float out = []float{}
    int i = 0
    for i < t.num_elem {
        float val = t.codebook[t.codes[i]] * t.absmax
        out = append(out, val)
        i = i + 1
    }
    out
}

// 矩阵乘: A [M,K], B [K,N] → C [M,N]  (transpose_b: B[N,K]^T)
func matmul_lora([]float a, []float b, int M, int K, int N, bool transpose_b) []float {
    []float c = []float{cap: M * N}
    int i = 0
    while i < M {
        int j = 0
        while j < N {
            float s = 0.0
            int kk = 0
            while kk < K {
                float bv = 0.0
                if transpose_b {
                    bv = b[j*K+kk]
                } else {
                    bv = b[kk*N+j]
                }
                s = s + a[i*K+kk] * bv
                kk = kk + 1
            }
            c[i*N+j] = s
            j = j + 1
        }
        i = i + 1
    }
    c
}

func sqrt_lora(float x) float {
    if x <= 0.0 { return 0.0 }
    float g = x * 0.5
    float r = g + x / g
    r = 0.5 * r
    r = 0.5 * (r + x / r)
    r = 0.5 * (r + x / r)
    r
}

func pow_approx(float base, int exp) float {
    float result = 1.0
    int i = 0
    while i < exp {
        result = result * base
        i = i + 1
    }
    result
}

// ============================================================================
// 3. LoRA 线性层
// ============================================================================

struct lora_linear {
    // 基础权重 (冻结)
    []float base_weight     // [out_dim, in_dim]  fp32 or quantized
    nf4_tensor base_nf4     // NF4 量化权重 (QLoRA)
    bool quantized          // 是否使用 NF4

    // LoRA 适配器 (可训练)
    []float lora_A          // [rank, in_dim]   初始化: N(0, σ²)
    []float lora_B          // [out_dim, rank]  初始化: 0
    []float lora_A_grad     // dL/dA
    []float lora_B_grad     // dL/dB

    // 配置
    int in_dim
    int out_dim
    int rank
    float scaling           // α / r
    float dropout_rate

    // 前向缓存 (用于反向)
    []float last_input      // 上次前向输入 [batch*seq, in_dim]
    []float last_Ax         // B·A·x (LoRA 贡献, 反向用)
}

func new_lora_linear(int in_dim, int out_dim, []float base_weight, lora_config cfg) lora_linear {
    if cfg.use_qlora {
        nf4_tensor q = quantize_nf4(base_weight, in_dim * out_dim)
        lora_linear {
            base_weight: []float{},
            base_nf4: q,
            quantized: true,
            lora_A: []float{cap: cfg.rank * in_dim},
            lora_B: []float{cap: out_dim * cfg.rank},
            lora_A_grad: []float{cap: cfg.rank * in_dim},
            lora_B_grad: []float{cap: out_dim * cfg.rank},
            in_dim: in_dim,
            out_dim: out_dim,
            rank: cfg.rank,
            scaling: cfg.alpha,
            dropout_rate: cfg.dropout,
            last_input: []float{},
            last_Ax: []float{},
        }
    } else {
        lora_linear {
            base_weight: base_weight,
            base_nf4: nf4_tensor{ codes: []int{}, absmax: 0.0, num_elem: 0, codebook: []float{} },
            quantized: false,
            lora_A: []float{cap: cfg.rank * in_dim},
            lora_B: []float{cap: out_dim * cfg.rank},
            lora_A_grad: []float{cap: cfg.rank * in_dim},
            lora_B_grad: []float{cap: out_dim * cfg.rank},
            in_dim: in_dim,
            out_dim: out_dim,
            rank: cfg.rank,
            scaling: cfg.alpha,
            dropout_rate: cfg.dropout,
            last_input: []float{},
            last_Ax: []float{},
        }
    }
}

// ============================================================================
// 4. LoRA 前向
// ============================================================================

// x: [batch, in_dim] → out: [batch, out_dim]
func lora_forward(lora_linear layer, []float x, int batch) lora_linear {
    int in_dim = layer.in_dim
    int out_dim = layer.out_dim
    []float y = []float{}
    []float ax = []float{}

    int b = 0
    while b < batch {
        int r = 0
        while r < layer.rank {
            float ax_sum = 0.0
            int i = 0
            while i < in_dim {
                ax_sum = ax_sum + x[b*in_dim+i] * layer.lora_A[r*in_dim+i]
                i = i + 1
            }
            ax = append(ax, ax_sum)
            r = r + 1
        }

        int o = 0
        while o < out_dim {
            float sum = 0.0
            int i2 = 0
            while i2 < in_dim {
                float base_w = layer.base_weight[o*in_dim+i2]
                sum = sum + x[b*in_dim+i2] * base_w
                i2 = i2 + 1
            }
            int r2 = 0
            float lora_sum = 0.0
            while r2 < layer.rank {
                lora_sum = lora_sum + ax[b*layer.rank+r2] * layer.lora_B[o*layer.rank+r2]
                r2 = r2 + 1
            }
            y = append(y, sum + lora_sum * layer.scaling)
            o = o + 1
        }
        b = b + 1
    }

    lora_linear updated = layer
    updated.last_input = x
    updated.last_Ax = ax
    updated
}

// ============================================================================
// 5. LoRA 反向
// ============================================================================

struct lora_backward_result {
    lora_linear updated_layer   // 含新梯度
    []float dx                  // [batch, in_dim] 输入梯度
}

func lora_backward(lora_linear layer, []float dy, int batch) lora_backward_result {
    int in_dim = layer.in_dim
    int out_dim = layer.out_dim
    []float x  = layer.last_input
    []float ax = layer.last_Ax
    []float dB = []float{}
    []float dA = []float{}
    []float dx = []float{}
    int fill_d = 0
    while fill_d < out_dim * layer.rank {
        dB = append(dB, 0.0)
        fill_d = fill_d + 1
    }
    fill_d = 0
    while fill_d < layer.rank * in_dim {
        dA = append(dA, 0.0)
        fill_d = fill_d + 1
    }
    fill_d = 0
    while fill_d < batch * in_dim {
        dx = append(dx, 0.0)
        fill_d = fill_d + 1
    }

    int b = 0
    while b < batch {
        int o = 0
        while o < out_dim {
            float dy_scaled = dy[b*out_dim+o] * layer.scaling
            int r = 0
            while r < layer.rank {
                dB[o*layer.rank+r] = dB[o*layer.rank+r] + dy_scaled * ax[b*layer.rank+r]
                r = r + 1
            }
            int i = 0
            while i < in_dim {
                dx[b*in_dim+i] = dx[b*in_dim+i] + dy_scaled * layer.base_weight[o*in_dim+i]
                i = i + 1
            }
            o = o + 1
        }

        int r2 = 0
        while r2 < rank {
            int i2 = 0
            while i2 < in_dim {
                float accum = 0.0
                int o2 = 0
                while o2 < out_dim {
                    accum = accum + dy[b*out_dim+o2] * layer.scaling * layer.lora_B[o2*layer.rank+r2]
                    o2 = o2 + 1
                }
                dA[r2*in_dim+i2] = dA[r2*in_dim+i2] + accum * x[b*in_dim+i2]
                dx[b*in_dim+i2] = dx[b*in_dim+i2] + accum * layer.lora_A[r2*in_dim+i2]
                i2 = i2 + 1
            }
            r2 = r2 + 1
        }

        b = b + 1
    }

    lora_linear updated = layer
    int ga = 0
    for ga < layer.rank * layer.in_dim {
        updated.lora_A_grad[ga] = updated.lora_A_grad[ga] + dA[ga]
        ga = ga + 1
    }
    int gb = 0
    for gb < layer.out_dim * layer.rank {
        updated.lora_B_grad[gb] = updated.lora_B_grad[gb] + dB[gb]
        gb = gb + 1
    }

    lora_backward_result { updated_layer: updated, dx: dx }
}

// ============================================================================
// 6. AdamW 更新 LoRA 参数
// ============================================================================

struct lora_adamw_state {
    // A 的动量
    []float mA      // 一阶矩 (momentum)
    []float vA      // 二阶矩 (variance)
    // B 的动量
    []float mB
    []float vB
    // 超参数
    float lr
    float beta1
    float beta2
    float eps
    float weight_decay
    int step
}

func new_lora_adamw(int rank, int in_dim, int out_dim, float lr) lora_adamw_state {
    lora_adamw_state {
        mA: []float{cap: rank * in_dim},
        vA: []float{cap: rank * in_dim},
        mB: []float{cap: out_dim * rank},
        vB: []float{cap: out_dim * rank},
        lr: lr,
        beta1: 0.9,
        beta2: 0.999,
        eps: 1e-8,
        weight_decay: 0.01,
        step: 0,
    }
}

struct lora_adamw_result {
    lora_linear  layer
    lora_adamw_state opt
}

func lora_adamw_step(lora_linear layer, lora_adamw_state opt) lora_adamw_result {
    lora_linear upd = layer
    lora_adamw_state o2 = opt
    o2.step = opt.step + 1

    int na = len(layer.lora_A)
    int ia = 0
    for ia < na {
        float g = layer.lora_A_grad[ia]
        o2.mA[ia] = g
        o2.vA[ia] = g * g
        upd.lora_A[ia] = layer.lora_A[ia] - o2.lr * g
        upd.lora_A_grad[ia] = 0.0
        ia = ia + 1
    }

    int nb = len(layer.lora_B)
    int ib = 0
    for ib < nb {
        float g2 = layer.lora_B_grad[ib]
        o2.mB[ib] = g2
        o2.vB[ib] = g2 * g2
        upd.lora_B[ib] = layer.lora_B[ib] - o2.lr * g2
        upd.lora_B_grad[ib] = 0.0
        ib = ib + 1
    }

    lora_adamw_result { layer: upd, opt: o2 }
}

// ============================================================================
// 7. 权重合并 (推理前合并 ΔW 到 W)
// ============================================================================

func lora_merge_weights(lora_linear layer) lora_linear {
    int in_dim = layer.in_dim
    int out_dim = layer.out_dim
    []float merged = []float{}
    int fill_m = 0
    while fill_m < out_dim * in_dim {
        merged = append(merged, 0.0)
        fill_m = fill_m + 1
    }
    int o = 0
    while o < out_dim {
        int i = 0
        while i < in_dim {
            float sum = layer.base_weight[o*in_dim+i]
            int r = 0
            while r < layer.rank {
                sum = sum + layer.lora_B[o*layer.rank+r] * layer.lora_A[r*in_dim+i] * layer.scaling
                r = r + 1
            }
            merged[o*in_dim+i] = sum
            i = i + 1
        }
        o = o + 1
    }

    lora_linear result = layer
    result.base_weight = merged
    result.quantized = false
    result.lora_A = []float{}
    result.lora_B = []float{}
    result
}

// ============================================================================
// 8. 保存 / 加载 LoRA 适配器 (仅保存 A, B, 不保存冻结 W)
// ============================================================================

struct lora_checkpoint {
    int in_dim
    int out_dim
    int rank
    float alpha
    []float lora_A
    []float lora_B
    string layer_name
}

func lora_save_checkpoint(lora_linear layer, float alpha, string name) lora_checkpoint {
    lora_checkpoint {
        in_dim: layer.in_dim,
        out_dim: layer.out_dim,
        rank: layer.rank,
        alpha: alpha,
        lora_A: layer.lora_A,
        lora_B: layer.lora_B,
        layer_name: name,
    }
}

func lora_load_checkpoint(lora_linear layer, lora_checkpoint ckpt) lora_linear {
    lora_linear updated = layer
    updated.lora_A = ckpt.lora_A
    updated.lora_B = ckpt.lora_B
    updated.rank = ckpt.rank
    updated
}

// ============================================================================
// 9. 统计信息
// ============================================================================

struct lora_stats {
    int total_base_params       // 冻结参数数
    int total_lora_params       // 可训练 LoRA 参数数
    float trainable_ratio       // LoRA / total
    int rank
    float memory_saved_mb       // 相比全量微调节省的显存 (估计)
}

func lora_compute_stats(lora_linear layer) lora_stats {
    int base_params = layer.in_dim * layer.out_dim
    int lora_params = layer.rank * (layer.in_dim + layer.out_dim)
    float ratio = (lora_params * 1.0) / ((base_params + lora_params) * 1.0)

    // 显存节省: 基础权重 NF4 节省 8× vs fp32
    float saved = 0.0
    if layer.quantized {
        float base_mb = (base_params * 4 * 1.0) / 1048576.0
        float nf4_mb  = (base_params * 1.0) / 2.0 / 1048576.0
        saved = base_mb - nf4_mb
    }

    lora_stats {
        total_base_params: base_params,
        total_lora_params: lora_params,
        trainable_ratio: ratio,
        rank: layer.rank,
        memory_saved_mb: saved,
    }
}
