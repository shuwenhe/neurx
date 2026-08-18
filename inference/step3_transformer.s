package step3_transformer
use std.text.int_to_string
use neurx.inference.safetensors_loader.{load_transformer_layer}
use neurx.inference.cpu_backend.{fast_matmul_flat_opt, fast_gelu, pow_f, fast_softmax}
use neurx.model.transformer.position_encoding.{new_rope_position_encoding, position_encoding_config, apply_rope_position}
extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func __sys_gettimeofday(int sec_ptr, int usec_ptr) int

struct timer {
    int start_sec
    int start_usec
}

func start_timer() timer {
    return timer{start_sec: 0, start_usec: 0}
}

func elapsed_ms(timer t) int {
    return 0
}

struct perf_stats {
    int layer
    int matmul_time_ms
    int rope_time_ms
    int attention_time_ms
    int ffn_time_ms
    int total_time_ms
}

struct transformer_config {
    int num_layers
    int hidden_size
    int num_heads
    int head_dim
    int intermediate_size
    float rope_theta
}

struct matrix_stats {
    float mean
    float sample
}

struct layer_perf_stats {
    int layer_id
    int matmul_count
    int attention_ops
    int ffn_ops
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

func compute_matrix_stats([][]float mat) matrix_stats {
    if len(mat) == 0 { return matrix_stats{mean: 0.0, sample: 0.0} }
    int R = len(mat)
    int C = 0
    if R > 0 { C = len(mat[0]) }
    if C == 0 { return matrix_stats{mean: 0.0, sample: 0.0} }
    int tot = R * C
    float sum = 0.0
    int r = 0
    while r < R {
        int c = 0
        while c < C {
            sum = sum + mat[r][c]
            c = c + 1
        }
        r = r + 1
    }
    float mean = sum / float(tot)
    float sample = 0.0
    int count = 0
    r = 0
    while r < R && count < 8 {
        int c = 0
        while c < C && count < 8 {
            sample = sample + mat[r][c]
            c = c + 1
            count = count + 1
        }
        r = r + 1
    }
    return matrix_stats{mean: mean, sample: sample}
}

func flatten_mat([][]float mat) []float {
    if len(mat) == 0 { return []float{} }
    int R = len(mat)
    int C = 0
    if R > 0 { C = len(mat[0]) }
    if C == 0 { return []float{} }
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
    return out
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
    int total_ops = 0
    print("[TRANSFORMER INFERENCE START]\n")
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
        matrix_stats stats_wq = compute_matrix_stats(Wq)
        matrix_stats stats_wk = compute_matrix_stats(Wk)
        matrix_stats stats_wv = compute_matrix_stats(Wv)
        matrix_stats stats_wo = compute_matrix_stats(Wo)
        matrix_stats stats_gate = compute_matrix_stats(Wgate)
        matrix_stats stats_up = compute_matrix_stats(Wup)
        matrix_stats stats_down = compute_matrix_stats(Wdown)
        print("[L" + int_to_string(layer) + "] Wq mean=" + int_to_string(int(stats_wq.mean * 1000000.0)) + " sample=" + int_to_string(int(stats_wq.sample * 1000000.0)) + "\n")
        print("[L" + int_to_string(layer) + "] Wk mean=" + int_to_string(int(stats_wk.mean * 1000000.0)) + " sample=" + int_to_string(int(stats_wk.sample * 1000000.0)) + "\n")
        print("[L" + int_to_string(layer) + "] Wv mean=" + int_to_string(int(stats_wv.mean * 1000000.0)) + " sample=" + int_to_string(int(stats_wv.sample * 1000000.0)) + "\n")
        print("[L" + int_to_string(layer) + "] Wo mean=" + int_to_string(int(stats_wo.mean * 1000000.0)) + " sample=" + int_to_string(int(stats_wo.sample * 1000000.0)) + "\n")
        print("[L" + int_to_string(layer) + "] Gate mean=" + int_to_string(int(stats_gate.mean * 1000000.0)) + " sample=" + int_to_string(int(stats_gate.sample * 1000000.0)) + "\n")
        print("[L" + int_to_string(layer) + "] Up mean=" + int_to_string(int(stats_up.mean * 1000000.0)) + " sample=" + int_to_string(int(stats_up.sample * 1000000.0)) + "\n")
        print("[L" + int_to_string(layer) + "] Down mean=" + int_to_string(int(stats_down.mean * 1000000.0)) + " sample=" + int_to_string(int(stats_down.sample * 1000000.0)) + "\n")
        []float fq = flatten_mat(Wq)
        []float fk = flatten_mat(Wk)
        []float fv = flatten_mat(Wv)
        []float fo = flatten_mat(Wo)
        []float fgate = flatten_mat(Wgate)
        []float fup = flatten_mat(Wup)
        []float fdown = flatten_mat(Wdown)
        []float Q = fast_matmul_flat_opt(A, fq, seq_len, hidden, hidden)
        []float K = fast_matmul_flat_opt(A, fk, seq_len, hidden, hidden)
        []float V = fast_matmul_flat_opt(A, fv, seq_len, hidden, hidden)
        pos_enc_cfg := position_encoding_config{
            hidden_dim: hidden,
            max_seq_len: seq_len,
            encoding_type: "rope",
            rope_base: 10000.0,
        }
        rope_enc := new_rope_position_encoding(pos_enc_cfg)
        [][]float rope_res = apply_rope_position(rope_enc, Q, K, seq_len, 0)
        Q = rope_res[0]
        K = rope_res[1]
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
                []float probs = []float{cap: seq_len}
                fast_softmax(scores, probs, seq_len)
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
        []float AttnProjected = fast_matmul_flat_opt(Out, fo, seq_len, hidden, hidden)
        int idx = 0
        while idx < seq_len * hidden {
            A[idx] = A[idx] + AttnProjected[idx]
            idx = idx + 1
        }
        []float Gate = fast_matmul_flat_opt(A, fgate, seq_len, hidden, 4864)
        []float Up = fast_matmul_flat_opt(A, fup, seq_len, hidden, 4864)
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
        []float FfnOut = fast_matmul_flat_opt(Gated, fdown, seq_len, 4864, hidden)
        int kk = 0
        while kk < seq_len * hidden {
            A[kk] = A[kk] + FfnOut[kk]
            kk = kk + 1
        }
        int layer_ops = seq_len * hidden * hidden * 3 + seq_len * seq_len * hidden + seq_len * hidden * 4864 * 2
        total_ops = total_ops + layer_ops
        print("[L" + int_to_string(layer) + "] ops=" + int_to_string(layer_ops / 1000000) + "M\n")
        layer = layer + 1
    }
    print("[TRANSFORMER INFERENCE END] total_ops=" + int_to_string(total_ops / 1000000000) + "B\n\n")
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
