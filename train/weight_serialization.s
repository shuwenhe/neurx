package neurx.train.weight_serialization

// ============================================================================
// GPT Weight Serialization (real disk persistence)
//
// Implements a self-contained, dependency-light on-disk format for the full
// GPT training state: model config, all weight tensors, AdamW optimizer state,
// and training metadata.
//
// Format (text-backed, line oriented). Floats are written in normalized
// scientific notation ("<mantissa>e<exp>") so both large weights and tiny
// optimizer-moment values (~1e-8) round-trip without precision loss that
// would break training resumption.
//
//   NEURXCKPT 1
//   CONFIG name=<..> vocab=<..> n_embd=<..> n_layer=<..> n_head=<..>
//          n_kv_head=<..> ffn=<..> block=<..> rope=<..> bias=<..> tie=<..> act=<..>
//   META step=<..> lr=<..> loss=<..> best=<..> stage=<..> model=<..>
//   TENSOR <name> <length>
//   <f0> <f1> ... <fN-1>
//   ...
//   END
//
// This is the module the older generic checkpoint code was missing: a real
// serializer that operates on the concrete gpt_model / gpt_adamw_state.
// ============================================================================

use neurx.model.llm.gpt.{
    gpt_config, gpt_model, gpt_layer,
    new_gpt_model, gpt_layer_at
}
use neurx.model.llm.gpt_backward.{
    gpt_adamw_state, gpt_layer_adamw, new_gpt_adamw_state
}
use neurx.train.gpt_training_checkpoint.{
    gpt_training_checkpoint, snapshot_gpt_training_state
}
use neurx.runtime.io.{
    runtime_read_text_file, runtime_write_text_file,
    runtime_make_dirs, runtime_file_exists
}

// ============================================================================
// 1. 数值格式化 (无损往返)
// ============================================================================

// 整数 → 字符串
func ser_int(int value) string {
    if value == 0 {
        return "0"
    }
    bool neg = value < 0
    int cur = value
    if neg {
        cur = -cur
    }
    string text = ""
    while cur > 0 {
        int digit = cur - (cur / 10) * 10
        text = string(digit + 48) + text
        cur = cur / 10
    }
    if neg {
        text = "-" + text
    }
    text
}

// 字符串 → 整数
func ser_parse_int(string s) int {
    int i = 0
    int sign = 1
    if len(s) > 0 && s[0] == 45 {
        sign = -1
        i = 1
    }
    int value = 0
    while i < len(s) {
        int c = s[i] - 48
        if c < 0 || c > 9 {
            return sign * value
        }
        value = value * 10 + c
        i = i + 1
    }
    sign * value
}

func ser_abs(float x) float {
    if x < 0.0 {
        return -x
    }
    x
}

func ser_pow10(int exp) float {
    float result = 1.0
    int e = exp
    if e >= 0 {
        while e > 0 {
            result = result * 10.0
            e = e - 1
        }
    } else {
        while e < 0 {
            result = result / 10.0
            e = e + 1
        }
    }
    result
}

// float → 规范化科学计数法字符串 "<mantissa>e<exp>"
// 尾数保留 9 位有效数字 (float32 精确往返所需)
func ser_float(float value) string {
    if value == 0.0 {
        return "0e0"
    }
    bool neg = value < 0.0
    float mag = ser_abs(value)

    // 归一化到 [1, 10)
    int exp = 0
    while mag >= 10.0 {
        mag = mag / 10.0
        exp = exp + 1
    }
    while mag < 1.0 {
        mag = mag * 10.0
        exp = exp - 1
    }

    // 尾数: 1 位整数 + 8 位小数 (共 9 位有效数字)
    // mantissa_int = round(mag * 1e8)
    float scaled = mag * 100000000.0
    int mantissa_int = ser_round_to_int(scaled)

    // 可能因四舍五入进位到 10.000... → 重新归一
    if mantissa_int >= 1000000000 {
        mantissa_int = mantissa_int / 10
        exp = exp + 1
    }

    int lead = mantissa_int / 100000000
    int frac = mantissa_int - lead * 100000000

    string frac_str = ser_int(frac)
    // 补前导零到 8 位
    while len(frac_str) < 8 {
        frac_str = "0" + frac_str
    }

    string out = ser_int(lead) + "." + frac_str + "e" + ser_int(exp)
    if neg {
        out = "-" + out
    }
    out
}

func ser_round_to_int(float x) int {
    // x 已为正
    float y = x + 0.5
    int n = 0
    while y >= 1.0 {
        y = y - 1.0
        n = n + 1
    }
    n
}

// 解析 "<mantissa>e<exp>" → float
func ser_parse_float(string s) float {
    if len(s) == 0 {
        return 0.0
    }
    bool neg = false
    int i = 0
    if s[0] == 45 {
        neg = true
        i = 1
    }

    // 尾数整数部分
    float mantissa = 0.0
    while i < len(s) && s[i] >= 48 && s[i] <= 57 {
        mantissa = mantissa * 10.0 + (s[i] - 48) * 1.0
        i = i + 1
    }
    // 尾数小数部分
    if i < len(s) && s[i] == 46 {
        i = i + 1
        float div = 1.0
        while i < len(s) && s[i] >= 48 && s[i] <= 57 {
            mantissa = mantissa * 10.0 + (s[i] - 48) * 1.0
            div = div * 10.0
            i = i + 1
        }
        mantissa = mantissa / div
    }

    // 指数部分
    int exp = 0
    if i < len(s) && (s[i] == 101 || s[i] == 69) {   // 'e' or 'E'
        i = i + 1
        int esign = 1
        if i < len(s) && s[i] == 45 {
            esign = -1
            i = i + 1
        } else if i < len(s) && s[i] == 43 {
            i = i + 1
        }
        int ev = 0
        while i < len(s) && s[i] >= 48 && s[i] <= 57 {
            ev = ev * 10 + (s[i] - 48)
            i = i + 1
        }
        exp = esign * ev
    }

    float result = mantissa * ser_pow10(exp)
    if neg {
        result = -result
    }
    result
}

// ============================================================================
// 2. 浮点数组序列化
// ============================================================================

// 把一个浮点数组编码为一行空格分隔的 token
func ser_float_array([]float arr) string {
    string line = ""
    int i = 0
    while i < len(arr) {
        if i > 0 {
            line = line + " "
        }
        line = line + ser_float(arr[i])
        i = i + 1
    }
    line
}

// 把一行空格分隔的 token 解析回浮点数组 (已知长度)
func ser_parse_float_array(string line, int length) []float {
    []float arr = []float{cap: length}
    int idx = 0
    int i = 0
    int n = len(line)
    while i < n && idx < length {
        // 跳过空格
        while i < n && line[i] == 32 {
            i = i + 1
        }
        int start = i
        while i < n && line[i] != 32 {
            i = i + 1
        }
        if i > start {
            string token = substring_local(line, start, i)
            arr[idx] = ser_parse_float(token)
            idx = idx + 1
        }
    }
    // 补齐缺失
    while idx < length {
        arr[idx] = 0.0
        idx = idx + 1
    }
    arr
}

func substring_local(string s, int start, int end) string {
    string out = ""
    int i = start
    while i < end && i < len(s) {
        out = out + string(s[i])
        i = i + 1
    }
    out
}

// ============================================================================
// 3. 配置序列化
// ============================================================================

func ser_bool(bool b) string {
    if b {
        return "1"
    }
    "0"
}

func ser_config_line(gpt_config c) string {
    string s = "CONFIG"
    s = s + " name=" + c.name
    s = s + " vocab=" + ser_int(c.vocab_size)
    s = s + " n_embd=" + ser_int(c.n_embd)
    s = s + " n_layer=" + ser_int(c.n_layer)
    s = s + " n_head=" + ser_int(c.n_head)
    s = s + " n_kv_head=" + ser_int(c.n_kv_head)
    s = s + " ffn=" + ser_int(c.ffn_dim)
    s = s + " block=" + ser_int(c.block_size)
    s = s + " rope=" + ser_float(c.rope_base)
    s = s + " bias=" + ser_bool(c.use_bias)
    s = s + " tie=" + ser_bool(c.tie_embeddings)
    s = s + " act=" + c.activation
    s
}

// 从 "key=value" token 中取 value
func ser_kv_value(string token) string {
    int i = 0
    while i < len(token) && token[i] != 61 {   // '='
        i = i + 1
    }
    if i >= len(token) {
        return ""
    }
    substring_local(token, i + 1, len(token))
}

// 把一行按空格切成 token
func ser_split_ws(string line) []string {
    []string out = []string{cap: 32}
    int count = 0
    int i = 0
    int n = len(line)
    while i < n {
        while i < n && line[i] == 32 {
            i = i + 1
        }
        int start = i
        while i < n && line[i] != 32 {
            i = i + 1
        }
        if i > start {
            out[count] = substring_local(line, start, i)
            count = count + 1
        }
    }
    []string trimmed = []string{cap: count}
    int k = 0
    while k < count {
        trimmed[k] = out[k]
        k = k + 1
    }
    trimmed
}

func ser_parse_config(string line) gpt_config {
    []string tokens = ser_split_ws(line)
    gpt_config c = gpt_config {
        name: "loaded",
        vocab_size: 50257,
        n_embd: 768,
        n_layer: 12,
        n_head: 12,
        n_kv_head: 12,
        ffn_dim: 3072,
        block_size: 1024,
        rope_base: 10000.0,
        dropout: 0.0,
        use_bias: true,
        activation: "gelu",
        tie_embeddings: true,
    }
    int i = 1   // 跳过 "CONFIG"
    while i < len(tokens) {
        string tok = tokens[i]
        string val = ser_kv_value(tok)
        if ser_key_is(tok, "name") {
            c.name = val
        } else if ser_key_is(tok, "vocab") {
            c.vocab_size = ser_parse_int(val)
        } else if ser_key_is(tok, "n_embd") {
            c.n_embd = ser_parse_int(val)
        } else if ser_key_is(tok, "n_layer") {
            c.n_layer = ser_parse_int(val)
        } else if ser_key_is(tok, "n_head") {
            c.n_head = ser_parse_int(val)
        } else if ser_key_is(tok, "n_kv_head") {
            c.n_kv_head = ser_parse_int(val)
        } else if ser_key_is(tok, "ffn") {
            c.ffn_dim = ser_parse_int(val)
        } else if ser_key_is(tok, "block") {
            c.block_size = ser_parse_int(val)
        } else if ser_key_is(tok, "rope") {
            c.rope_base = ser_parse_float(val)
        } else if ser_key_is(tok, "bias") {
            c.use_bias = val == "1"
        } else if ser_key_is(tok, "tie") {
            c.tie_embeddings = val == "1"
        } else if ser_key_is(tok, "act") {
            c.activation = val
        }
        i = i + 1
    }
    c
}

func ser_key_is(string token, string key) bool {
    int i = 0
    while i < len(key) && i < len(token) {
        if token[i] != key[i] {
            return false
        }
        i = i + 1
    }
    // key 之后必须是 '='
    if i < len(token) && token[i] == 61 {
        return i == len(key)
    }
    false
}

// ============================================================================
// 4. 完整 checkpoint 保存
// ============================================================================

// 构建 TENSOR 段
func ser_tensor_block(string name, []float arr) string {
    string s = "TENSOR " + name + " " + ser_int(len(arr)) + "\n"
    s = s + ser_float_array(arr) + "\n"
    s
}

// 序列化整个 GPT checkpoint 为文本
func serialize_gpt_checkpoint(gpt_training_checkpoint ckpt) string {
    gpt_model model = ckpt.model
    gpt_adamw_state opt = ckpt.optimizer
    gpt_config cfg = model.config

    string out = "NEURXCKPT 1\n"
    out = out + ser_config_line(cfg) + "\n"

    // META
    string meta = "META"
    meta = meta + " step=" + ser_int(ckpt.global_step)
    meta = meta + " optstep=" + ser_int(opt.step)
    meta = meta + " lr=" + ser_float(ckpt.learning_rate)
    meta = meta + " loss=" + ser_float(ckpt.loss)
    meta = meta + " best=" + ser_float(ckpt.best_loss)
    meta = meta + " stage=" + ckpt.stage_name
    meta = meta + " model=" + ckpt.model_name
    meta = meta + " b1=" + ser_float(opt.beta1)
    meta = meta + " b2=" + ser_float(opt.beta2)
    meta = meta + " eps=" + ser_float(opt.eps)
    meta = meta + " wd=" + ser_float(opt.weight_decay)
    out = out + meta + "\n"

    // 顶层张量
    out = out + ser_tensor_block("wte", model.wte)
    out = out + ser_tensor_block("wpe", model.wpe)
    out = out + ser_tensor_block("lm_head", model.lm_head)
    out = out + ser_tensor_block("final_gamma", model.final_norm.gamma)

    // 优化器顶层动量
    out = out + ser_tensor_block("opt.m_wte", opt.m_wte)
    out = out + ser_tensor_block("opt.v_wte", opt.v_wte)
    out = out + ser_tensor_block("opt.m_wpe", opt.m_wpe)
    out = out + ser_tensor_block("opt.v_wpe", opt.v_wpe)
    out = out + ser_tensor_block("opt.m_lm_head", opt.m_lm_head)
    out = out + ser_tensor_block("opt.v_lm_head", opt.v_lm_head)
    out = out + ser_tensor_block("opt.m_final_gamma", opt.m_final_gamma)
    out = out + ser_tensor_block("opt.v_final_gamma", opt.v_final_gamma)

    // 逐层
    int l = 0
    while l < model.n_layer {
        gpt_layer layer = gpt_layer_at(model.layers, l)
        gpt_layer_adamw lo = opt.layers[l]
        string p = "L" + ser_int(l) + "."

        out = out + ser_tensor_block(p + "wq", layer.attn.query_weight)
        out = out + ser_tensor_block(p + "wk", layer.attn.key_weight)
        out = out + ser_tensor_block(p + "wv", layer.attn.value_weight)
        out = out + ser_tensor_block(p + "wo", layer.attn.output_weight)
        out = out + ser_tensor_block(p + "gate", layer.ffn.glu_ffn.gate_weight)
        out = out + ser_tensor_block(p + "val", layer.ffn.glu_ffn.value_weight)
        out = out + ser_tensor_block(p + "down", layer.ffn.glu_ffn.down_weight)
        out = out + ser_tensor_block(p + "n1", layer.norm1.gamma)
        out = out + ser_tensor_block(p + "n2", layer.norm2.gamma)

        // 优化器层状态
        out = out + ser_tensor_block(p + "o.m_wq", lo.m_wq)
        out = out + ser_tensor_block(p + "o.v_wq", lo.v_wq)
        out = out + ser_tensor_block(p + "o.m_wk", lo.m_wk)
        out = out + ser_tensor_block(p + "o.v_wk", lo.v_wk)
        out = out + ser_tensor_block(p + "o.m_wv", lo.m_wv)
        out = out + ser_tensor_block(p + "o.v_wv", lo.v_wv)
        out = out + ser_tensor_block(p + "o.m_wo", lo.m_wo)
        out = out + ser_tensor_block(p + "o.v_wo", lo.v_wo)
        out = out + ser_tensor_block(p + "o.m_gate", lo.m_ffn_gate_w)
        out = out + ser_tensor_block(p + "o.v_gate", lo.v_ffn_gate_w)
        out = out + ser_tensor_block(p + "o.m_val", lo.m_ffn_val_w)
        out = out + ser_tensor_block(p + "o.v_val", lo.v_ffn_val_w)
        out = out + ser_tensor_block(p + "o.m_down", lo.m_ffn_down_w)
        out = out + ser_tensor_block(p + "o.v_down", lo.v_ffn_down_w)
        out = out + ser_tensor_block(p + "o.m_n1", lo.m_norm1_gamma)
        out = out + ser_tensor_block(p + "o.v_n1", lo.v_norm1_gamma)
        out = out + ser_tensor_block(p + "o.m_n2", lo.m_norm2_gamma)
        out = out + ser_tensor_block(p + "o.v_n2", lo.v_norm2_gamma)

        l = l + 1
    }

    out = out + "END\n"
    out
}

// 保存到磁盘 (真实写文件)
func save_gpt_checkpoint(gpt_training_checkpoint ckpt, string dir, string filename) bool {
    runtime_make_dirs(dir)
    string path = dir + "/" + filename
    string content = serialize_gpt_checkpoint(ckpt)
    runtime_write_text_file(path, content)
    runtime_file_exists(path)
}

// ============================================================================
// 5. 完整 checkpoint 加载
// ============================================================================

struct ser_line_cursor {
    []string lines
    int pos
}

func ser_split_lines(string text) []string {
    []string out = []string{cap: 1024}
    int count = 0
    int i = 0
    int n = len(text)
    int start = 0
    while i < n {
        if text[i] == 10 {
            out[count] = substring_local(text, start, i)
            count = count + 1
            start = i + 1
        }
        i = i + 1
    }
    if start < n {
        out[count] = substring_local(text, start, n)
        count = count + 1
    }
    []string trimmed = []string{cap: count}
    int k = 0
    while k < count {
        trimmed[k] = out[k]
        k = k + 1
    }
    trimmed
}

// 在 lines 中查找 "TENSOR <name> <len>"，返回解析后的数组
// 张量数据在紧随其后的一行
func ser_find_tensor([]string lines, string name) []float {
    int i = 0
    while i < len(lines) {
        string line = lines[i]
        // 以 "TENSOR " 开头
        if ser_line_starts(line, "TENSOR ") {
            []string toks = ser_split_ws(line)
            if len(toks) >= 3 {
                if toks[1] == name {
                    int length = ser_parse_int(toks[2])
                    if i + 1 < len(lines) {
                        return ser_parse_float_array(lines[i + 1], length)
                    }
                    return []float{cap: 0}
                }
            }
        }
        i = i + 1
    }
    []float{cap: 0}
}

func ser_line_starts(string line, string prefix) bool {
    if len(prefix) > len(line) {
        return false
    }
    int i = 0
    while i < len(prefix) {
        if line[i] != prefix[i] {
            return false
        }
        i = i + 1
    }
    true
}

func ser_find_meta_line([]string lines) string {
    int i = 0
    while i < len(lines) {
        if ser_line_starts(lines[i], "META") {
            return lines[i]
        }
        i = i + 1
    }
    ""
}

func ser_find_config_line([]string lines) string {
    int i = 0
    while i < len(lines) {
        if ser_line_starts(lines[i], "CONFIG") {
            return lines[i]
        }
        i = i + 1
    }
    ""
}

// 从磁盘加载并重建完整 GPT checkpoint
func load_gpt_checkpoint(string path) gpt_training_checkpoint {
    string content = runtime_read_text_file(path)
    []string lines = ser_split_lines(content)

    // 解析配置并构建空模型骨架
    gpt_config cfg = ser_parse_config(ser_find_config_line(lines))
    gpt_model model = new_gpt_model(cfg)

    // 覆盖顶层权重
    model.wte = ser_find_tensor(lines, "wte")
    model.wpe = ser_find_tensor(lines, "wpe")
    model.lm_head = ser_find_tensor(lines, "lm_head")
    model.final_norm.gamma = ser_find_tensor(lines, "final_gamma")

    // 解析 META
    string meta = ser_find_meta_line(lines)
    []string mt = ser_split_ws(meta)
    int global_step = 0
    int opt_step = 0
    float lr = 0.0
    float loss = 0.0
    float best = 0.0
    float b1 = 0.9
    float b2 = 0.95
    float eps = 1e-8
    float wd = 0.1
    string stage = "loaded"
    string model_name = cfg.name
    int mi = 1
    while mi < len(mt) {
        string tok = mt[mi]
        string val = ser_kv_value(tok)
        if ser_key_is(tok, "step") {
            global_step = ser_parse_int(val)
        } else if ser_key_is(tok, "optstep") {
            opt_step = ser_parse_int(val)
        } else if ser_key_is(tok, "lr") {
            lr = ser_parse_float(val)
        } else if ser_key_is(tok, "loss") {
            loss = ser_parse_float(val)
        } else if ser_key_is(tok, "best") {
            best = ser_parse_float(val)
        } else if ser_key_is(tok, "b1") {
            b1 = ser_parse_float(val)
        } else if ser_key_is(tok, "b2") {
            b2 = ser_parse_float(val)
        } else if ser_key_is(tok, "eps") {
            eps = ser_parse_float(val)
        } else if ser_key_is(tok, "wd") {
            wd = ser_parse_float(val)
        } else if ser_key_is(tok, "stage") {
            stage = val
        } else if ser_key_is(tok, "model") {
            model_name = val
        }
        mi = mi + 1
    }

    // 重建优化器骨架并覆盖动量/方差
    gpt_adamw_state opt = new_gpt_adamw_state(model, lr, b1, b2, eps, wd)
    opt.step = opt_step
    opt.m_wte = ser_find_tensor(lines, "opt.m_wte")
    opt.v_wte = ser_find_tensor(lines, "opt.v_wte")
    opt.m_wpe = ser_find_tensor(lines, "opt.m_wpe")
    opt.v_wpe = ser_find_tensor(lines, "opt.v_wpe")
    opt.m_lm_head = ser_find_tensor(lines, "opt.m_lm_head")
    opt.v_lm_head = ser_find_tensor(lines, "opt.v_lm_head")
    opt.m_final_gamma = ser_find_tensor(lines, "opt.m_final_gamma")
    opt.v_final_gamma = ser_find_tensor(lines, "opt.v_final_gamma")

    // 逐层覆盖
    int l = 0
    while l < model.n_layer {
        gpt_layer layer = gpt_layer_at(model.layers, l)
        string p = "L" + ser_int(l) + "."

        layer.attn.query_weight  = ser_find_tensor(lines, p + "wq")
        layer.attn.key_weight    = ser_find_tensor(lines, p + "wk")
        layer.attn.value_weight  = ser_find_tensor(lines, p + "wv")
        layer.attn.output_weight = ser_find_tensor(lines, p + "wo")
        layer.ffn.glu_ffn.gate_weight  = ser_find_tensor(lines, p + "gate")
        layer.ffn.glu_ffn.value_weight = ser_find_tensor(lines, p + "val")
        layer.ffn.glu_ffn.down_weight  = ser_find_tensor(lines, p + "down")
        layer.norm1.gamma = ser_find_tensor(lines, p + "n1")
        layer.norm2.gamma = ser_find_tensor(lines, p + "n2")
        model.layers[l] = layer

        gpt_layer_adamw lo = opt.layers[l]
        lo.m_wq = ser_find_tensor(lines, p + "o.m_wq")
        lo.v_wq = ser_find_tensor(lines, p + "o.v_wq")
        lo.m_wk = ser_find_tensor(lines, p + "o.m_wk")
        lo.v_wk = ser_find_tensor(lines, p + "o.v_wk")
        lo.m_wv = ser_find_tensor(lines, p + "o.m_wv")
        lo.v_wv = ser_find_tensor(lines, p + "o.v_wv")
        lo.m_wo = ser_find_tensor(lines, p + "o.m_wo")
        lo.v_wo = ser_find_tensor(lines, p + "o.v_wo")
        lo.m_ffn_gate_w = ser_find_tensor(lines, p + "o.m_gate")
        lo.v_ffn_gate_w = ser_find_tensor(lines, p + "o.v_gate")
        lo.m_ffn_val_w = ser_find_tensor(lines, p + "o.m_val")
        lo.v_ffn_val_w = ser_find_tensor(lines, p + "o.v_val")
        lo.m_ffn_down_w = ser_find_tensor(lines, p + "o.m_down")
        lo.v_ffn_down_w = ser_find_tensor(lines, p + "o.v_down")
        lo.m_norm1_gamma = ser_find_tensor(lines, p + "o.m_n1")
        lo.v_norm1_gamma = ser_find_tensor(lines, p + "o.v_n1")
        lo.m_norm2_gamma = ser_find_tensor(lines, p + "o.m_n2")
        lo.v_norm2_gamma = ser_find_tensor(lines, p + "o.v_n2")
        opt.layers[l] = lo

        l = l + 1
    }

    snapshot_gpt_training_state(
        model, opt, global_step, 0, lr, loss, best, stage, model_name, 0
    )
}

// ============================================================================
// 6. 往返自检 (用于测试序列化正确性)
// ============================================================================

// 校验 float 往返: 序列化后再解析，返回最大相对误差
func ser_roundtrip_max_error([]float arr) float {
    float max_err = 0.0
    int i = 0
    while i < len(arr) {
        float original = arr[i]
        float restored = ser_parse_float(ser_float(original))
        float diff = original - restored
        if diff < 0.0 {
            diff = -diff
        }
        float denom = ser_abs(original)
        if denom < 1e-12 {
            denom = 1.0
        }
        float rel = diff / denom
        if rel > max_err {
            max_err = rel
        }
        i = i + 1
    }
    max_err
}
