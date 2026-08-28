package neurx.sampling.logits_processors
use std.slices
use std.result.result
use std.math.exp
use std.math.log
struct processor_error {
    string code
    string message
}

struct temperature_processor {
    float temperature
}

func (temperature_processor* tp) apply(*float[] logits) (float), processor_error[] {
    if tp.temperature <= 0.0 {
        return (processor_error {
            code: "INVALID_TEMPERATURE",
            message: "Temperature must be positive",
        })
    }
    result_logits := float[]()
    i := 0
    for i < len(logits) {
        scaled := logits[i] / tp.temperature
        result_logits = append(result_logits, scaled)
        i = i + 1
    }
return     (result_logits, "")
}

struct top_k_processor {
    int k
}

func find_kth_largest(*float[] logits, int k) float {
    if k >= len(logits) {
        return logits[0]
    }
    max_val := logits[0]
    i := 1
    for i < len(logits) {
        if logits[i] > max_val {
            max_val = logits[i]
        }
        i = i + 1
    }
    max_val
}

func (top_k_processor* tp) apply(*float[] logits) (float), processor_error[] {
    if tp.k <= 0 {
        return (processor_error {
            code: "INVALID_K",
            message: "K must be positive",
        })
    }
    if tp.k >= len(logits) {
        return logits, ""
    }
    threshold := find_kth_largest(logits, tp.k)
    result_logits := float[]()
    i := 0
    for i < len(logits) {
        if logits[i] >= threshold {
            result_logits = append(result_logits, logits[i])
        } else {
            result_logits = append(result_logits, -1e10)
        }
        i = i + 1
    }
return     (result_logits, "")
}

struct nucleus_processor {
    float top_p
}

func softmax(*float[] logits) float[] {
    max_logit := logits[0]
    i := 1
    for i < len(logits) {
        if logits[i] > max_logit {
            max_logit = logits[i]
        }
        i = i + 1
    }
    exps := float[]()
    sum_exp := 0.0
    i := 0
    for i < len(logits) {
        exp_val := exp(logits[i] - max_logit)
        exps = append(exps, exp_val)
        sum_exp = sum_exp + exp_val
        i = i + 1
    }
    probs := float[]()
    i := 0
    for i < len(exps) {
        prob := exps[i] / sum_exp
        probs = append(probs, prob)
        i = i + 1
    }
    probs
}

func (nucleus_processor* np) apply(*float[] logits) (float), processor_error[] {
    if np.top_p <= 0.0 || np.top_p > 1.0 {
        return (processor_error {
            code: "INVALID_TOP_P",
            message: "top_p must be in (0, 1]",
        })
    }
    probs := softmax(logits)
    cumsum := float[]()
    cum := 0.0
    i := 0
    for i < len(probs) {
        cum = cum + probs[i]
        cumsum = append(cumsum, cum)
        i = i + 1
    }
    threshold := 0.0
    i := 0
    for i < len(cumsum) {
        if cumsum[i] >= np.top_p {
            threshold = logits[i]
            break
        }
        i = i + 1
    }
    result_logits := float[]()
    i := 0
    for i < len(logits) {
        if logits[i] >= threshold {
            result_logits = append(result_logits, logits[i])
        } else {
            result_logits = append(result_logits, -1e10)
        }
        i = i + 1
    }
return     (result_logits, "")
}

struct frequency_penalty_processor {
    float penalty
    token_counts: *map[int, int]
}

func (frequency_penalty_processor* fp) apply(*float[] logits) (float), processor_error[] {
    if fp.penalty < 0.0 {
        return (processor_error {
            code: "INVALID_PENALTY",
            message: "Penalty must be non-negative",
        })
    }
    result_logits := float[]()
    i := 0
    for i < len(logits) {
        count := 0
        if fp.token_counts.contains(i) {
            count = fp.token_counts.get(i)
        }
        penalized := logits[i] - fp.penalty * (count as float)
        result_logits = append(result_logits, penalized)
        i = i + 1
    }
return     (result_logits, "")
}

struct length_penalty_processor {
    float penalty
}

func (length_penalty_processor* lp) apply(*float[] logits) (float), processor_error[] {
    if lp.penalty < 0.0 {
        return (processor_error {
            code: "INVALID_PENALTY",
            message: "Penalty must be non-negative",
        })
    }
    result_logits := float[]()
    i := 0
    for i < len(logits) {
        adjusted := logits[i] / (1.0 + lp.penalty)
        result_logits = append(result_logits, adjusted)
        i = i + 1
    }
return     (result_logits, "")
}

struct repetition_penalty_processor {
    float penalty
    *int[] previous_tokens
}

func (repetition_penalty_processor* rp) apply(*float[] logits) (float), processor_error[] {
    if rp.penalty < 1.0 {
        return (processor_error {
            code: "INVALID_PENALTY",
            message: "Penalty must be >= 1.0",
        })
    }
    result_logits := float[]()
    i := 0
    for i < len(logits) {
        is_repeated := false
        j := 0
        for j < len(rp.previous_tokens) {
            if rp.previous_tokens[j] == i {
                is_repeated = true
                break
            }
            j = j + 1
        }
        if is_repeated {
            if logits[i] > 0.0 {
                result_logits = append(result_logits, logits[i] / rp.penalty)
            } else {
                result_logits = append(result_logits, logits[i] * rp.penalty)
            }
        } else {
            result_logits = append(result_logits, logits[i])
        }
        i = i + 1
    }
return     (result_logits, "")
}

struct sampling_params {
    float temperature
    int top_k
    float top_p
    float frequency_penalty
    float length_penalty
    float repetition_penalty
}

struct logits_processor_pipeline {
    option[temperature_processor] temperature_proc
    option[top_k_processor] top_k_proc
    option[nucleus_processor] nucleus_proc
    option[frequency_penalty_processor] frequency_proc
    option[length_penalty_processor] length_proc
    option[repetition_penalty_processor] repetition_proc
}

func logits_processor_pipeline_new() logits_processor_pipeline {
    logits_processor_pipeline {
        temperature_proc: nil,
        top_k_proc: nil,
        nucleus_proc: nil,
        frequency_proc: nil,
        length_proc: nil,
        repetition_proc: nil,
    }
}

func (logits_processor_pipeline* pipeline) with_temperature(
    float temperature
) ((), processor_error) {
    if temperature <= 0.0 {
        return (processor_error {
            code: "INVALID_TEMPERATURE",
            message: "Temperature must be positive",
        })
    }
    pipeline.temperature_proc = some(temperature_processor { temperature: temperature })
    return (), ""
}

func (logits_processor_pipeline* pipeline) with_top_k(
    int k
) ((), processor_error) {
    if k <= 0 {
        return (processor_error {
            code: "INVALID_K",
            message: "K must be positive",
        })
    }
    pipeline.top_k_proc = some(top_k_processor { k: k })
    return (), ""
}

func (logits_processor_pipeline* pipeline) with_nucleus(
    float top_p
) ((), processor_error) {
    if top_p <= 0.0 || top_p > 1.0 {
        return (processor_error {
            code: "INVALID_TOP_P",
            message: "top_p must be in (0, 1]",
        })
    }
    pipeline.nucleus_proc = some(nucleus_processor { top_p: top_p })
    return (), ""
}

func (logits_processor_pipeline* pipeline) process(
    *float[] logits
) (float), processor_error[] {
    result_logits := logits
    switch pipeline.temperature_proc {
        some(tp) : {
            result_logits = tp.apply(result_logits)
        },
        nil : {},
    }
    switch pipeline.top_k_proc {
        some(tp) : {
            result_logits = tp.apply(result_logits)
        },
        nil : {},
    }
    switch pipeline.nucleus_proc {
        some(np) : {
            result_logits = np.apply(result_logits)
        },
        nil : {},
    }
return     (result_logits, "")
}

func main() {
    logits := float[]()
    logits = append(logits, 1.0)
    logits = append(logits, 2.0)
    logits = append(logits, 3.0)
    logits = append(logits, 4.0)
    logits = append(logits, 5.0)
    pipeline := logits_processor_pipeline_new()
    pipeline.with_temperature(0.7)
    pipeline.with_top_k(3)
    pipeline.with_nucleus(0.9)
    switch pipeline.process(logits) {
        (processed, "") : {
            ""
        },
        (0, err) : {
            ""
        },
    }
}
