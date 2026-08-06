package neurx.distributed.megatron.microbatch_calculator

struct schedule_entry {
    int threshold
    int batch_size
}

struct num_microbatches_calculator {
    string calculator_type
    int num_micro_batches
    int current_global_batch_size
    int current_running_global_batch_size
    int micro_batch_size
    int data_parallel_size
    int micro_batch_times_dp
    []schedule_entry schedule
}

func round_down(int batch_size, int divisor) int {
    return (batch_size / divisor) * divisor
}

func new_constant_calculator(
    int global_batch_size,
    int micro_batch_size,
    int data_parallel_size,
    bool decrease_batch_size_if_needed
) num_microbatches_calculator {
    int micro_times_dp = micro_batch_size * data_parallel_size
    int running_gbs = global_batch_size
    int num_micro = 0
    if decrease_batch_size_if_needed {
        running_gbs = round_down(global_batch_size, micro_times_dp)
        num_micro = running_gbs / micro_times_dp
    } else {
        running_gbs = global_batch_size
        num_micro = global_batch_size / micro_times_dp
    }
    if num_micro < 1 {
        num_micro = 1
    }
    num_microbatches_calculator {
        calculator_type: "constant",
        num_micro_batches: num_micro,
        current_global_batch_size: global_batch_size,
        current_running_global_batch_size: running_gbs,
        micro_batch_size: micro_batch_size,
        data_parallel_size: data_parallel_size,
        micro_batch_times_dp: micro_times_dp,
        schedule: make([]schedule_entry, 0),
    }
}

func new_rampup_calculator(
    int micro_batch_size,
    int data_parallel_size,
    []schedule_entry schedule
) num_microbatches_calculator {
    int micro_times_dp = micro_batch_size * data_parallel_size
    int first_gbs = schedule[0].batch_size
    int num_micro = first_gbs / micro_times_dp
    if num_micro < 1 {
        num_micro = 1
    }
    num_microbatches_calculator {
        calculator_type: "rampup",
        num_micro_batches: num_micro,
        current_global_batch_size: first_gbs,
        current_running_global_batch_size: first_gbs,
        micro_batch_size: micro_batch_size,
        data_parallel_size: data_parallel_size,
        micro_batch_times_dp: micro_times_dp,
        schedule: schedule,
    }
}

func get_batch_size_for_samples(
    num_microbatches_calculator calc,
    int consumed_samples
) int {
    int batch_size = calc.schedule[0].batch_size
    for int i = 0; i < len(calc.schedule); i = i + 1 {
        schedule_entry entry = calc.schedule[i]
        if consumed_samples >= entry.threshold {
            batch_size = entry.batch_size
        } else {
            break
        }
    }
    return batch_size
}

func update_num_microbatches(
    num_microbatches_calculator calc,
    int consumed_samples
) num_microbatches_calculator {
    if calc.calculator_type == "constant" {
        return calc
    }
    int new_gbs = get_batch_size_for_samples(calc, consumed_samples)
    calc.current_global_batch_size = new_gbs
    calc.current_running_global_batch_size = new_gbs
    calc.num_micro_batches = new_gbs / calc.micro_batch_times_dp
    if calc.num_micro_batches < 1 {
        calc.num_micro_batches = 1
    }
    return calc
}

func get_num_microbatches(num_microbatches_calculator calc) int {
    return calc.num_micro_batches
}

func get_current_global_batch_size(num_microbatches_calculator calc) int {
    return calc.current_global_batch_size
}

func validate_schedule([]schedule_entry schedule) bool {
    if len(schedule) == 0 {
        return false
    }
    if schedule[0].threshold != 0 {
        return false
    }
    for int i = 1; i < len(schedule); i = i + 1 {
        if schedule[i].threshold <= schedule[i - 1].threshold {
            return false
        }
    }
    for int i = 0; i < len(schedule); i = i + 1 {
        if schedule[i].batch_size <= 0 {
            return false
        }
    }
    return true
}

