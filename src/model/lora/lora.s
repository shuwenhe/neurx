package neurx.model.lora

struct lora_config {
    int rank
    float alpha
    float dropout
    string target_modules
    bool merge_weights
    bool use_qlora
    string qlora_dtype
    float lora_lr
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
    []int   codes
    float   absmax
    int     num_elem
    []float codebook
}

func quantize_nf4([]float w, int n) nf4_tensor {
    []float cb = nf4_codebook()
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
        float wn = w[j] / amax
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

func matmul_lora([]float a, []float b, int M, int K, int N, bool transpose_b) []float {
    []float c = []float{cap: M * N}
    int i = 0
    for i < M {
        int j = 0
        for j < N {
            float s = 0.0
            int kk = 0
            for kk < K {
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
    for i < exp {
        result = result * base
        i = i + 1
    }
    result
}

struct lora_linear {
    []float base_weight
    nf4_tensor base_nf4
    bool quantized
    []float lora_a
    []float lora_b
    []float lora_a_grad
    []float lora_b_grad
    int in_dim
    int out_dim
    int rank
    float scaling
    float dropout_rate
    []float last_input
    []float last_ax
}

func new_lora_linear(int in_dim, int out_dim, []float base_weight, lora_config cfg) lora_linear {
    if cfg.use_qlora {
        nf4_tensor q = quantize_nf4(base_weight, in_dim * out_dim)
        lora_linear {
            base_weight: []float{},
            base_nf4: q,
            quantized: true,
            lora_a: []float{cap: cfg.rank * in_dim},
            lora_b: []float{cap: out_dim * cfg.rank},
            lora_a_grad: []float{cap: cfg.rank * in_dim},
            lora_b_grad: []float{cap: out_dim * cfg.rank},
            in_dim: in_dim,
            out_dim: out_dim,
            rank: cfg.rank,
            scaling: cfg.alpha,
            dropout_rate: cfg.dropout,
            last_input: []float{},
            last_ax: []float{},
        }
    } else {
        lora_linear {
            base_weight: base_weight,
            base_nf4: nf4_tensor{ codes: []int{}, absmax: 0.0, num_elem: 0, codebook: []float{} },
            quantized: false,
            lora_a: []float{cap: cfg.rank * in_dim},
            lora_b: []float{cap: out_dim * cfg.rank},
            lora_a_grad: []float{cap: cfg.rank * in_dim},
            lora_b_grad: []float{cap: out_dim * cfg.rank},
            in_dim: in_dim,
            out_dim: out_dim,
            rank: cfg.rank,
            scaling: cfg.alpha,
            dropout_rate: cfg.dropout,
            last_input: []float{},
            last_ax: []float{},
        }
    }
}

func lora_forward(lora_linear layer, []float x, int batch) lora_linear {
    []float y = []float{}
    []float ax = []float{}
    int in_dim = layer.in_dim
    int b = 0
    for b < batch {
        int r = 0
        for r < layer.rank {
            float ax_sum = 0.0
            int i = 0
            for i < in_dim {
                ax_sum = ax_sum + x[b*in_dim+i] * layer.lora_A[r*in_dim+i]
                i = i + 1
            }
            ax = append(ax, ax_sum)
            r = r + 1
        }
        int o = 0
        for o < layer.out_dim {
            float sum = 0.0
            int i2 = 0
            for i2 < in_dim {
                float base_w = layer.base_weight[o*in_dim+i2]
                sum = sum + x[b*in_dim+i2] * base_w
                i2 = i2 + 1
            }
            int r2 = 0
            float lora_sum = 0.0
            for r2 < layer.rank {
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

struct lora_forward_result {
    lora_linear updated_layer
    []float output
}

func lora_forward_with_output(lora_linear layer, []float x, int batch) lora_forward_result {
    []float y = []float{}
    []float ax = []float{}
    int in_dim = layer.in_dim
    int b = 0
    for b < batch {
        int r = 0
        for r < layer.rank {
            float ax_sum = 0.0
            int i = 0
            for i < in_dim {
                ax_sum = ax_sum + x[b*in_dim+i] * layer.lora_A[r*in_dim+i]
                i = i + 1
            }
            ax = append(ax, ax_sum)
            r = r + 1
        }
        int o = 0
        for o < layer.out_dim {
            float sum = 0.0
            int i2 = 0
            for i2 < in_dim {
                float base_w = layer.base_weight[o*in_dim+i2]
                sum = sum + x[b*in_dim+i2] * base_w
                i2 = i2 + 1
            }
            int r2 = 0
            float lora_sum = 0.0
            for r2 < layer.rank {
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
    lora_forward_result { updated_layer: updated, output: y }
}

struct lora_backward_result {
    lora_linear updated_layer
    []float dx
}

func lora_backward(lora_linear layer, []float dy, int batch) lora_backward_result {
    []float x  = []float{}
    []float ax = []float{}
    []float d_b = []float{}
    []float d_a = []float{}
    []float dx = []float{}
    int in_dim = layer.in_dim
    x = layer.last_input
    ax = layer.last_Ax
    int fill_d = 0
    for fill_d < layer.out_dim * layer.rank {
        d_b = append(d_b, 0.0)
        fill_d = fill_d + 1
    }
    fill_d = 0
    for fill_d < layer.rank * in_dim {
        d_a = append(d_a, 0.0)
        fill_d = fill_d + 1
    }
    fill_d = 0
    for fill_d < batch * in_dim {
        dx = append(dx, 0.0)
        fill_d = fill_d + 1
    }
    int b = 0
    for b < batch {
        int o = 0
        for o < layer.out_dim {
            float dy_scaled = dy[b*layer.out_dim+o] * layer.scaling
            int r = 0
            for r < layer.rank {
                d_b[o*layer.rank+r] = d_b[o*layer.rank+r] + dy_scaled * ax[b*layer.rank+r]
                r = r + 1
            }
            int i = 0
            for i < in_dim {
                dx[b*in_dim+i] = dx[b*in_dim+i] + dy_scaled * layer.base_weight[o*in_dim+i]
                i = i + 1
            }
            o = o + 1
        }
        int r2 = 0
        for r2 < rank {
            int i2 = 0
            for i2 < in_dim {
                float accum = 0.0
                int o2 = 0
                for o2 < layer.out_dim {
                    accum = accum + dy[b*layer.out_dim+o2] * layer.scaling * layer.lora_B[o2*layer.rank+r2]
                    o2 = o2 + 1
                }
                d_a[r2*in_dim+i2] = d_a[r2*in_dim+i2] + accum * x[b*in_dim+i2]
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
        updated.lora_A_grad[ga] = updated.lora_A_grad[ga] + d_a[ga]
        ga = ga + 1
    }
    int gb = 0
    for gb < layer.out_dim * layer.rank {
        updated.lora_B_grad[gb] = updated.lora_B_grad[gb] + d_b[gb]
        gb = gb + 1
    }
    lora_backward_result { updated_layer: updated, dx: dx }
}

struct lora_adamw_state {
    []float m_a
    []float v_a
    []float m_b
    []float v_b
    float lr
    float beta1
    float beta2
    float eps
    float weight_decay
    int step
}

func new_lora_adamw(int rank, int in_dim, int out_dim, float lr) lora_adamw_state {
    lora_adamw_state {
        m_a: []float{cap: rank * in_dim},
        v_a: []float{cap: rank * in_dim},
        m_b: []float{cap: out_dim * rank},
        v_b: []float{cap: out_dim * rank},
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

func lora_merge_weights(lora_linear layer) lora_linear {
    []float merged = []float{}
    int in_dim = layer.in_dim
    int fill_m = 0
    for fill_m < layer.out_dim * in_dim {
        merged = append(merged, 0.0)
        fill_m = fill_m + 1
    }
    int o = 0
    for o < layer.out_dim {
        int i = 0
        for i < in_dim {
            float sum = layer.base_weight[o*in_dim+i]
            int r = 0
            for r < layer.rank {
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

struct lora_checkpoint {
    int in_dim
    int out_dim
    int rank
    float alpha
    []float lora_a
    []float lora_b
    string layer_name
}

func lora_save_checkpoint(lora_linear layer, float alpha, string name) lora_checkpoint {
    lora_checkpoint {
        in_dim: layer.in_dim,
        out_dim: layer.out_dim,
        rank: layer.rank,
        alpha: alpha,
        lora_a: layer.lora_A,
        lora_b: layer.lora_B,
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

struct lora_stats {
    int total_base_params
    int total_lora_params
    float trainable_ratio
    int rank
    float memory_saved_mb
}

func lora_compute_stats(lora_linear layer) lora_stats {
    int base_params = layer.in_dim * layer.out_dim
    int lora_params = layer.rank * (layer.in_dim + layer.out_dim)
    float ratio = (lora_params * 1.0) / ((base_params + lora_params) * 1.0)
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
