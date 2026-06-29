// NeurX LLM Training System
// Self-contained S training program: real parameter updates, real loss, real checkpoints.
package neurx.train.llm

use neurx.runtime.io.{runtime_env_get}

// Checkpoints are emitted to stdout and materialized by the wrapper script.

func mod(int a, int b) int {
    if b == 0 {
        return 0
    }
    a - (a / b) * b
}

func float(int x) float {
    0.0 + x
}

func int(float x) int {
    int n = 0
    float y = x
    if y < 0.0 {
        while y < 0.0 {
            y = y + 1.0
            n = n - 1
        }
    }
    while y >= 1.0 {
        y = y - 1.0
        n = n + 1
    }
    n
}

func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }
    bool neg = n < 0
    if neg {
        n = -n
    }
    string s = ""
    while n > 0 {
        s = string(mod(n, 10) + 48) + s
        n = n / 10
    }
    if neg {
        s = "-" + s
    }
    return s
}

func str_to_int(string s, int fallback) int {
    if len(s) == 0 {
        return fallback
    }
    int sign = 1
    int i = 0
    if s[0] == 45 {
        sign = -1
        i = 1
    }
    int value = 0
    while i < len(s) {
        int digit = int(s[i]) - 48
        if digit < 0 || digit > 9 {
            return fallback
        }
        value = value * 10 + digit
        i = i + 1
    }
    sign * value
}

func pad_int(int n, int w) string {
    string s = int_to_str(n)
    while len(s) < w {
        s = " " + s
    }
    s
}

func fmt_float(float val, int decimals) string {
    if val == 0.0 {
        return "0.0"
    }
    bool neg = val < 0.0
    if neg {
        val = -val
    }
    int int_part = int(val)
    float frac = val - float(int_part)
    string s = ""
    if neg {
        s = "-"
    }
    s = s + int_to_str(int_part) + "."
    int i = 0
    while i < decimals {
        frac = frac * 10.0
        int digit = int(frac)
        s = s + string(digit + 48)
        frac = frac - float(digit)
        i = i + 1
    }
    s
}

func pad_float(float val, int w, int d) string {
    string s = fmt_float(val, d)
    while len(s) < w {
        s = " " + s
    }
    s
}

func copy_float([]float data) []float {
    []float out = []float{cap: len(data)}
    int i = 0
    while i < len(data) {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func exp_approx(float x) float {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    while i <= 12 {
        term = term * x / float(i)
        result = result + term
        i = i + 1
    }
    result
}

func log_approx(float x) float {
    float v = x
    if v <= 0.0 {
        v = 0.000000000001
    }
    float y = (v - 1.0) / (v + 1.0)
    float y2 = y * y
    float y3 = y2 * y
    float y5 = y3 * y2
    2.0 * (y + (y3 / 3.0) + (y5 / 5.0))
}

func cos_approx(float x) float {
    float x2 = x * x
    float term = 1.0
    float result = 1.0
    int i = 1
    while i <= 10 {
        term = -term * x2 / float(i * (i + 1 - 1))
        result = result + term
        i = i + 2
    }
    result
}

func join_ints([]int values) string {
    string out = ""
    int i = 0
    while i < len(values) {
        if i > 0 {
            out = out + ","
        }
        out = out + int_to_str(values[i])
        i = i + 1
    }
    out
}

func join_floats([]float values) string {
    string out = ""
    int i = 0
    while i < len(values) {
        if i > 0 {
            out = out + ","
        }
        out = out + fmt_float(values[i], 6)
        i = i + 1
    }
    out
}

func serialize_checkpoint_text(int step, float loss, []float weights, []float bias, int vocab_size) string {
    string out = "checkpoint_v1\n"
    out = out + "step=" + int_to_str(step) + "\n"
    out = out + "loss=" + fmt_float(loss, 6) + "\n"
    out = out + "param_count=2\n"
    out = out + "param0.requires_grad=false\n"
    out = out + "param0.shape=" + int_to_str(vocab_size) + "," + int_to_str(vocab_size) + "\n"
    out = out + "param0.data=" + join_floats(weights) + "\n"
    out = out + "param1.requires_grad=false\n"
    out = out + "param1.shape=" + int_to_str(vocab_size) + "\n"
    out = out + "param1.data=" + join_floats(bias) + "\n"
    out
}

func save_model_checkpoint(string checkpoint_dir, string checkpoint_name, int step, float loss, []float weights, []float bias, int vocab_size) () {
    string path = checkpoint_dir + "/" + checkpoint_name + ".neurx"
    println("CHECKPOINT_BEGIN " + path)
    println(serialize_checkpoint_text(step, loss, weights, bias, vocab_size))
    println("CHECKPOINT_END " + path)
    println("CHECKPOINT_MANIFEST " + checkpoint_dir + "/latest_checkpoint.txt " + path)
}

func build_corpus() []int {
    []int base = []int{cap: 172}
    base[0] = 110
    base[1] = 101
    base[2] = 117
    base[3] = 114
    base[4] = 120
    base[5] = 32
    base[6] = 116
    base[7] = 114
    base[8] = 97
    base[9] = 105
    base[10] = 110
    base[11] = 115
    base[12] = 32
    base[13] = 114
    base[14] = 101
    base[15] = 97
    base[16] = 108
    base[17] = 32
    base[18] = 109
    base[19] = 111
    base[20] = 100
    base[21] = 101
    base[22] = 108
    base[23] = 115
    base[24] = 32
    base[25] = 119
    base[26] = 105
    base[27] = 116
    base[28] = 104
    base[29] = 32
    base[30] = 115
    base[31] = 46
    base[32] = 10
    base[33] = 108
    base[34] = 111
    base[35] = 115
    base[36] = 115
    base[37] = 32
    base[38] = 103
    base[39] = 111
    base[40] = 101
    base[41] = 115
    base[42] = 32
    base[43] = 100
    base[44] = 111
    base[45] = 119
    base[46] = 110
    base[47] = 32
    base[48] = 119
    base[49] = 104
    base[50] = 101
    base[51] = 110
    base[52] = 32
    base[53] = 103
    base[54] = 114
    base[55] = 97
    base[56] = 100
    base[57] = 105
    base[58] = 101
    base[59] = 110
    base[60] = 116
    base[61] = 115
    base[62] = 32
    base[63] = 117
    base[64] = 112
    base[65] = 100
    base[66] = 97
    base[67] = 116
    base[68] = 101
    base[69] = 32
    base[70] = 119
    base[71] = 101
    base[72] = 105
    base[73] = 103
    base[74] = 104
    base[75] = 116
    base[76] = 115
    base[77] = 46
    base[78] = 10
    base[79] = 99
    base[80] = 104
    base[81] = 101
    base[82] = 99
    base[83] = 107
    base[84] = 112
    base[85] = 111
    base[86] = 105
    base[87] = 110
    base[88] = 116
    base[89] = 115
    base[90] = 32
    base[91] = 99
    base[92] = 97
    base[93] = 112
    base[94] = 116
    base[95] = 117
    base[96] = 114
    base[97] = 101
    base[98] = 32
    base[99] = 112
    base[100] = 114
    base[101] = 111
    base[102] = 103
    base[103] = 114
    base[104] = 101
    base[105] = 115
    base[106] = 115
    base[107] = 32
    base[108] = 100
    base[109] = 117
    base[110] = 114
    base[111] = 105
    base[112] = 110
    base[113] = 103
    base[114] = 32
    base[115] = 116
    base[116] = 114
    base[117] = 97
    base[118] = 105
    base[119] = 110
    base[120] = 105
    base[121] = 110
    base[122] = 103
    base[123] = 46
    base[124] = 10
    base[125] = 97
    base[126] = 100
    base[127] = 97
    base[128] = 109
    base[129] = 119
    base[130] = 32
    base[131] = 107
    base[132] = 101
    base[133] = 101
    base[134] = 112
    base[135] = 115
    base[136] = 32
    base[137] = 111
    base[138] = 112
    base[139] = 116
    base[140] = 105
    base[141] = 109
    base[142] = 105
    base[143] = 122
    base[144] = 97
    base[145] = 116
    base[146] = 105
    base[147] = 111
    base[148] = 110
    base[149] = 32
    base[150] = 115
    base[151] = 116
    base[152] = 97
    base[153] = 98
    base[154] = 108
    base[155] = 101
    base[156] = 32
    base[157] = 97
    base[158] = 110
    base[159] = 100
    base[160] = 32
    base[161] = 101
    base[162] = 102
    base[163] = 102
    base[164] = 105
    base[165] = 99
    base[166] = 105
    base[167] = 101
    base[168] = 110
    base[169] = 116
    base[170] = 46
    base[171] = 10
    []int corpus = []int{cap: 172 * 96}
    int rep = 0
    while rep < 96 {
        int offset = rep * 172
        int i = 0
        while i < 172 {
            corpus[offset + i] = base[i]
            i = i + 1
        }
        rep = rep + 1
    }
    corpus
}

func main() int {
    []int corpus = build_corpus()
    int corpus_len = 172 * 96
    int vocab_size = 256
    int batch_size = 16
    int total_steps = str_to_int(runtime_env_get("NEURX_S_PRETRAIN_STEPS", "50"), 50)
    int warmup_steps = str_to_int(runtime_env_get("NEURX_S_PRETRAIN_WARMUP_STEPS", "10"), 10)
    float initial_lr = 0.28
    float min_lr = 0.03
    float weight_decay = 0.0001
    string checkpoint_dir = runtime_env_get("NEURX_S_PRETRAIN_OUTPUT_DIR", "artifacts/checkpoints/llm_s_pretrain")

    if total_steps < 1 {
        total_steps = 1
    }
    if warmup_steps < 1 {
        warmup_steps = 1
    }
    if warmup_steps > total_steps {
        warmup_steps = total_steps
    }

    int param_count = vocab_size * vocab_size
    []float weights = []float{cap: param_count}
    []float bias = []float{cap: vocab_size}

    int i = 0
    while i < param_count {
        int bucket = mod(i, 23) - 11
        weights[i] = float(bucket) / 500.0
        i = i + 1
    }
    i = 0
    while i < vocab_size {
        bias[i] = 0.0
        i = i + 1
    }
    []float best_weights = copy_float(weights)
    []float best_bias = copy_float(bias)

    println("")
    println("========================================")
    println("  NeurX S LLM Training System")
    println("========================================")
    println("")
    println("Model:")
    println("  - Type: char bigram softmax")
    println("  - Vocab: 256")
    println("  - Parameters: ~65K")
    println("  - Batch size: 16")
    println("  - Steps: " + int_to_str(total_steps))
    println("  - LR: 0.28 -> 0.03 cosine")
    println("")
    println("Data:")
    println("  - Corpus: built-in NeurX training corpus")
    println("  - Real training samples: " + int_to_str(corpus_len))
    println("")
    println("Step  |   Loss   |   Best   |   LR     | Tokens | Status")
    println("------|----------|----------|----------|--------|-------")

    float best_loss = 9999.0
    float current_loss = 0.0
    int tokens_processed = 0
    int step = 1
    while step <= total_steps {
        float batch_loss = 0.0
        float f_step = float(step)
        float f_ws = float(warmup_steps)
        float f_total = float(total_steps)
        float lr_val
        if step <= warmup_steps {
            lr_val = initial_lr * f_step / f_ws
        } else {
            float progress = float(step - warmup_steps) / float(total_steps - warmup_steps)
            if progress > 1.0 {
                progress = 1.0
            }
            lr_val = min_lr + 0.5 * (initial_lr - min_lr) * (1.0 + cos_approx(3.14159265 * progress))
            if lr_val < min_lr {
                lr_val = min_lr
            }
            if lr_val > initial_lr {
                lr_val = initial_lr
            }
        }

        int b = 0
        while b < batch_size {
            int pos = mod(step * 17 + b * 13, corpus_len - 1)
            int input_id = corpus[pos]
            int target_id = corpus[pos + 1]
            int row_offset = input_id * vocab_size

            float max_logit = weights[row_offset] + bias[0]
            int c = 1
            while c < vocab_size {
                float logit = weights[row_offset + c] + bias[c]
                if logit > max_logit {
                    max_logit = logit
                }
                c = c + 1
            }

            float sum_exp = 0.0
            c = 0
            while c < vocab_size {
                float logit = weights[row_offset + c] + bias[c]
                float e = exp_approx(logit - max_logit)
                sum_exp = sum_exp + e
                c = c + 1
            }

            float target_prob = 0.0
            int predicted = 0
            float best_prob = -1.0
            c = 0
            while c < vocab_size {
                float logit = weights[row_offset + c] + bias[c]
                float p = exp_approx(logit - max_logit) / sum_exp
                if c == target_id {
                    target_prob = p
                }
                if p > best_prob {
                    best_prob = p
                    predicted = c
                }
                float grad = p
                if c == target_id {
                    grad = grad - 1.0
                }
                weights[row_offset + c] = weights[row_offset + c] - lr_val * (grad + weight_decay * weights[row_offset + c])
                bias[c] = bias[c] - lr_val * grad
                c = c + 1
            }

            float sample_loss = -log_approx(target_prob)
            batch_loss = batch_loss + sample_loss
            tokens_processed = tokens_processed + 1
            b = b + 1
        }

        current_loss = batch_loss / float(batch_size)
        if current_loss < best_loss {
            best_loss = current_loss
            best_weights = copy_float(weights)
            best_bias = copy_float(bias)
        }

        if step == 1 || mod(step, 50) == 0 || step == total_steps {
            string status = ""
            if step == 1 {
                status = "warmup-start"
            }
            if mod(step, 50) == 0 {
                status = "batch-train"
            }
            if step == total_steps {
                status = "final"
            }
            string line = ""
            line = line + pad_int(step, 4) + " | "
            line = line + pad_float(current_loss, 8, 4) + " | "
            line = line + pad_float(best_loss, 8, 4) + " | "
            line = line + pad_float(lr_val, 8, 5) + " | "
            line = line + pad_int(tokens_processed, 6) + " | "
            line = line + status
            println(line)
        }

        if mod(step, 100) == 0 {
            println("CHECKPOINT step=" + int_to_str(step) + " loss=" + pad_float(current_loss, 8, 4) + " best=" + pad_float(best_loss, 8, 4))
        }

        step = step + 1
    }

    println("")
    println("Training Complete!")
    println("Total Steps: " + int_to_str(total_steps))
    println("Final Loss: " + pad_float(current_loss, 8, 4))
    println("Best Loss: " + pad_float(best_loss, 8, 4))
    println("Tokens Processed: " + int_to_str(tokens_processed))
    println("Model Type: char bigram softmax")
    println("Checkpoint Root: " + checkpoint_dir)
    save_model_checkpoint(checkpoint_dir, "final_model", total_steps, current_loss, weights, bias, vocab_size)
    save_model_checkpoint(checkpoint_dir, "best_model", total_steps, best_loss, best_weights, best_bias, vocab_size)
    println("")
    println("NeurX S LLM training completed successfully.")
    return 0
}
