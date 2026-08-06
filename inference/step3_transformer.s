package step3_transformer

use neurx.inference.safetensors_loader.{load_transformer_layer}
use neurx.inference.cpu_backend.{fast_matmul_flat, fast_gelu, pow_f}

extern "intrinsic" func __host_slice(string text, int start, int end) string

func int_to_string(int val) string {
    if val == 0 { return "0" }
    string res = ""
    int cur = val
    if cur < 0 { cur = -cur }
    while cur != 0 {
        int d = cur - (cur / 10) * 10
        res = __host_slice("0123456789", d, d+1) + res
        cur = cur / 10
    }
    res
}

struct transformer_config {
    int num_layers
    int hidden_size
    int num_heads
    int head_dim
    int intermediate_size
    float rope_theta
}

func create_transformer_config() transformer_config {
    return transformer_config{
        num_layers: 24,
        hidden_size: 896,
        num_heads: 14,
        head_dim: 64,
        intermediate_size: 4864,
        rope_theta: 10000.0
    }
}

func apply_rope([]float x, int position, float theta) []float {
    return x
}

func multi_head_attention([][]float query, [][]float key, [][]float value, int num_heads) [][]float {
    return query
}

func feed_forward([][]float x) [][]float {
    return x
}

func rms_norm([][]float x) [][]float {
    return x
}

func transformer_layer([][]float hidden_states) [][]float {
    return hidden_states
}

func apply_rope_flat([]float q, []float k, int seq_len, int num_heads, int head_dim, float theta) ( []float, []float ) {
    int total_dim = num_heads * head_dim
    int t = 0
    while t < seq_len {
        int h = 0
        while h < num_heads {
            int base = h * head_dim
            int d = 0
            while d < head_dim {
                int idx = t * total_dim + base + d
                float pos = float(t)
                float theta_k = pos / pow_f(theta, float(d) / float(head_dim))
                float cosv = 1.0
                float sinv = theta_k
                float qv = q[idx]
                float kv = k[idx]
                q[idx] = qv * cosv - kv * sinv
                k[idx] = kv * cosv + qv * sinv
                d = d + 1
            }
            h = h + 1
        }
        t = t + 1
    }
    (q, k)
}

func exp_approx(float x) float {
    if x > 20.0 { return 485165195.0 }
    if x < -20.0 { return 0.0 }
    float term = 1.0
    float result = 1.0
    int i = 1
    while i <= 10 {
        term = term * x / float(i)
        result = result + term
        i = i + 1
    }
    result
}

func softmax_row([]float scores, int length) []float {
    []float out = []float{cap: length}
    if length == 0 { return out }
    float maxv = scores[0]
    int i = 1
    while i < length {
        if scores[i] > maxv { maxv = scores[i] }
        i = i + 1
    }
    float sumexp = 0.0
    i = 0
    while i < length {
        float v = scores[i] - maxv
        float e = exp_approx(v)
        out[i] = e
        sumexp = sumexp + e
        i = i + 1
    }
    if sumexp == 0.0 { return out }
    i = 0
    while i < length {
        out[i] = out[i] / sumexp
        i = i + 1
    }
    out
}

func transformer_forward([][]float embeddings) [][]float {
    int seq_len = len(embeddings)
    if seq_len == 0 { return embeddings }
    int hidden = len(embeddings[0])
    string model_file = "/home/shuwen/shuwen/posttrain/model.safetensors"

    []float A = []float{cap: seq_len * hidden}
    int i = 0
    while i < seq_len {
        int j = 0
        while j < hidden {
            A[i * hidden + j] = embeddings[i][j]
            j = j + 1
        }
        i = i + 1
    }

    int num_layers = 24
    int layer = 0
    while layer < num_layers {
        map[string][][]float weights = load_transformer_layer(model_file, layer, hidden, 14)
        string base = "model.layers." + int_to_string(layer) + "."
        [][]float Wq = weights[base + "self_attn.q_proj.weight"]
        [][]float Wk = weights[base + "self_attn.k_proj.weight"]
        [][]float Wv = weights[base + "self_attn.v_proj.weight"]
        [][]float Wo = weights[base + "self_attn.o_proj.weight"]
        [][]float Wgate = weights[base + "mlp.gate_proj.weight"]
        [][]float Wup = weights[base + "mlp.up_proj.weight"]
        [][]float Wdown = weights[base + "mlp.down_proj.weight"]

        func flatten_mat(mat [][]float) []float {
            if mat == nil || len(mat) == 0 { return []float{} }
            int R = len(mat)
            int C = len(mat[0])
            []float out = []float{cap: R * C}
            int r = 0
            while r < R {
                int c = 0
                while c < C {
                    out[r * C + c] = mat[r][c]
                    c = c + 1
                }
                r = r + 1
            }
            out
        }

        []float fq = flatten_mat(Wq)
        []float fk = flatten_mat(Wk)
        []float fv = flatten_mat(Wv)
        []float fo = flatten_mat(Wo)
        []float fgate = flatten_mat(Wgate)
        []float fup = flatten_mat(Wup)
        []float fdown = flatten_mat(Wdown)

        []float Q = fast_matmul_flat(A, fq, seq_len, hidden, hidden)
        []float K = fast_matmul_flat(A, fk, seq_len, hidden, hidden)
        []float V = fast_matmul_flat(A, fv, seq_len, hidden, hidden)

        (Q, K) = apply_rope_flat(Q, K, seq_len, 14, hidden / 14, 10000.0)

        int num_heads = 14
        int head_dim = hidden / num_heads
        []float Out = []float{cap: seq_len * hidden}
        int qi = 0
        float scale = 1.0 / pow_f(float(head_dim), 0.5)
        while qi < seq_len {
            int h = 0
            while h < num_heads {
                int q_off = qi * hidden + h * head_dim
                []float scores = []float{cap: seq_len}
                int kj = 0
                while kj < seq_len {
                    int k_off = kj * hidden + h * head_dim
                    float dot = 0.0
                    int d = 0
                    while d < head_dim {
                        dot = dot + Q[q_off + d] * K[k_off + d]
                        d = d + 1
                    }
                    float s = dot * scale
                    if kj > qi { s = s - 1e9 }
                    scores[kj] = s
                    kj = kj + 1
                }
                []float probs = softmax_row(scores, seq_len)
                int d2 = 0
                while d2 < head_dim {
                    float acc = 0.0
                    int k2 = 0
                    while k2 < seq_len {
                        int v_off = k2 * hidden + h * head_dim + d2
                        acc = acc + probs[k2] * V[v_off]
                        k2 = k2 + 1
                    }
                    Out[qi * hidden + h * head_dim + d2] = acc
                    d2 = d2 + 1
                }
                h = h + 1
            }
            qi = qi + 1
        }

        []float AttnProjected = fast_matmul_flat(Out, fo, seq_len, hidden, hidden)

        int idx = 0
        while idx < seq_len * hidden {
            A[idx] = A[idx] + AttnProjected[idx]
            idx = idx + 1
        }

        []float Gate = fast_matmul_flat(A, fgate, seq_len, hidden, 4864)
        []float Up = fast_matmul_flat(A, fup, seq_len, hidden, 4864)
        []float Gated = []float{cap: seq_len * 4864}
        int ii = 0
        while ii < seq_len {
            int jj = 0
            while jj < 4864 {
                int pos = ii * 4864 + jj
                Gated[pos] = Up[pos] * fast_gelu(Gate[pos])
                jj = jj + 1
            }
            ii = ii + 1
        }
        []float FfnOut = fast_matmul_flat(Gated, fdown, seq_len, 4864, hidden)

        int kk = 0
        while kk < seq_len * hidden {
            A[kk] = A[kk] + FfnOut[kk]
            kk = kk + 1
        }

        layer = layer + 1
    }

    [][]float result = [][]float{cap: seq_len}
    int r = 0
    while r < seq_len {
        []float row = []float{cap: hidden}
        int c = 0
        while c < hidden {
            row.push(A[r * hidden + c])
            c = c + 1
        }
        result.push(row)
        r = r + 1
    }
    result
}
