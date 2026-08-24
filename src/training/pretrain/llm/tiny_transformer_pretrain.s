package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_read_text_file, runtime_run_command_output}
use std.conv.parse_int_default as parse_int
extern "intrinsic" func __host_write_text_file(string path, string content) int

func runtime_write_text_file(string path, string content) () {
    _ = __host_write_text_file(path, content)
}

struct train_cache {
    []float x
    []float q
    []float k
    []float v
    []float attention
    []float context
    []float probabilities
    float loss
}

struct adamw_state {
    []float params
    []float first_moment
    []float second_moment
    int step
    float beta1_power
    float beta2_power
    float last_loss
}

func zeros(int n) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = 0.0
        i = i + 1
    }
    out
}

func initial_parameters(int vocab_size, int hidden_size) []float {
    int embedding_count = vocab_size * hidden_size
    int matrix_count = hidden_size * hidden_size
    int lm_head_count = hidden_size * vocab_size
    int count = embedding_count + matrix_count * 3 + lm_head_count
    []float out = zeros(count)
    int i = 0
    while i < count {
        int centered = (i * 37 + 17) - ((i * 37 + 17) / 23) * 23 - 11
        out[i] = (centered as float) * 0.007
        i = i + 1
    }
    out
}

func embedding_offset() int {
    0
}

func q_offset(int vocab_size, int hidden_size) int {
    vocab_size * hidden_size
}

func k_offset(int vocab_size, int hidden_size) int {
    q_offset(vocab_size, hidden_size) + hidden_size * hidden_size
}

func v_offset(int vocab_size, int hidden_size) int {
    k_offset(vocab_size, hidden_size) + hidden_size * hidden_size
}

func lm_head_offset(int vocab_size, int hidden_size) int {
    v_offset(vocab_size, hidden_size) + hidden_size * hidden_size
}

func exp_approx(float x) float {
    float value = x
    if value > 12.0 {
        value = 12.0
    }
    if value < -12.0 {
        value = -12.0
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    while i <= 24 {
        term = term * value / (i as float)
        result = result + term
        i = i + 1
    }
    if result < 0.0000001 {
        return 0.0000001
    }
    result
}

func log_approx(float x) float {
    if x <= 0.0 {
        return -100.0
    }
    float scaled = x
    int exponent = 0
    while scaled > 2.0 {
        scaled = scaled * 0.5
        exponent = exponent + 1
    }
    while scaled < 0.5 {
        scaled = scaled * 2.0
        exponent = exponent - 1
    }
    float z = (scaled - 1.0) / (scaled + 1.0)
    float z2 = z * z
    float power = z
    float series = 0.0
    int denominator = 1
    int i = 0
    while i < 18 {
        series = series + power / (denominator as float)
        power = power * z2
        denominator = denominator + 2
        i = i + 1
    }
    2.0 * series + (exponent as float) * 0.6931471805599453
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float result = 1.0
    if x > 1.0 {
        result = x
    }
    int i = 0
    while i < 24 {
        result = 0.5 * (result + x / result)
        i = i + 1
    }
    result
}

func forward(
    []float params,
    []int inputs,
    []int targets,
    int vocab_size,
    int hidden_size
) train_cache {
    int seq_len = len(inputs)
    []float x = zeros(seq_len * hidden_size)
    []float q = zeros(seq_len * hidden_size)
    []float k = zeros(seq_len * hidden_size)
    []float v = zeros(seq_len * hidden_size)
    []float attention = zeros(seq_len * seq_len)
    []float context = zeros(seq_len * hidden_size)
    []float probabilities = zeros(seq_len * vocab_size)
    int t = 0
    while t < seq_len {
        int h = 0
        while h < hidden_size {
            x[t * hidden_size + h] = params[embedding_offset() + inputs[t] * hidden_size + h]
            h = h + 1
        }
        t = t + 1
    }
    t = 0
    while t < seq_len {
        int o = 0
        while o < hidden_size {
            float q_value = 0.0
            float k_value = 0.0
            float v_value = 0.0
            int i = 0
            while i < hidden_size {
                float input_value = x[t * hidden_size + i]
                q_value = q_value + input_value * params[q_offset(vocab_size, hidden_size) + i * hidden_size + o]
                k_value = k_value + input_value * params[k_offset(vocab_size, hidden_size) + i * hidden_size + o]
                v_value = v_value + input_value * params[v_offset(vocab_size, hidden_size) + i * hidden_size + o]
                i = i + 1
            }
            q[t * hidden_size + o] = q_value
            k[t * hidden_size + o] = k_value
            v[t * hidden_size + o] = v_value
            o = o + 1
        }
        t = t + 1
    }
    float scale = 1.0 / sqrt_approx(hidden_size as float)
    t = 0
    while t < seq_len {
        []float scores = zeros(seq_len)
        float max_score = -1000000.0
        int s = 0
        while s <= t {
            float score = 0.0
            int h = 0
            while h < hidden_size {
                score = score + q[t * hidden_size + h] * k[s * hidden_size + h]
                h = h + 1
            }
            scores[s] = score * scale
            if scores[s] > max_score {
                max_score = scores[s]
            }
            s = s + 1
        }
        float normalizer = 0.0
        s = 0
        while s <= t {
            scores[s] = exp_approx(scores[s] - max_score)
            normalizer = normalizer + scores[s]
            s = s + 1
        }
        s = 0
        while s <= t {
            float probability = scores[s] / normalizer
            attention[t * seq_len + s] = probability
            int h = 0
            while h < hidden_size {
                context[t * hidden_size + h] = context[t * hidden_size + h] + probability * v[s * hidden_size + h]
                h = h + 1
            }
            s = s + 1
        }
        t = t + 1
    }
    float loss = 0.0
    t = 0
    while t < seq_len {
        []float logits = zeros(vocab_size)
        float max_logit = -1000000.0
        int token = 0
        while token < vocab_size {
            float logit = 0.0
            int h = 0
            while h < hidden_size {
                logit = logit + context[t * hidden_size + h] * params[lm_head_offset(vocab_size, hidden_size) + h * vocab_size + token]
                h = h + 1
            }
            logits[token] = logit
            if logit > max_logit {
                max_logit = logit
            }
            token = token + 1
        }
        float normalizer = 0.0
        token = 0
        while token < vocab_size {
            logits[token] = exp_approx(logits[token] - max_logit)
            normalizer = normalizer + logits[token]
            token = token + 1
        }
        token = 0
        while token < vocab_size {
            probabilities[t * vocab_size + token] = logits[token] / normalizer
            token = token + 1
        }
        loss = loss - log_approx(probabilities[t * vocab_size + targets[t]] + 0.00000001)
        t = t + 1
    }
    train_cache {
        x: x,
        q: q,
        k: k,
        v: v,
        attention: attention,
        context: context,
        probabilities: probabilities,
        loss: loss / (seq_len as float),
    }
}

func backward(
    []float params,
    train_cache cache,
    []int inputs,
    []int targets,
    int vocab_size,
    int hidden_size
) []float {
    int seq_len = len(inputs)
    []float grads = zeros(len(params))
    []float d_context = zeros(seq_len * hidden_size)
    []float d_q = zeros(seq_len * hidden_size)
    []float d_k = zeros(seq_len * hidden_size)
    []float d_v = zeros(seq_len * hidden_size)
    []float d_x = zeros(seq_len * hidden_size)
    int t = 0
    while t < seq_len {
        int token = 0
        while token < vocab_size {
            float d_logit = cache.probabilities[t * vocab_size + token]
            if token == targets[t] {
                d_logit = d_logit - 1.0
            }
            d_logit = d_logit / (seq_len as float)
            int h = 0
            while h < hidden_size {
                int lm_index = lm_head_offset(vocab_size, hidden_size) + h * vocab_size + token
                grads[lm_index] = grads[lm_index] + cache.context[t * hidden_size + h] * d_logit
                d_context[t * hidden_size + h] = d_context[t * hidden_size + h] + params[lm_index] * d_logit
                h = h + 1
            }
            token = token + 1
        }
        t = t + 1
    }
    float scale = 1.0 / sqrt_approx(hidden_size as float)
    t = 0
    while t < seq_len {
        []float d_attention = zeros(seq_len)
        int s = 0
        while s <= t {
            int h = 0
            while h < hidden_size {
                d_v[s * hidden_size + h] = d_v[s * hidden_size + h] +
                    cache.attention[t * seq_len + s] * d_context[t * hidden_size + h]
                d_attention[s] = d_attention[s] +
                    d_context[t * hidden_size + h] * cache.v[s * hidden_size + h]
                h = h + 1
            }
            s = s + 1
        }
        float weighted = 0.0
        s = 0
        while s <= t {
            weighted = weighted + cache.attention[t * seq_len + s] * d_attention[s]
            s = s + 1
        }
        s = 0
        while s <= t {
            float d_score = cache.attention[t * seq_len + s] * (d_attention[s] - weighted)
            int h = 0
            while h < hidden_size {
                d_q[t * hidden_size + h] = d_q[t * hidden_size + h] +
                    d_score * cache.k[s * hidden_size + h] * scale
                d_k[s * hidden_size + h] = d_k[s * hidden_size + h] +
                    d_score * cache.q[t * hidden_size + h] * scale
                h = h + 1
            }
            s = s + 1
        }
        t = t + 1
    }
    t = 0
    while t < seq_len {
        int i = 0
        while i < hidden_size {
            int o = 0
            while o < hidden_size {
                int q_index = q_offset(vocab_size, hidden_size) + i * hidden_size + o
                int k_index = k_offset(vocab_size, hidden_size) + i * hidden_size + o
                int v_index = v_offset(vocab_size, hidden_size) + i * hidden_size + o
                float input_value = cache.x[t * hidden_size + i]
                grads[q_index] = grads[q_index] + input_value * d_q[t * hidden_size + o]
                grads[k_index] = grads[k_index] + input_value * d_k[t * hidden_size + o]
                grads[v_index] = grads[v_index] + input_value * d_v[t * hidden_size + o]
                d_x[t * hidden_size + i] = d_x[t * hidden_size + i] +
                    params[q_index] * d_q[t * hidden_size + o] +
                    params[k_index] * d_k[t * hidden_size + o] +
                    params[v_index] * d_v[t * hidden_size + o]
                o = o + 1
            }
            int embedding_index = embedding_offset() + inputs[t] * hidden_size + i
            grads[embedding_index] = grads[embedding_index] + d_x[t * hidden_size + i]
            i = i + 1
        }
        t = t + 1
    }
    grads
}

func adamw_update(adamw_state state, []float grads, float loss, float learning_rate, float weight_decay) adamw_state {
    float beta1 = 0.9
    float beta2 = 0.999
    float beta1_power = state.beta1_power * beta1
    float beta2_power = state.beta2_power * beta2
    []float params = zeros(len(state.params))
    []float first = zeros(len(state.params))
    []float second = zeros(len(state.params))
    int i = 0
    while i < len(state.params) {
        first[i] = beta1 * state.first_moment[i] + (1.0 - beta1) * grads[i]
        second[i] = beta2 * state.second_moment[i] + (1.0 - beta2) * grads[i] * grads[i]
        float first_hat = first[i] / (1.0 - beta1_power)
        float second_hat = second[i] / (1.0 - beta2_power)
        params[i] = state.params[i] -
            learning_rate * (first_hat / (sqrt_approx(second_hat) + 0.00000001) + weight_decay * state.params[i])
        i = i + 1
    }
    adamw_state {
        params: params,
        first_moment: first,
        second_moment: second,
        step: state.step + 1,
        beta1_power: beta1_power,
        beta2_power: beta2_power,
        last_loss: loss,
    }
}

func gradient_relative_error(
    []float params,
    []float analytic,
    []int inputs,
    []int targets,
    int vocab_size,
    int hidden_size
) float {
    float epsilon = 0.001
    float worst = 0.0
    int i = 0
    while i < len(params) {
        []float plus = copy_floats(params)
        []float minus = copy_floats(params)
        plus[i] = plus[i] + epsilon
        minus[i] = minus[i] - epsilon
        float plus_loss = forward(plus, inputs, targets, vocab_size, hidden_size).loss
        float minus_loss = forward(minus, inputs, targets, vocab_size, hidden_size).loss
        float numerical = (plus_loss - minus_loss) / (2.0 * epsilon)
        float denominator = abs_float(numerical) + abs_float(analytic[i]) + 0.0001
        float error = abs_float(numerical - analytic[i]) / denominator
        if error > worst {
            worst = error
        }
        i = i + 1
    }
    worst
}

func save_checkpoint(string path, adamw_state state, float loss) {
    string text = "version=1\n"
    text = text + "step=" + int_to_string(state.step) + "\n"
    text = text + "loss=" + float_to_string(loss, 9) + "\n"
    text = text + "beta1_power=" + float_to_string(state.beta1_power, 12) + "\n"
    text = text + "beta2_power=" + float_to_string(state.beta2_power, 12) + "\n"
    text = text + "params=" + floats_to_string(state.params) + "\n"
    text = text + "first_moment=" + floats_to_string(state.first_moment) + "\n"
    text = text + "second_moment=" + floats_to_string(state.second_moment) + "\n"
    runtime_write_text_file(path, text)
}

func load_checkpoint(string path, []float fallback_params) adamw_state {
    if !runtime_file_exists(path) {
        return adamw_state {
            params: fallback_params,
            first_moment: zeros(len(fallback_params)),
            second_moment: zeros(len(fallback_params)),
            step: 0,
            beta1_power: 1.0,
            beta2_power: 1.0,
            last_loss: 0.0,
        }
    }
    string text = runtime_read_text_file(path)
    []float params = parse_float_list(value_for_key(text, "params"), len(fallback_params))
    []float first = parse_float_list(value_for_key(text, "first_moment"), len(fallback_params))
    []float second = parse_float_list(value_for_key(text, "second_moment"), len(fallback_params))
    if len(params) != len(fallback_params) || len(first) != len(fallback_params) || len(second) != len(fallback_params) {
        println("[tiny-s] checkpoint topology mismatch; starting fresh")
        return adamw_state {
            params: fallback_params,
            first_moment: zeros(len(fallback_params)),
            second_moment: zeros(len(fallback_params)),
            step: 0,
            beta1_power: 1.0,
            beta2_power: 1.0,
            last_loss: 0.0,
        }
    }
    adamw_state {
        params: params,
        first_moment: first,
        second_moment: second,
        step: parse_int(value_for_key(text, "step"), 0),
        beta1_power: parse_float(value_for_key(text, "beta1_power")),
        beta2_power: parse_float(value_for_key(text, "beta2_power")),
        last_loss: parse_float(value_for_key(text, "loss")),
    }
}

func main() {
    int vocab_size = 4
    int hidden_size = 2
    []int inputs = [0, 1, 2]
    []int targets = [1, 2, 3]
    int max_steps = parse_int(runtime_env_get("NEURX_TINY_STEPS", "120"), 120)
    float learning_rate = parse_float(runtime_env_get("NEURX_TINY_LR", "0.005"))
    float weight_decay = parse_float(runtime_env_get("NEURX_TINY_WEIGHT_DECAY", "0.001"))
    string output_dir = runtime_env_get("NEURX_TINY_OUTPUT_DIR", "artifact/checkpoints/tiny_s_transformer")
    string checkpoint_path = output_dir + "/checkpoint.sckpt"
    bool resume = parse_int(runtime_env_get("NEURX_TINY_RESUME", "1"), 1) > 0
    _ = runtime_run_command_output("mkdir -p " + shell_escape(output_dir))
    []float initial = initial_parameters(vocab_size, hidden_size)
    adamw_state state = load_checkpoint(checkpoint_path, initial)
    if !resume {
        state = adamw_state {
            params: initial,
            first_moment: zeros(len(initial)),
            second_moment: zeros(len(initial)),
            step: 0,
            beta1_power: 1.0,
            beta2_power: 1.0,
            last_loss: 0.0,
        }
    }
    train_cache initial_cache = forward(state.params, inputs, targets, vocab_size, hidden_size)
    []float initial_grads = backward(state.params, initial_cache, inputs, targets, vocab_size, hidden_size)
    float gradient_error = gradient_relative_error(state.params, initial_grads, inputs, targets, vocab_size, hidden_size)
    println("[tiny-s] gradient_relative_error=" + float_to_string(gradient_error, 8))
    if gradient_error > 0.08 {
        println("[tiny-s] ERROR: analytical backward failed numerical reference")
        return 2
    }
    float start_loss = initial_cache.loss
    while state.step < max_steps {
        train_cache cache = forward(state.params, inputs, targets, vocab_size, hidden_size)
        []float grads = backward(state.params, cache, inputs, targets, vocab_size, hidden_size)
        state = adamw_update(state, grads, cache.loss, learning_rate, weight_decay)
        if state.step == 1 || state.step == max_steps || state.step - (state.step / 20) * 20 == 0 {
            println("[tiny-s] step=" + int_to_string(state.step) + " loss=" + float_to_string(cache.loss, 8))
        }
    }
    train_cache final_cache = forward(state.params, inputs, targets, vocab_size, hidden_size)
    save_checkpoint(checkpoint_path, state, final_cache.loss)
    runtime_write_text_file(output_dir + "/latest_checkpoint.txt", checkpoint_path + "\n")
    println("[tiny-s] start_loss=" + float_to_string(start_loss, 8) + " final_loss=" + float_to_string(final_cache.loss, 8))
    println("[tiny-s] checkpoint=" + checkpoint_path)
    if state.step > 0 && final_cache.loss >= start_loss && !resume {
        println("[tiny-s] ERROR: loss did not decrease")
        return 3
    }
    0
}

func copy_floats([]float values) []float {
    []float out = zeros(len(values))
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func abs_float(float value) float {
    if value < 0.0 {
        return 0.0 - value
    }
    value
}

func floats_to_string([]float values) string {
    string out = ""
    int i = 0
    while i < len(values) {
        if i > 0 {
            out = out + ","
        }
        out = out + float_to_string(values[i], 12)
        i = i + 1
    }
    out
}

func parse_float_list(string text, int expected) []float {
    []float out = zeros(expected)
    int count = 0
    int start = 0
    int i = 0
    while i <= len(text) {
        if i == len(text) || text[i] == 44 {
            string item = substring(text, start, i)
            if len(item) > 0 && count < expected {
                out[count] = parse_float(item)
                count = count + 1
            }
            start = i + 1
        }
        i = i + 1
    }
    if count != expected {
        return []
    }
    out
}

func value_for_key(string text, string key) string {
    string prefix = key + "="
    int line_start = 0
    int i = 0
    while i <= len(text) {
        if i == len(text) || text[i] == 10 {
            string line = substring(text, line_start, i)
            if starts_with(line, prefix) {
                return substring(line, len(prefix), len(line))
            }
            line_start = i + 1
        }
        i = i + 1
    }
    ""
}

func starts_with(string text, string prefix) bool {
    if len(text) < len(prefix) {
        return false
    }
    int i = 0
    while i < len(prefix) {
        if text[i] != prefix[i] {
            return false
        }
        i = i + 1
    }
    true
}

func substring(string text, int start, int end) string {
    string out = ""
    int i = start
    while i < end && i < len(text) {
        out = out + string_char(text[i])
        i = i + 1
    }
    out
}

func parse_float(string text) float {
    if len(text) == 0 {
        return 0.0
    }
    float value = 0.0
    float fraction_scale = 1.0
    bool fraction = false
    bool negative = false
    int i = 0
    if text[0] == 45 {
        negative = true
        i = 1
    }
    while i < len(text) {
        if text[i] == 46 {
            fraction = true
        } else if text[i] >= 48 && text[i] <= 57 {
            if fraction {
                fraction_scale = fraction_scale * 10.0
                value = value + ((text[i] - 48) as float) / fraction_scale
            } else {
                value = value * 10.0 + ((text[i] - 48) as float)
            }
        }
        i = i + 1
    }
    if negative {
        return 0.0 - value
    }
    value
}

func int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    int current = value
    bool negative = current < 0
    if negative {
        current = 0 - current
    }
    string out = ""
    while current > 0 {
        int digit = current - (current / 10) * 10
        out = string_char(digit + 48) + out
        current = current / 10
    }
    if negative {
        out = "-" + out
    }
    out
}

func float_to_string(float value, int decimals) string {
    float current = value
    string out = ""
    if current < 0.0 {
        out = "-"
        current = 0.0 - current
    }
    int whole = 0
    while current >= 1.0 && whole < 1000000 {
        current = current - 1.0
        whole = whole + 1
    }
    out = out + int_to_string(whole) + "."
    int i = 0
    while i < decimals {
        current = current * 10.0
        int digit = 0
        while current >= 1.0 && digit < 9 {
            current = current - 1.0
            digit = digit + 1
        }
        out = out + string_char(digit + 48)
        i = i + 1
    }
    out
}

func string_char(int code) string {
    string(code)
}

func shell_escape(string text) string {
    string out = "'"
    int i = 0
    while i < len(text) {
        if text[i] == 39 {
            out = out + "'\"'\"'"
        } else {
            out = out + string_char(text[i])
        }
        i = i + 1
    }
    out + "'"
}
