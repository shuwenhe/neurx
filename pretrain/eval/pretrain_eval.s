package neurx.pretrain.eval
struct pretrain_eval_state {
    int last_eval_step
    float val_loss
    float ppl
    float best_val_loss
    float best_ppl
    float loss_delta
    bool has_result
    bool is_best
}

func new_pretrain_eval_state() pretrain_eval_state {
    pretrain_eval_state {
        last_eval_step: -1,
        val_loss: 0.0,
        ppl: 0.0,
        best_val_loss: 999999.0,
        best_ppl: 999999.0,
        loss_delta: 0.0,
        has_result: false,
        is_best: false,
    }
}

func update_pretrain_eval(pretrain_eval_state state, int step, float val_loss, float ppl) pretrain_eval_state {
    float next_best_val_loss = state.best_val_loss
    float next_best_ppl = state.best_ppl
    bool next_is_best = false
    if !state.has_result || val_loss < state.best_val_loss {
        next_best_val_loss = val_loss
        next_best_ppl = ppl
        next_is_best = true
    }
    pretrain_eval_state {
        last_eval_step: step,
        val_loss: val_loss,
        ppl: ppl,
        best_val_loss: next_best_val_loss,
        best_ppl: next_best_ppl,
        loss_delta: state.val_loss - val_loss,
        has_result: true,
        is_best: next_is_best,
    }
}

func pretrain_eval_perplexity_from_loss(float loss) float {
    if loss >= 20.0 {
        return 485165195.4097903
    }
    if loss <= -20.0 {
        return 0.0000000020611536
    }
    float reduced = loss
    int power_of_two = 0
    while reduced > 0.34657359027997265 {
        reduced = reduced - 0.6931471805599453
        power_of_two = power_of_two + 1
    }
    while reduced < -0.34657359027997265 {
        reduced = reduced + 0.6931471805599453
        power_of_two = power_of_two - 1
    }
    float term = 1.0
    float result = 1.0
    int order = 1
    while order <= 12 {
        term = term * reduced / order
        result = result + term
        order = order + 1
    }
    while power_of_two > 0 {
        result = result * 2.0
        power_of_two = power_of_two - 1
    }
    while power_of_two < 0 {
        result = result * 0.5
        power_of_two = power_of_two + 1
    }
    result
}

func pretrain_eval_update_from_loss(pretrain_eval_state state, int step, float val_loss) pretrain_eval_state {
    update_pretrain_eval(state, step, val_loss, pretrain_eval_perplexity_from_loss(val_loss))
}

func pretrain_eval_has_result(pretrain_eval_state state) bool {
    state.has_result
}

func pretrain_eval_is_best(pretrain_eval_state state) bool {
    state.is_best
}

func string_char(int c) string {
    string(c)
}

func int_to_str(int n) string {
    int value = n
    if value == 0 {
        return "0"
    }
    bool neg = value < 0
    if neg {
        value = -value
    }
    string s = ""
    while value > 0 {
        s = string_char(value % 10 + 48) + s
        value = value / 10
    }
    if neg {
        s = "-" + s
    }
    s
}

func fmt_float(float val, int decimals) string {
    float value = val
    if value == 0.0 {
        return "0.0"
    }
    bool neg = value < 0.0
    if neg {
        value = -value
    }
    int int_part = 0
    float whole = value
    while whole >= 1.0 {
        whole = whole - 1.0
        int_part = int_part + 1
    }
    float frac = value - int_part
    string s = ""
    if neg {
        s = "-"
    }
    s = s + string_char(int_part + 48) + "."
    int i = 0
    while i < decimals {
        frac = frac * 10.0
        int digit = 0
        float tmp = frac
        while tmp >= 1.0 {
            tmp = tmp - 1.0
            digit = digit + 1
        }
        s = s + string_char(digit + 48)
        frac = frac - digit
        i = i + 1
    }
    s
}

func pretrain_eval_summary(pretrain_eval_state state) string {
    string result = "eval(step="
    if state.has_result {
        result = result + int_to_str(state.last_eval_step)
        result = result + ", val_loss="
        result = result + fmt_float(state.val_loss, 6)
        result = result + ", ppl="
        result = result + fmt_float(state.ppl, 4)
        result = result + ", best_val_loss="
        result = result + fmt_float(state.best_val_loss, 6)
        result = result + ", best_ppl="
        result = result + fmt_float(state.best_ppl, 4)
        result = result + ", delta="
        result = result + fmt_float(state.loss_delta, 6)
        result = result + ", best="
        if state.is_best {
            result = result + "1"
        } else {
            result = result + "0"
        }
    } else {
        result = result + "-1, val_loss=0.000000, ppl=0.0000, best_val_loss=999999.000000, best_ppl=999999.0000, delta=0.000000, best=0"
    }
    result + ")"
}

func pretrain_eval_state_dict(pretrain_eval_state state) pretrain_eval_state {
    state
}

func pretrain_eval_load_state_dict(pretrain_eval_state state, pretrain_eval_state other) pretrain_eval_state {
    other
}

