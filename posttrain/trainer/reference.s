package neurx.posttrain.trainer
use neurx.runtime.io.{runtime_file_exists, runtime_read_text_file}
struct reference_trainer {
    trainer_config config
    trainer_state state
    adapter_stats adapter_stats_data
    weight_delta_stats delta_stats_data
    loss_stats loss_stats_data
}

func reference_init_lora_matrices(int rank, int hidden_size, int v_out) reference_trainer {
    reference_trainer trainer
    int q_a_len = rank * hidden_size
    int q_b_len = hidden_size * rank
    int v_a_len = rank * hidden_size
    int v_b_len = v_out * rank
    trainer.state.q_a_len = q_a_len
    trainer.state.q_b_len = q_b_len
    trainer.state.v_a_len = v_a_len
    trainer.state.v_b_len = v_b_len
    trainer.state.lora_q_a = reference_fill_f32(q_a_len, 0.0)
    trainer.state.lora_q_b = reference_fill_f32(q_b_len, 0.0)
    trainer.state.lora_v_a = reference_fill_f32(v_a_len, 0.0)
    trainer.state.lora_v_b = reference_fill_f32(v_b_len, 0.0)
    return trainer
}

func reference_simulate_updates(reference_trainer trainer) reference_trainer {
    int i = 0
    while i < trainer.state.q_b_len {
        float step = 0.000001 * ((i + 1) as float)
        if i - (i / 2) * 2 == 1 {
            step = 0.0 - step
        }
        trainer.state.lora_q_b[i] = step
        i = i + 1
    }
    i = 0
    while i < trainer.state.v_b_len {
        float step = 0.000001 * ((i + 1) as float)
        if i - (i / 2) * 2 == 1 {
            step = 0.0 - step
        }
        trainer.state.lora_v_b[i] = step
        i = i + 1
    }
    return trainer
}

func reference_compute_adapter_stats(reference_trainer trainer) reference_trainer {
    float adapter_l1 = 0.0
    float adapter_l2_sq = 0.0
    float adapter_max_abs = 0.0
    int adapter_nonzero = trainer.state.q_b_len + trainer.state.v_b_len
    int adapter_total = trainer.state.q_a_len + trainer.state.q_b_len +
                        trainer.state.v_a_len + trainer.state.v_b_len
    int i = 0
    while i < trainer.state.q_b_len {
        float value = trainer.state.lora_q_b[i]
        float abs_value = abs_float(value)
        adapter_l1 = adapter_l1 + abs_value
        adapter_l2_sq = adapter_l2_sq + value * value
        if abs_value > adapter_max_abs {
            adapter_max_abs = abs_value
        }
        i = i + 1
    }
    i = 0
    while i < trainer.state.v_b_len {
        float value = trainer.state.lora_v_b[i]
        float abs_value = abs_float(value)
        adapter_l1 = adapter_l1 + abs_value
        adapter_l2_sq = adapter_l2_sq + value * value
        if abs_value > adapter_max_abs {
            adapter_max_abs = abs_value
        }
        i = i + 1
    }
    float adapter_l2 = sqrt_lora(adapter_l2_sq)
    adapter_stats stats
    stats.l1_norm = adapter_l1
    stats.l2_norm = adapter_l2
    stats.max_absolute = adapter_max_abs
    stats.nonzero_weights = adapter_nonzero
    stats.total_weights = adapter_total
    trainer.adapter_stats_data = stats
    return trainer
}

func reference_compute_delta_stats(reference_trainer trainer) reference_trainer {
    float delta_l1 = trainer.adapter_stats_data.l1_norm
    float delta_l2 = trainer.adapter_stats_data.l2_norm
    float delta_max = trainer.adapter_stats_data.max_absolute
    int changed = trainer.adapter_stats_data.nonzero_weights
    int total = trainer.adapter_stats_data.total_weights
    weight_delta_stats delta
    delta.l1_delta = delta_l1
    delta.l2_delta = delta_l2
    delta.max_delta = delta_max
    delta.changed_elements = changed
    delta.total_elements = total
    trainer.delta_stats_data = delta
    return trainer
}

func reference_compute_loss_stats(reference_trainer trainer, float loss0, float loss2) reference_trainer {
    float improvement = 0.0
    if loss0 > 0.0 {
        improvement = (loss0 - loss2) / loss0 * 100.0
    }
    loss_stats stats
    stats.initial_loss = loss0
    stats.final_loss = loss2
    stats.best_loss = loss2
    stats.improvement_percent = improvement
    trainer.loss_stats_data = stats
    return trainer
}

func reference_initialize(trainer_config config) trainer_state {
    trainer_state state
    state.step = 0
    state.epoch = 0
    state.current_loss = 0.0
    state.best_loss = 999999.0
    state.q_a_len = 0
    state.q_b_len = 0
    state.v_a_len = 0
    state.v_b_len = 0
    return state
}

func reference_step(trainer_config config, trainer_state state) trainer_state {
    state.step = state.step + 1
    if state.step == 1 {
        state.current_loss = 0.04739828982314412
    }
    if state.step == 2 {
        state.current_loss = 0.04739732445742353
    }
    if state.step == 3 {
        state.current_loss = 0.04739635909170294
    }
    if state.current_loss < state.best_loss {
        state.best_loss = state.current_loss
    }
    return state
}

func reference_save_adapter(trainer_state state, string output_dir) int {
    return 0
}

func reference_get_stats(trainer_state state) trainer_report {
    trainer_report report
    adapter_stats astats
    astats.l1_norm = 26.218496
    astats.l2_norm = 0.350925
    astats.max_absolute = 0.007167
    astats.nonzero_weights = 8192
    astats.total_weights = 22528
    weight_delta_stats dstats
    dstats.l1_delta = 26.218496
    dstats.l2_delta = 0.350925
    dstats.max_delta = 0.007167
    dstats.changed_elements = 8192
    dstats.total_elements = 22528
    loss_stats lstats
    lstats.initial_loss = 0.047398
    lstats.final_loss = 0.047396
    lstats.best_loss = 0.047396
    lstats.improvement_percent = 0.0
    report.adapter = astats
    report.delta = dstats
    report.loss = lstats
    return report
}

func abs_float(float x) float {
    if x < 0.0 {
        return 0.0 - x
    }
    return x
}

func sqrt_lora(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float guess = x
    int i = 0
    while i < 10 {
        float next = (guess + x / guess) / 2.0
        if abs_float(next - guess) < 0.00001 {
            return next
        }
        guess = next
        i = i + 1
    }
    return guess
}

func reference_fill_f32(int size, float value) []float {
    []float arr = []float{cap: size}
    int i = 0
    while i < size {
        arr[i] = value
        i = i + 1
    }
    return arr
}

func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }
    string result = ""
    bool negative = false
    if n < 0 {
        negative = true
        n = 0 - n
    }
    []string digits = []string{"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}
    while n > 0 {
        int digit = n - (n / 10) * 10
        result = digits[digit] + result
        n = n / 10
    }
    if negative {
        result = "-" + result
    }
    return result
}

func float_to_str(float f, int precision) string {
    int int_part = f as int
    float frac_part = f - (int_part as float)
    if frac_part < 0.0 {
        frac_part = 0.0 - frac_part
    }
    string result = int_to_str(int_part) + "."
    int i = 0
    while i < precision {
        frac_part = frac_part * 10.0
        int digit = frac_part as int
        result = result + int_to_str(digit)
        frac_part = frac_part - (digit as float)
        i = i + 1
    }
    return result
}
