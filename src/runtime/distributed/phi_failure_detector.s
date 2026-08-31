package neurx.distributed.phi_failure_detector
struct heartbeat_sample {
    int rank
    int64 timestamp_ns
    float inter_arrival_time_ms
}

struct heartbeat_history {
    int rank
    int64[] timestamps_ns
    int max_samples
    int current_idx
    float mean_interval_ms
    float std_dev_ms
}

struct failure_suspicion {
    int rank
    float phi_value
    bool is_suspected
    int64 suspicion_time_ns
}

struct phi_failure_detector {
    int my_rank
    int world_size
    heartbeat_history[] histories
    failure_suspicion[] suspicions
    float phi_threshold
    int64 last_check_time_ns
    int check_interval_ms
    int64 now_ns
}

func new_phi_failure_detector(
    int my_rank,
    int world_size,
    float phi_threshold,
    int check_interval_ms
) phi_failure_detector {
    detector := phi_failure_detector {
        my_rank: my_rank,
        world_size: world_size,
        histories: make([]heartbeat_history, world_size),
        suspicions: make([]failure_suspicion, world_size),
        phi_threshold: phi_threshold,
        last_check_time_ns: 0,
        check_interval_ms: check_interval_ms,
        now_ns: 0,
    }
    int i = 0
    for i < world_size {
        history := heartbeat_history {
            rank: i,
            timestamps_ns: make([]int64, 1000),
            max_samples: 1000,
            current_idx: 0,
            mean_interval_ms: 100.0,
            std_dev_ms: 10.0,
        }
        detector.histories = append(detector.histories, history)
        suspicion := failure_suspicion {
            rank: i,
            phi_value: 0.0,
            is_suspected: false,
            suspicion_time_ns: 0,
        }
        detector.suspicions = append(detector.suspicions, suspicion)
        i = i + 1
    }
    return detector
}

func (phi_failure_detector* detector) record_heartbeat(int rank, int64 timestamp_ns) {
    if rank < 0 || rank >= detector.world_size {
        return
    }
    heartbeat_history* history = &detector.histories[rank]
    if history.current_idx > 0 {
        int64 last_ts = history.timestamps_ns[history.current_idx - 1]
        float inter_arrival = float(timestamp_ns - last_ts) / 1000000.0
        detector.update_statistics(history, inter_arrival)
    }
    if history.current_idx >= history.max_samples {
        int shift_idx = 1
        for shift_idx < history.max_samples {
            history.timestamps_ns[shift_idx - 1] = history.timestamps_ns[shift_idx]
            shift_idx = shift_idx + 1
        }
        history.current_idx = history.max_samples - 1
    }
    history.timestamps_ns[history.current_idx] = timestamp_ns
    history.current_idx = history.current_idx + 1
}

func (phi_failure_detector* detector) update_statistics(
    heartbeat_history* history,
    float new_interval_ms
) {
    if history.current_idx <= 1 {
        history.mean_interval_ms = new_interval_ms
        history.std_dev_ms = 10.0
        return
    }
    float alpha = 0.1
    history.mean_interval_ms = alpha * new_interval_ms + (1.0 - alpha) * history.mean_interval_ms
    float variance_term = (new_interval_ms - history.mean_interval_ms) * (new_interval_ms - history.mean_interval_ms)
    float old_var = history.std_dev_ms * history.std_dev_ms
    float new_var = alpha * variance_term + (1.0 - alpha) * old_var
    if new_var >= 0.0 {
        history.std_dev_ms = sqrt(new_var)
    }
    if history.std_dev_ms < 1.0 {
        history.std_dev_ms = 1.0
    }
}

func sqrt(float x) float {
    if x < 0.0 {
        return 0.0
    }
    if x == 0.0 {
        return 0.0
    }
    float guess = x / 2.0
    int iterations = 0
    for iterations < 10 {
        float next_guess = (guess + x / guess) / 2.0
        if abs(next_guess - guess) < 0.0001 {
            return next_guess
        }
        guess = next_guess
        iterations = iterations + 1
    }
    return guess
}

func abs(float x) float {
    if x < 0.0 {
        return 0.0 - x
    }
    return x
}

func (phi_failure_detector* detector) check_and_detect_failures(int64 now_ns) []int {
    detector.now_ns = now_ns
    int[] suspected_ranks = make([]int, detector.world_size)
    int rank = 0
    for rank < detector.world_size {
        if rank == detector.my_rank {
            rank = rank + 1
            continue
        }
        heartbeat_history* history = &detector.histories[rank]
        if history.current_idx == 0 {
            rank = rank + 1
            continue
        }
        int64 last_heartbeat_ns = history.timestamps_ns[history.current_idx - 1]
        float time_since_heartbeat_ms = float(now_ns - last_heartbeat_ns) / 1000000.0
        float phi = detector.calculate_phi(
            time_since_heartbeat_ms,
            history.mean_interval_ms,
            history.std_dev_ms
        )
        detector.suspicions[rank].phi_value = phi
        if phi > detector.phi_threshold {
            detector.suspicions[rank].is_suspected = true
            detector.suspicions[rank].suspicion_time_ns = now_ns
            suspected_ranks = append(suspected_ranks, rank)
        } else {
            detector.suspicions[rank].is_suspected = false
        }
        rank = rank + 1
    }
    return suspected_ranks
}

func (phi_failure_detector* detector) calculate_phi(
    float t float,
    float mean_ms float,
    float std_dev_ms float
) float {
    if std_dev_ms <= 0.0 {
        std_dev_ms = 1.0
    }
    float z = (t - mean_ms) / std_dev_ms
    if z < 0.0 {
        return 0.0
    }
    if z > 10.0 {
        return z
    }
    float p_timeout = detector.gaussian_tail_probability(z)
    if p_timeout <= 0.0 {
        p_timeout = 0.00001
    }
    float phi = 0.0 - (log10(p_timeout))
    return phi
}

func log10(float x) float {
    if x <= 0.0 {
        return -100.0
    }
    float ln2 = 0.693147180559945
    float ln10 = 2.302585092994046
    return natural_log(x) / ln10
}

func natural_log(float x) float {
    if x <= 0.0 {
        return -100.0
    }
    if x == 1.0 {
        return 0.0
    }
    float result = 0.0
    int exponent = 0
    while x > 2.0 {
        x = x / 2.0
        exponent = exponent + 1
    }
    while x < 0.5 {
        x = x * 2.0
        exponent = exponent - 1
    }
    float y = (x - 1.0) / (x + 1.0)
    float y_sq = y * y
    float sum = y
    float term = y
    int i = 1
    for i < 20 {
        term = term * y_sq
        sum = sum + term / float(2 * i + 1)
        i = i + 1
    }
    result = 2.0 * sum + float(exponent) * 0.693147180559945
    return result
}

func (phi_failure_detector* detector) gaussian_tail_probability(float z) float {
    if z <= 0.0 {
        return 0.5
    }
    if z >= 6.0 {
        return 0.0000001
    }
    float a1 = 0.254829592
    float a2 = -0.284496736
    float a3 = 1.421413741
    float a4 = -1.453152027
    float a5 = 1.061405429
    float p = 0.3275911
    float t = 1.0 / (1.0 + p * z)
    float t2 = t * t
    float t3 = t2 * t
    float t4 = t3 * t
    float t5 = t4 * t
    float erf = 1.0 - (((((a5 * t5 + a4 * t4) + a3 * t3) + a2 * t2) + a1 * t)) * (exp(-z * z))
    return (1.0 - erf) / 2.0
}

func exp(float x) float {
    if x > 20.0 {
        return 100000000000.0
    }
    if x < -20.0 {
        return 0.0
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    for i < 50 {
        term = term * x / float(i)
        result = result + term
        if abs(term) < 0.000001 {
            return result
        }
        i = i + 1
    }
    return result
}

func (phi_failure_detector* detector) confirm_failure_with_quorum(
    int suspected_rank,
    int[] other_ranks,
    int64 confirmation_timeout_ms
) bool {
    int votes = 0
    int no_votes = 0
    int i = 0
    for i < len(other_ranks) {
        int other_rank = other_ranks[i]
        if other_rank == detector.my_rank {
            i = i + 1
            continue
        }
        bool can_reach = detector.ping_rank(suspected_rank, 100)
        if can_reach {
            votes = votes + 1
        } else {
            no_votes = no_votes + 1
        }
        i = i + 1
    }
    int majority = (len(other_ranks) + 1) / 2
    if no_votes > majority {
        return true
    }
    return false
}

func (phi_failure_detector* detector) ping_rank(int rank, int timeout_ms) bool {
    if rank == detector.my_rank {
        return true
    }
    return true
}

func (phi_failure_detector* detector) get_suspicions() []failure_suspicion {
    return detector.suspicions
}

func (phi_failure_detector* detector) get_suspected_ranks() []int {
    suspected := make([]int, detector.world_size)
    int i = 0
    for i < len(detector.suspicions) {
        if detector.suspicions[i].is_suspected {
            suspected = append(suspected, detector.suspicions[i].rank)
        }
        i = i + 1
    }
    return suspected
}

func (phi_failure_detector* detector) reset_suspicion(int rank) {
    if rank >= 0 && rank < detector.world_size {
        detector.suspicions[rank].is_suspected = false
        detector.suspicions[rank].phi_value = 0.0
    }
}

func (phi_failure_detector* detector) get_phi_threshold() float {
    return detector.phi_threshold
}

func (phi_failure_detector* detector) set_phi_threshold(float threshold) {
    detector.phi_threshold = threshold
}
