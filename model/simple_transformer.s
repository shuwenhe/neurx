package neurx.model.simple_transformer
use neurx.tensor
struct simple_transformer {
    vocab_size i64
    hidden_size i64
    num_layers i64
    num_heads i64
    max_seq_len i64
    embeddings [][]f64
    pos_embeddings [][]f64
    attention_w_q [][][]f64
    attention_w_k [][][]f64
    attention_w_v [][][]f64
    attention_w_o [][][]f64
    ff_w1 [][][]f64
    ff_w2 [][][]f64
    ln_gamma [][][]f64
    ln_beta [][][]f64
    output_weight [][]f64
}

struct transformer_output {
    logits [][]f64
    hidden_states [][]f64
}

func transformer_new(vocab_size i64, hidden_size i64, num_layers i64, num_heads i64, max_seq_len i64) simple_transformer {
    t := simple_transformer{
        vocab_size: vocab_size,
        hidden_size: hidden_size,
        num_layers: num_layers,
        num_heads: num_heads,
        max_seq_len: max_seq_len,
        embeddings: make([][]f64, vocab_size),
        pos_embeddings: make([][]f64, max_seq_len),
        attention_w_q: make([][][]f64, num_layers),
        attention_w_k: make([][][]f64, num_layers),
        attention_w_v: make([][][]f64, num_layers),
        attention_w_o: make([][][]f64, num_layers),
        ff_w1: make([][][]f64, num_layers),
        ff_w2: make([][][]f64, num_layers),
        ln_gamma: make([][][]f64, num_layers),
        ln_beta: make([][][]f64, num_layers),
        output_weight: make([][]f64, hidden_size),
    }
    for i := 0; i < len(t.embeddings); i++ {
        t.embeddings[i] = make([]f64, hidden_size)
        for j := 0; j < hidden_size; j++ {
            t.embeddings[i][j] = random_normal() * 0.02
        }
    }
    for i := 0; i < len(t.pos_embeddings); i++ {
        t.pos_embeddings[i] = make([]f64, hidden_size)
        for j := 0; j < hidden_size; j++ {
            dim := f64(j)
            freq := 1.0 / pow_approx(10000.0, dim/f64(hidden_size))
            if j % 2 == 0 {
                t.pos_embeddings[i][j] = sin_approx(f64(i) * freq)
            } else {
                t.pos_embeddings[i][j] = cos_approx(f64(i) * freq)
            }
        }
    }
    for l := 0; l < len(t.attention_w_q); l++ {
        t.attention_w_q[l] = make([][]f64, hidden_size)
        t.attention_w_k[l] = make([][]f64, hidden_size)
        t.attention_w_v[l] = make([][]f64, hidden_size)
        t.attention_w_o[l] = make([][]f64, hidden_size)
        t.ff_w1[l] = make([][]f64, hidden_size)
        t.ff_w2[l] = make([][]f64, hidden_size*4)
        t.ln_gamma[l] = make([][]f64, 2)
        t.ln_beta[l] = make([][]f64, 2)
        for i := 0; i < hidden_size; i++ {
            t.attention_w_q[l][i] = make([]f64, hidden_size)
            t.attention_w_k[l][i] = make([]f64, hidden_size)
            t.attention_w_v[l][i] = make([]f64, hidden_size)
            t.attention_w_o[l][i] = make([]f64, hidden_size)
            for j := 0; j < hidden_size; j++ {
                t.attention_w_q[l][i][j] = random_normal() * 0.02
                t.attention_w_k[l][i][j] = random_normal() * 0.02
                t.attention_w_v[l][i][j] = random_normal() * 0.02
                t.attention_w_o[l][i][j] = random_normal() * 0.02
            }
        }
        for i := 0; i < hidden_size; i++ {
            t.ff_w1[l][i] = make([]f64, hidden_size*4)
            for j := 0; j < hidden_size*4; j++ {
                t.ff_w1[l][i][j] = random_normal() * 0.02
            }
        }
        for i := 0; i < hidden_size*4; i++ {
            t.ff_w2[l][i] = make([]f64, hidden_size)
            for j := 0; j < hidden_size; j++ {
                t.ff_w2[l][i][j] = random_normal() * 0.02
            }
        }
        t.ln_gamma[l][0] = make([]f64, hidden_size)
        t.ln_beta[l][0] = make([]f64, hidden_size)
        t.ln_gamma[l][1] = make([]f64, hidden_size)
        t.ln_beta[l][1] = make([]f64, hidden_size)
        for i := 0; i < hidden_size; i++ {
            t.ln_gamma[l][0][i] = 1.0
            t.ln_beta[l][0][i] = 0.0
            t.ln_gamma[l][1][i] = 1.0
            t.ln_beta[l][1][i] = 0.0
        }
    }
    for i := 0; i < hidden_size; i++ {
        t.output_weight[i] = make([]f64, vocab_size)
        for j := 0; j < vocab_size; j++ {
            t.output_weight[i][j] = random_normal() * 0.02
        }
    }
    return t
}

func transformer_forward(t simple_transformer, input_ids [][]i64) transformer_output {
    batch_size := i64(len(input_ids))
    seq_len := i64(len(input_ids[0]))
    hidden_size := t.hidden_size
    hidden := make([][]f64, batch_size*seq_len)
    for b := 0; b < len(input_ids); b++ {
        for s := 0; s < len(input_ids[b]); s++ {
            token_id := int(input_ids[b][s])
            idx := b * len(input_ids[b]) + s
            hidden[idx] = make([]f64, hidden_size)
            for h := 0; h < hidden_size; h++ {
                if token_id >= 0 && token_id < len(t.embeddings) {
                    hidden[idx][h] = t.embeddings[token_id][h] + t.pos_embeddings[s][h]
                } else {
                    hidden[idx][h] = t.pos_embeddings[s][h]
                }
            }
        }
    }
    for layer := 0; layer < len(t.attention_w_q); layer++ {
        q := matrix_multiply(hidden, t.attention_w_q[layer])
        k := matrix_multiply(hidden, t.attention_w_k[layer])
        v := matrix_multiply(hidden, t.attention_w_v[layer])
        attn_out := matrix_multiply(v, t.attention_w_o[layer])
        hidden = layer_norm(add_vectors(hidden, attn_out), t.ln_gamma[layer][0], t.ln_beta[layer][0])
        ff_hidden := matrix_multiply(hidden, t.ff_w1[layer])
        ff_hidden = apply_relu(ff_hidden)
        ff_out := matrix_multiply(ff_hidden, t.ff_w2[layer])
        hidden = layer_norm(add_vectors(hidden, ff_out), t.ln_gamma[layer][1], t.ln_beta[layer][1])
    }
    logits_flat := matrix_multiply(hidden, t.output_weight)
    logits := make([][]f64, batch_size*seq_len)
    for i := 0; i < len(logits_flat); i++ {
        logits[i] = logits_flat[i]
    }
    return transformer_output{
        logits: logits,
        hidden_states: hidden,
    }
}

func matrix_multiply(a [][]f64, b [][]f64) [][]f64 {
    if len(a) == 0 || len(b) == 0 {
        return make([][]f64, 0)
    }
    rows := len(a)
    cols := len(b[0])
    result := make([][]f64, rows)
    for i := 0; i < rows; i++ {
        result[i] = make([]f64, cols)
        for j := 0; j < cols; j++ {
            sum := 0.0
            for k := 0; k < len(b); k++ {
                sum = sum + a[i][k]*b[k][j]
            }
            result[i][j] = sum
        }
    }
    return result
}

func add_vectors(a [][]f64, b [][]f64) [][]f64 {
    result := make([][]f64, len(a))
    for i := 0; i < len(a); i++ {
        result[i] = make([]f64, len(a[i]))
        for j := 0; j < len(a[i]); j++ {
            result[i][j] = a[i][j] + b[i][j]
        }
    }
    return result
}

func apply_relu(x [][]f64) [][]f64 {
    result := make([][]f64, len(x))
    for i := 0; i < len(x); i++ {
        result[i] = make([]f64, len(x[i]))
        for j := 0; j < len(x[i]); j++ {
            if x[i][j] > 0.0 {
                result[i][j] = x[i][j]
            } else {
                result[i][j] = 0.0
            }
        }
    }
    return result
}

func layer_norm(x [][]f64, gamma []f64, beta []f64) [][]f64 {
    result := make([][]f64, len(x))
    eps := 1e-6
    for i := 0; i < len(x); i++ {
        result[i] = make([]f64, len(x[i]))
        mean := 0.0
        for j := 0; j < len(x[i]); j++ {
            mean = mean + x[i][j]
        }
        mean = mean / f64(len(x[i]))
        variance := 0.0
        for j := 0; j < len(x[i]); j++ {
            diff := x[i][j] - mean
            variance = variance + diff*diff
        }
        variance = variance / f64(len(x[i]))
        std := sqrt_approx(variance + eps)
        for j := 0; j < len(x[i]); j++ {
            normalized := (x[i][j] - mean) / std
            result[i][j] = gamma[j]*normalized + beta[j]
        }
    }
    return result
}

func random_normal() f64 {
    u1 := f64(random_int_range(0, 10000)) / 10000.0
    u2 := f64(random_int_range(0, 10000)) / 10000.0
    if u1 < 0.0001 {
        u1 = 0.0001
    }
    r := sqrt_approx(-2.0 * ln_approx(u1))
    return r * cos_approx(2.0 * 3.14159265 * u2)
}

func random_int_range(min i64, max i64) i64 {
    return min + ((1103515245*min + 12345) % (max - min))
}

func sqrt_approx(x f64) f64 {
    if x < 0.0 {
        return 0.0
    }
    if x == 0.0 {
        return 0.0
    }
    result := x
    for i := 0; i < 10; i++ {
        result = (result + x/result) * 0.5
    }
    return result
}

func pow_approx(x f64, exp f64) f64 {
    if x <= 0.0 {
        return 1.0
    }
    return exp_approx(exp * ln_approx(x))
}

func exp_approx(x f64) f64 {
    if x > 100.0 {
        return 1e10
    }
    if x < -100.0 {
        return 1e-10
    }
    result := 1.0
    term := 1.0
    for i := 1; i <= 20; i++ {
        term = term * x / f64(i)
        result = result + term
    }
    return result
}

func ln_approx(x f64) f64 {
    if x <= 0.0 {
        return -100.0
    }
    if x == 1.0 {
        return 0.0
    }
    if x > 0.0 && x <= 2.0 {
        z := (x - 1.0) / (x + 1.0)
        result := 0.0
        term := z
        z_squared := z * z
        for i := 0; i < 20; i++ {
            result = result + term / f64(2*i + 1)
            term = term * z_squared
        }
        return 2.0 * result
    } else {
        exp := 0.0
        y := x
        for y > 2.0 {
            y = y / 2.0
            exp = exp + 1.0
        }
        for y < 1.0 {
            y = y * 2.0
            exp = exp - 1.0
        }
        return ln_approx(y) + exp*0.693147180559945
    }
}

func cos_approx(x f64) f64 {
    x = x - 2.0*3.14159265*i64(x/(2.0*3.14159265))
    result := 1.0
    term := 1.0
    for i := 1; i <= 20; i++ {
        term = term * (-x*x) / f64(2*i*(2*i-1))
        result = result + term
        if term < 1e-10 && term > -1e-10 {
            break
        }
    }
    return result
}

func sin_approx(x f64) f64 {
    x = x - 2.0*3.14159265*i64(x/(2.0*3.14159265))
    result := x
    term := x
    for i := 1; i <= 20; i++ {
        term = term * (-x*x) / f64((2*i+1)*(2*i))
        result = result + term
        if term < 1e-10 && term > -1e-10 {
            break
        }
    }
    return result
}

