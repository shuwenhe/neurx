package neurx.sampling.logits_processors

use std.vec.vec
use std.result.result
use std.math.exp
use std.math.log

struct processor_error {
    code: string
    message: string
}

struct temperature_processor {
    temperature: float
}

func (temperature_processor* tp) apply(*vec[float] logits) result[vec[float], processor_error] {
    if tp.temperature <= 0.0 {
        return (processor_error {
            code: "INVALID_TEMPERATURE",
            message: "Temperature must be positive",
        })
    }

    result_logits := vec[float]()
    i := 0
    for i < logits.len() {
        scaled := logits[i] / tp.temperature
        result_logits.push(scaled)
        i = i + 1
    }

    (result_logits, "")
}

struct top_k_processor {
    k: int
}

func find_kth_largest(*vec[float] logits, int k) float {
    if k >= logits.len() {
        return logits[0]
    }

    max_val := logits[0]
    i := 1
    for i < logits.len() {
        if logits[i] > max_val {
            max_val = logits[i]
        }
        i = i + 1
    }

    max_val
}

func (top_k_processor* tp) apply(*vec[float] logits) result[vec[float], processor_error] {
    if tp.k <= 0 {
        return (processor_error {
            code: "INVALID_K",
            message: "K must be positive",
        })
    }

    if tp.k >= logits.len() {
        return (logits, "")
    }

    threshold := find_kth_largest(logits, tp.k)

    result_logits := vec[float]()
    i := 0
    for i < logits.len() {
        if logits[i] >= threshold {
            result_logits.push(logits[i])
        } else {
            result_logits.push(-1e10)
        }
        i = i + 1
    }

    (result_logits, "")
}

struct nucleus_processor {
    top_p: float
}

func softmax(*vec[float] logits) vec[float] {
    max_logit := logits[0]
    i := 1
    for i < logits.len() {
        if logits[i] > max_logit {
            max_logit = logits[i]
        }
        i = i + 1
    }

    exps := vec[float]()
    sum_exp := 0.0
    i := 0
    for i < logits.len() {
        exp_val := exp(logits[i] - max_logit)
        exps.push(exp_val)
        sum_exp = sum_exp + exp_val
        i = i + 1
    }

    probs := vec[float]()
    i := 0
    for i < exps.len() {
        prob := exps[i] / sum_exp
        probs.push(prob)
        i = i + 1
    }

    probs
}

func (nucleus_processor* np) apply(*vec[float] logits) result[vec[float], processor_error] {
    if np.top_p <= 0.0 || np.top_p > 1.0 {
        return (processor_error {
            code: "INVALID_TOP_P",
            message: "top_p must be in (0, 1]",
        })
    }

    probs := softmax(logits)

    cumsum := vec[float]()
    cum := 0.0
    i := 0
    for i < probs.len() {
        cum = cum + probs[i]
        cumsum.push(cum)
        i = i + 1
    }

    threshold := 0.0
    i := 0
    for i < cumsum.len() {
        if cumsum[i] >= np.top_p {
            threshold = logits[i]
            break
        }
        i = i + 1
    }

    result_logits := vec[float]()
    i := 0
    for i < logits.len() {
        if logits[i] >= threshold {
            result_logits.push(logits[i])
        } else {
            result_logits.push(-1e10)
        }
        i = i + 1
    }

    (result_logits, "")
}

struct frequency_penalty_processor {
    penalty: float
    token_counts: *map[int, int]
}

func (frequency_penalty_processor* fp) apply(*vec[float] logits) result[vec[float], processor_error] {
    if fp.penalty < 0.0 {
        return (processor_error {
            code: "INVALID_PENALTY",
            message: "Penalty must be non-negative",
        })
    }

    result_logits := vec[float]()
    i := 0
    for i < logits.len() {
        count := 0
        if fp.token_counts.contains(i) {
            count = fp.token_counts.get(i)
        }

        penalized := logits[i] - fp.penalty * (count as float)
        result_logits.push(penalized)
        i = i + 1
    }

    (result_logits, "")
}

struct length_penalty_processor {
    penalty: float
}

func (length_penalty_processor* lp) apply(*vec[float] logits) result[vec[float], processor_error] {
    if lp.penalty < 0.0 {
        return (processor_error {
            code: "INVALID_PENALTY",
            message: "Penalty must be non-negative",
        })
    }

    result_logits := vec[float]()
    i := 0
    for i < logits.len() {
        adjusted := logits[i] / (1.0 + lp.penalty)
        result_logits.push(adjusted)
        i = i + 1
    }

    (result_logits, "")
}

struct repetition_penalty_processor {
    penalty: float
    previous_tokens: *vec[int]
}

func (repetition_penalty_processor* rp) apply(*vec[float] logits) result[vec[float], processor_error] {
    if rp.penalty < 1.0 {
        return (processor_error {
            code: "INVALID_PENALTY",
            message: "Penalty must be >= 1.0",
        })
    }

    result_logits := vec[float]()
    i := 0
    for i < logits.len() {
        is_repeated := false
        j := 0
        for j < rp.previous_tokens.len() {
            if rp.previous_tokens[j] == i {
                is_repeated = true
                break
            }
            j = j + 1
        }

        if is_repeated {
            if logits[i] > 0.0 {
                result_logits.push(logits[i] / rp.penalty)
            } else {
                result_logits.push(logits[i] * rp.penalty)
            }
        } else {
            result_logits.push(logits[i])
        }
        i = i + 1
    }

    (result_logits, "")
}

struct sampling_params {
    temperature: float
    top_k: int
    top_p: float
    frequency_penalty: float
    length_penalty: float
    repetition_penalty: float
}

struct logits_processor_pipeline {
    temperature_proc: option[temperature_processor]
    top_k_proc: option[top_k_processor]
    nucleus_proc: option[nucleus_processor]
    frequency_proc: option[frequency_penalty_processor]
    length_proc: option[length_penalty_processor]
    repetition_proc: option[repetition_penalty_processor]
}

func logits_processor_pipeline::new() logits_processor_pipeline {
    logits_processor_pipeline {
        temperature_proc: option::none,
        top_k_proc: option::none,
        nucleus_proc: option::none,
        frequency_proc: option::none,
        length_proc: option::none,
        repetition_proc: option::none,
    }
}

func (logits_processor_pipeline* pipeline) with_temperature(
    temperature: float
) result[(), processor_error] {
    if temperature <= 0.0 {
        return (processor_error {
            code: "INVALID_TEMPERATURE",
            message: "Temperature must be positive",
        })
    }

    pipeline.temperature_proc = option::some(temperature_processor { temperature: temperature })
    ((, ""))
}

func (logits_processor_pipeline* pipeline) with_top_k(
    k: int
) result[(), processor_error] {
    if k <= 0 {
        return (processor_error {
            code: "INVALID_K",
            message: "K must be positive",
        })
    }

    pipeline.top_k_proc = option::some(top_k_processor { k: k })
    ((, ""))
}

func (logits_processor_pipeline* pipeline) with_nucleus(
    top_p: float
) result[(), processor_error] {
    if top_p <= 0.0 || top_p > 1.0 {
        return (processor_error {
            code: "INVALID_TOP_P",
            message: "top_p must be in (0, 1]",
        })
    }

    pipeline.nucleus_proc = option::some(nucleus_processor { top_p: top_p })
    ((, ""))
}

func (logits_processor_pipeline* pipeline) process(
    logits: *vec[float]
) result[vec[float], processor_error] {
    result_logits := logits

    switch pipeline.temperature_proc {
        option::some(tp) : {
            result_logits = tp.apply(result_logits)
        },
        option::none : {},
    }

    switch pipeline.top_k_proc {
        option::some(tp) : {
            result_logits = tp.apply(result_logits)
        },
        option::none : {},
    }

    switch pipeline.nucleus_proc {
        option::some(np) : {
            result_logits = np.apply(result_logits)
        },
        option::none : {},
    }

    (result_logits, "")
}

func main() {
    logits := vec[float]()
    logits.push(1.0)
    logits.push(2.0)
    logits.push(3.0)
    logits.push(4.0)
    logits.push(5.0)

    pipeline := logits_processor_pipeline::new()
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
