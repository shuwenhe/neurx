package neurx.moe.transformer_backward
use neurx.moe.transformer.{
    moe_layer, moe_config, moe_expert, routing_decision, moe_output,
    moe_route, moe_expert_forward, moe_capacity
}
use neurx.model.llm.gpt.{gpt_alloc, gpt_matmul, gpt_swish, gpt_sigmoid}

struct moe_expert_grads {
    []float d_gate_weight
    []float d_value_weight
    []float d_down_weight
}


struct moe_layer_grads {
    []float d_router_weight
    []moe_expert_grads d_experts
    []float d_hidden
    float d_aux_loss_scale
}


func moe_swish_grad(float x) float {
    float s = gpt_sigmoid(x)
    s + x * s * (1.0 - s)
}


func moe_expert_backward(
    moe_expert expert,
    []float token_hidden,
    []float d_out,
    int H, int D
) ([]float, moe_expert_grads) {
    []float gate_pre = moe_alloc(D, 0.0)
    []float value_pre = moe_alloc(D, 0.0)
    int j = 0
    while j < D {
        float g = 0.0
        float v = 0.0
        int d = 0
        while d < H {
            g = g + token_hidden[d] * expert.gate_weight[d * D + j]
            v = v + token_hidden[d] * expert.value_weight[d * D + j]
            d = d + 1
        }
        gate_pre[j] = g
        value_pre[j] = v
        j = j + 1
    }
    []float swish_g = moe_alloc(D, 0.0)
    j = 0
    while j < D {
        swish_g[j] = gpt_swish(gate_pre[j])
        j = j + 1
    }
    []float d_gv = moe_alloc(D, 0.0)
    []float d_down_w = moe_alloc(D * H, 0.0)
    int d = 0
    while d < H {
        j = 0
        while j < D {
            d_gv[j] = d_gv[j] + expert.down_weight[j * H + d] * d_out[d]
            d_down_w[j * H + d] = d_down_w[j * H + d] + swish_g[j] * value_pre[j] * d_out[d]
            j = j + 1
        }
        d = d + 1
    }
    []float d_swish_g = moe_alloc(D, 0.0)
    []float d_value_pre = moe_alloc(D, 0.0)
    j = 0
    while j < D {
        d_swish_g[j] = d_gv[j] * value_pre[j]
        d_value_pre[j] = d_gv[j] * swish_g[j]
        j = j + 1
    }
    []float d_gate_pre = moe_alloc(D, 0.0)
    j = 0
    while j < D {
        d_gate_pre[j] = d_swish_g[j] * moe_swish_grad(gate_pre[j])
        j = j + 1
    }
    []float d_gate_w  = moe_alloc(H * D, 0.0)
    []float d_value_w = moe_alloc(H * D, 0.0)
    d = 0
    while d < H {
        j = 0
        while j < D {
            d_gate_w[d * D + j]  = token_hidden[d] * d_gate_pre[j]
            d_value_w[d * D + j] = token_hidden[d] * d_value_pre[j]
            j = j + 1
        }
        d = d + 1
    }
    []float d_h = moe_alloc(H, 0.0)
    d = 0
    while d < H {
        float s = 0.0
        j = 0
        while j < D {
            s = s + expert.gate_weight[d * D + j] * d_gate_pre[j]
                  + expert.value_weight[d * D + j] * d_value_pre[j]
            j = j + 1
        }
        d_h[d] = s
        d = d + 1
    }
    moe_expert_grads eg = moe_expert_grads {
        d_gate_weight: d_gate_w,
        d_value_weight: d_value_w,
        d_down_weight: d_down_w,
    }
    (d_h, eg)
}


func moe_softmax_bk([]float probs, []float d_logprob, int E) []float {
    float dot = 0.0
    int e = 0
    while e < E { dot = dot + d_logprob[e] * probs[e]; e = e + 1 }
    []float d_scores = moe_alloc(E, 0.0)
    e = 0
    while e < E {
        d_scores[e] = probs[e] * (d_logprob[e] - dot)
        e = e + 1
    }
    d_scores
}


func moe_backward(
    moe_layer layer,
    []float hidden,
    routing_decision route,
    []float d_output,
    int tokens
) moe_layer_grads {
    int H = layer.hidden_dim
    int D = layer.expert_dim
    int E = layer.num_experts
    int K = layer.top_k
    []float d_hidden = moe_alloc(tokens * H, 0.0)
    []float d_router_weight = moe_alloc(H * E, 0.0)
    []moe_expert_grads expert_grads = []moe_expert_grads{cap: E}
    int e = 0
    while e < E {
        expert_grads[e] = moe_expert_grads {
            d_gate_weight:  moe_alloc(H * D, 0.0),
            d_value_weight: moe_alloc(H * D, 0.0),
            d_down_weight:  moe_alloc(D * H, 0.0),
        }
        e = e + 1
    }
    int capacity = moe_capacity(tokens, E, K, layer.config.capacity_factor)
    []int expert_counts = []int{cap: E}
    int ec = 0
    while ec < E { expert_counts[ec] = 0; ec = ec + 1 }
    int t = 0
    while t < tokens {
        []float h_t = moe_alloc(H, 0.0)
        int d = 0
        while d < H { h_t[d] = hidden[t * H + d]; d = d + 1 }
        []float d_gate_logit = moe_alloc(E, 0.0)
        []float probs_t = moe_alloc(E, 0.0)
        e = 0
        while e < E {
            probs_t[e] = route.router_probs[t * E + e]
            e = e + 1
        }
        int k = 0
        while k < K {
            int eid = route.expert_ids[t * K + k]
            float g = route.gate_weights[t * K + k]
            if expert_counts[eid] < capacity {
                expert_counts[eid] = expert_counts[eid] + 1
                []float d_eo = moe_alloc(H, 0.0)
                d = 0
                while d < H {
                    d_eo[d] = d_output[t * H + d] * g
                    d = d + 1
                }
                []float d_h_e
                moe_expert_grads eg
                (d_h_e, eg) = moe_expert_backward(layer.experts[eid], h_t, d_eo, H, D)
                d = 0
                while d < H {
                    d_hidden[t * H + d] = d_hidden[t * H + d] + d_h_e[d]
                    d = d + 1
                }
                int n = H * D
                d = 0
                while d < n {
                    expert_grads[eid].d_gate_weight[d]  = expert_grads[eid].d_gate_weight[d]  + eg.d_gate_weight[d]
                    expert_grads[eid].d_value_weight[d] = expert_grads[eid].d_value_weight[d] + eg.d_value_weight[d]
                    d = d + 1
                }
                n = D * H
                d = 0
                while d < n {
                    expert_grads[eid].d_down_weight[d] = expert_grads[eid].d_down_weight[d] + eg.d_down_weight[d]
                    d = d + 1
                }
                moe_expert ex = layer.experts[eid]
                []float eo = moe_expert_forward(ex, h_t, H, D)
                float dot_eo_do = 0.0
                d = 0
                while d < H {
                    dot_eo_do = dot_eo_do + d_output[t * H + d] * eo[d]
                    d = d + 1
                }
                d_gate_logit[eid] = d_gate_logit[eid] + dot_eo_do
            }
            k = k + 1
        }
        []float d_router_logit = moe_softmax_bk(probs_t, d_gate_logit, E)
        d = 0
        while d < H {
            e = 0
            while e < E {
                d_router_weight[d * E + e] = d_router_weight[d * E + e] + h_t[d] * d_router_logit[e]
                e = e + 1
            }
            d = d + 1
        }
        t = t + 1
    }
    moe_layer_grads {
        d_router_weight: d_router_weight,
        d_experts: expert_grads,
        d_hidden: d_hidden,
        d_aux_loss_scale: layer.config.aux_loss_weight,
    }
}


struct moe_adamw_state {
    []float m_router     []float v_router
    [][]float m_gate_w   [][]float v_gate_w
    [][]float m_value_w  [][]float v_value_w
    [][]float m_down_w   [][]float v_down_w
    int step
    float lr
    float beta1
    float beta2
    float eps
    float weight_decay
}


func new_moe_adamw_state(moe_layer layer) moe_adamw_state {
    int H = layer.hidden_dim
    int D = layer.expert_dim
    int E = layer.num_experts
    [][]float m_gw = [][]float{cap: E}
    [][]float v_gw = [][]float{cap: E}
    [][]float m_vw = [][]float{cap: E}
    [][]float v_vw = [][]float{cap: E}
    [][]float m_dw = [][]float{cap: E}
    [][]float v_dw = [][]float{cap: E}
    int e = 0
    while e < E {
        m_gw[e] = moe_alloc(H * D, 0.0)
        v_gw[e] = moe_alloc(H * D, 0.0)
        m_vw[e] = moe_alloc(H * D, 0.0)
        v_vw[e] = moe_alloc(H * D, 0.0)
        m_dw[e] = moe_alloc(D * H, 0.0)
        v_dw[e] = moe_alloc(D * H, 0.0)
        e = e + 1
    }
    moe_adamw_state {
        m_router: moe_alloc(H * E, 0.0),
        v_router: moe_alloc(H * E, 0.0),
        m_gate_w: m_gw, v_gate_w: v_gw,
        m_value_w: m_vw, v_value_w: v_vw,
        m_down_w: m_dw, v_down_w: v_dw,
        step: 0,
        lr: 0.0003, beta1: 0.9, beta2: 0.95, eps: 1e-8, weight_decay: 0.1,
    }
}


func moe_adamw_vec([]float p, []float g, []float m, []float v, int step, float lr, float b1, float b2, float eps, float wd) []float {
    float bc1 = 1.0 - moe_pow(b1, step)
    float bc2 = 1.0 - moe_pow(b2, step)
    int n = len(p)
    []float out = moe_alloc(n, 0.0)
    int i = 0
    while i < n {
        m[i] = b1 * m[i] + (1.0 - b1) * g[i]
        v[i] = b2 * v[i] + (1.0 - b2) * g[i] * g[i]
        float mh = m[i] / bc1
        float vh = v[i] / bc2
        out[i] = p[i] * (1.0 - lr * wd) - lr * mh / (moe_sqrt(vh) + eps)
        i = i + 1
    }
    out
}


func moe_adamw_step(moe_layer layer, moe_layer_grads grads, moe_adamw_state opt) (moe_layer, moe_adamw_state) {
    opt.step = opt.step + 1
    int s = opt.step
    float lr = opt.lr
    float b1 = opt.beta1
    float b2 = opt.beta2
    float eps = opt.eps
    float wd = opt.weight_decay
    layer.router_weight = moe_adamw_vec(layer.router_weight, grads.d_router_weight, opt.m_router, opt.v_router, s, lr, b1, b2, eps, wd)
    int e = 0
    while e < layer.num_experts {
        moe_expert_grads eg = grads.d_experts[e]
        layer.experts[e].gate_weight  = moe_adamw_vec(layer.experts[e].gate_weight,  eg.d_gate_weight,  opt.m_gate_w[e],  opt.v_gate_w[e],  s, lr, b1, b2, eps, wd)
        layer.experts[e].value_weight = moe_adamw_vec(layer.experts[e].value_weight, eg.d_value_weight, opt.m_value_w[e], opt.v_value_w[e], s, lr, b1, b2, eps, wd)
        layer.experts[e].down_weight  = moe_adamw_vec(layer.experts[e].down_weight,  eg.d_down_weight,  opt.m_down_w[e],  opt.v_down_w[e],  s, lr, b1, b2, eps, wd)
        e = e + 1
    }
    (layer, opt)
}


func moe_alloc(int n, float v) []float {
    []float arr = []float{cap: n}
    int i = 0
    while i < n { arr[i] = v; i = i + 1 }
    arr
}


func moe_sqrt(float x) float {
    if x <= 0.0 { return 0.0 }
    float y = x
    int i = 0
    while i < 15 { y = 0.5 * (y + x / y); i = i + 1 }
    y
}


func moe_pow(float base, int exp) float {
    float r = 1.0
    int e = exp
    while e > 0 { r = r * base; e = e - 1 }
    r
}

