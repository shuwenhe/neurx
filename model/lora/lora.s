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
    int r = cfg.rank
    float scale = cfg.alpha

    // 初始化 A: 小常数，B 为 0，保证初始 ΔW = 0
    []float a = fill_lora(r * in_dim, 0.01)
    // 初始化 B: 全零 (初始 ΔW = 0)
    []float b = fill_lora(out_dim * r, 0.0)

    if cfg.use_qlora {
        nf4_tensor q = quantize_nf4(base_weight, in_dim * out_dim)
        lora_linear {
            base_weight: []float{},
            base_nf4: q,
            quantized: true,
            lora_A: a,
            lora_B: b,
            lora_A_grad: fill_lora(r * in_dim, 0.0),
            lora_B_grad: fill_lora(out_dim * r, 0.0),
            in_dim: in_dim,
            out_dim: out_dim,
            rank: r,
            scaling: scale,
            dropout_rate: cfg.dropout,
            last_input: []float{},
            last_Ax: []float{},
        }
    } else {
        lora_linear {
            base_weight: base_weight,
            base_nf4: nf4_tensor{ codes: []int{}, absmax: 0.0, num_elem: 0, codebook: []float{} },
            quantized: false,
            lora_A: a,
            lora_B: b,
            lora_A_grad: fill_lora(r * in_dim, 0.0),
            lora_B_grad: fill_lora(out_dim * r, 0.0),
            in_dim: in_dim,
            out_dim: out_dim,
            rank: r,
            scaling: scale,
            dropout_rate: cfg.dropout,
            last_input: []float{},
            last_Ax: []float{},
        }
    }
}

func fill_lora(int n, float val) []float {
    []float out = []float{}
    int i = 0
    for i < n {
        out = append(out, val)
        i = i + 1
    }
    out
}

// ============================================================================
// 4. LoRA 前向
// ============================================================================

// x: [batch, in_dim] → out: [batch, out_dim]
func lora_forward(lora_linear layer, []float x, int batch) lora_linear {
    int I = layer.in_dim
    int O = layer.out_dim
    int R = layer.rank

    // 基础权重前向
    []float base_w = layer.base_weight
    if layer.quantized {
        base_w = dequantize_nf4(layer.base_nf4)
    }

    // y_base = x @ W^T  [batch, O]
    []float y = matmul_lora(x, base_w, batch, I, O, true)

    // LoRA: y_lora = (x @ A^T) @ B^T * scaling
    // Ax [batch, R]
    []float ax = matmul_lora(x, layer.lora_A, batch, I, R, true)
    // y_lora = ax @ B^T  [batch, O]
    []float y_lora = matmul_lora(ax, layer.lora_B, batch, R, O, true)

    // y += y_lora * scaling
    int idx = 0
    for idx < batch * O {
        y[idx] = y[idx] + y_lora[idx] * layer.scaling
        idx = idx + 1
    }

    // Cache for backward
    lora_linear updated = layer
    updated.last_input = x
    updated.last_Ax = ax
    updated
}

// 矩阵乘: A [M,K], B [K,N] → C [M,N]  (transpose_b: B[N,K]^T)
func matmul_lora([]float a, []float b, int M, int K, int N, bool transpose_b) []float {
    []float c = fill_lora(M * N, 0.0)
    int i = 0
    for i < M {
        int j = 0
        for j < N {
            float s = 0.0
            int kk = 0
            for kk < K {
                float bv = 0.0
                if transpose_b {
                    bv = b[j*K+kk]    // B[j,k] (B stored as [N,K])
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

// ============================================================================
// 5. LoRA 反向
// ============================================================================

struct lora_backward_result {
    lora_linear updated_layer   // 含新梯度
    []float dx                  // [batch, in_dim] 输入梯度
}

func lora_backward(lora_linear layer, []float dy, int batch) lora_backward_result {
    int I = layer.in_dim
    int O = layer.out_dim
    int R = layer.rank
    []float x  = layer.last_input
    []float ax = layer.last_Ax

    // dL/dB = (dy * scaling)^T @ Ax  → dB [O, R]
    // dy_scaled [batch, O]
    []float dy_scaled = fill_lora(batch * O, 0.0)
    int si = 0
    for si < batch * O {
        dy_scaled[si] = dy[si] * layer.scaling
        si = si + 1
    }

    // dB += dy_scaled^T @ ax:  dB[o,r] += dy_scaled[b,o] * ax[b,r]
    []float dB = fill_lora(O * R, 0.0)
    int bi = 0
    for bi < batch {
        int oi = 0
        for oi < O {
            int ri = 0
            for ri < R {
                dB[oi*R+ri] = dB[oi*R+ri] + dy_scaled[bi*O+oi] * ax[bi*R+ri]
                ri = ri + 1
            }
            oi = oi + 1
        }
        bi = bi + 1
    }

    // dL/d(Ax) = dy_scaled @ B  [batch, R]
    []float dAx = matmul_lora(dy_scaled, layer.lora_B, batch, O, R, false)

    // dL/dA = dAx^T @ x  → dA [R, I]
    []float dA = fill_lora(R * I, 0.0)
    int bi2 = 0
    for bi2 < batch {
        int ri2 = 0
        for ri2 < R {
            int ii = 0
            for ii < I {
                dA[ri2*I+ii] = dA[ri2*I+ii] + dAx[bi2*R+ri2] * x[bi2*I+ii]
                ii = ii + 1
            }
            ri2 = ri2 + 1
        }
        bi2 = bi2 + 1
    }

    // dx = dy @ W_base + dAx @ A  (gradient flows through frozen W too)
    []float base_w = layer.base_weight
    if layer.quantized {
        base_w = dequantize_nf4(layer.base_nf4)
    }
    []float dx_base = matmul_lora(dy, base_w, batch, O, I, false)
    []float dx_lora = matmul_lora(dAx, layer.lora_A, batch, R, I, false)
    []float dx = fill_lora(batch * I, 0.0)
    int di = 0
    for di < batch * I {
        dx[di] = dx_base[di] + dx_lora[di]
        di = di + 1
    }

    // 累积梯度
    lora_linear updated = layer
    int ga = 0
    for ga < R * I {
        updated.lora_A_grad[ga] = updated.lora_A_grad[ga] + dA[ga]
        ga = ga + 1
    }
    int gb = 0
    for gb < O * R {
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
        mA: fill_lora(rank * in_dim, 0.0),
        vA: fill_lora(rank * in_dim, 0.0),
        mB: fill_lora(out_dim * rank, 0.0),
        vB: fill_lora(out_dim * rank, 0.0),
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
    int step = opt.step + 1
    float b1  = opt.beta1
    float b2  = opt.beta2
    float eps = opt.eps
    float lr  = opt.lr
    float wd  = opt.weight_decay

    // Bias correction
    float bc1 = 1.0 - pow_approx(b1, step)
    float bc2 = 1.0 - pow_approx(b2, step)
    float lr_t = lr * sqrt_lora(bc2) / bc1

    lora_linear upd = layer
    lora_adamw_state o2 = opt
    o2.step = step

    // Update A
    int na = len(layer.lora_A)
    int ia = 0
    for ia < na {
        float g = layer.lora_A_grad[ia]
        o2.mA[ia] = b1 * opt.mA[ia] + (1.0 - b1) * g
        o2.vA[ia] = b2 * opt.vA[ia] + (1.0 - b2) * g * g
        float step_size = lr_t / (sqrt_lora(o2.vA[ia]) + eps)
        upd.lora_A[ia] = layer.lora_A[ia] * (1.0 - lr * wd) - step_size * o2.mA[ia]
        upd.lora_A_grad[ia] = 0.0
        ia = ia + 1
    }

    // Update B (no weight decay on B to keep ΔW=0 at init)
    int nb = len(layer.lora_B)
    int ib = 0
    for ib < nb {
        float g2 = layer.lora_B_grad[ib]
        o2.mB[ib] = b1 * opt.mB[ib] + (1.0 - b1) * g2
        o2.vB[ib] = b2 * opt.vB[ib] + (1.0 - b2) * g2 * g2
        float step_size2 = lr_t / (sqrt_lora(o2.vB[ib]) + eps)
        upd.lora_B[ib] = layer.lora_B[ib] - step_size2 * o2.mB[ib]
        upd.lora_B_grad[ib] = 0.0
        ib = ib + 1
    }

    lora_adamw_result { layer: upd, opt: o2 }
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
    for i < exp {
        result = result * base
        i = i + 1
    }
    result
}

// ============================================================================
// 7. 权重合并 (推理前合并 ΔW 到 W)
// ============================================================================

func lora_merge_weights(lora_linear layer) lora_linear {
    int I = layer.in_dim
    int O = layer.out_dim
    int R = layer.rank

    // ΔW = B @ A * scaling  [O, I]
    []float delta = matmul_lora(layer.lora_B, layer.lora_A, O, R, I, false)

    []float merged = fill_lora(O * I, 0.0)
    []float base_w = layer.base_weight
    if layer.quantized {
        base_w = dequantize_nf4(layer.base_nf4)
    }
    int idx = 0
    for idx < O * I {
        merged[idx] = base_w[idx] + delta[idx] * layer.scaling
        idx = idx + 1
    }

    lora_linear result = layer
    result.base_weight = merged
    result.quantized = false
    // 清零适配器 (已合并)
    result.lora_A = fill_lora(R * I, 0.0)
    result.lora_B = fill_lora(O * R, 0.0)
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
