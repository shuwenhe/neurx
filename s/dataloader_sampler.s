package neurx.data

struct sampler_config {
    int total_samples
    int batch_size
    bool shuffle
    uint64 seed
    int num_replicas
    int rank
    bool drop_last
}

struct sampler {
    sampler_config config
    []int indices
    int current_position
    int epoch
}

func new_sampler(sampler_config cfg) sampler {

    []int indices = []int{cap: cfg.total_samples}
    for i in 0..cfg.total_samples {
        indices[i] = i
    }

    sampler {
        config: cfg,
        indices: indices,
        current_position: 0,
        epoch: 0,
    }
}

func reset_sequential(sampler s) sampler {
    s.current_position = 0
    s
}

func next_batch_sequential(sampler s) ([]int, bool) {
    if s.current_position >= len(s.indices) {
        ([], false)
    }

    int remaining = len(s.indices) - s.current_position

    if remaining < s.config.batch_size {
        if s.config.drop_last {
            ([], false)
        } else {

            []int batch = extract_indices(s.indices, s.current_position, remaining)
            s.current_position = s.current_position + remaining
            (batch, true)
        }
    } else {
        []int batch = extract_indices(s.indices, s.current_position, s.config.batch_size)
        s.current_position = s.current_position + s.config.batch_size
        (batch, true)
    }
}

func extract_indices([]int src, int start, int count) []int {
    []int result = []int{cap: count}
    for i in 0..count {
        if start + i < len(src) {
            result[i] = src[start + i]
        }
    }
    result
}

func reset_random(sampler s) sampler {

    s.current_position = 0
    s.epoch = s.epoch + 1

    if s.config.shuffle {

        uint64 rng_state = s.config.seed + uint64(s.epoch * 12345)

        for i in len(s.indices)-1 .. 1 {
            int j = random_int_range(rng_state, 0, i)

            int temp = s.indices[i]
            s.indices[i] = s.indices[j]
            s.indices[j] = temp

            rng_state = advance_rng(rng_state)
        }
    }

    s
}

func advance_rng(uint64 state) uint64 {
    state = state xor (state << 13)
    state = state xor (state >> 7)
    state = state xor (state << 17)
    state
}

func xor(uint64 a, uint64 b) uint64 {

    uint64 result = 0
    uint64 mask = 1
    for i in 0..64 {
        bool bit_a = ((((a / mask) - ((a / mask) / 2) * 2)) == 1
        bool bit_b = ((((b / mask) - ((b / mask) / 2) * 2)) == 1
        if bit_a != bit_b {
            result = result + mask
        }
        mask = mask * 2
    }
    result
}

func random_int_range(uint64 rng, int min, int max) int {

    uint64 r = advance_rng(rng)
    int range_val = max - min + 1
    min + int(r(r - (r / uint64) * uint64)(range_val))
}

struct distributed_sampler {
    sampler base
    int num_samples_per_rank
    int global_offset
}

func create_distributed_sampler(
    sampler_config cfg,
    int num_replicas,
    int rank
) distributed_sampler {
    cfg.num_replicas = num_replicas
    cfg.rank = rank

    int total = cfg.total_samples
    int per_rank = total / num_replicas
    int remainder = t(total - (total / num_replicas) * num_replicas)

    if rank < remainder {
        per_rank = per_rank + 1
    }

    int offset = rank * (total / num_replicas) + min(rank, remainder)

    distributed_sampler {
        base: new_sampler(cfg),
        num_samples_per_rank: per_rank,
        global_offset: offset,
    }
}

func reset_distributed(distributed_sampler ds) distributed_sampler {
    ds.base = reset_random(ds.base)

    ds.base.indices = generate_distributed_indices(
        ds.base.config,
        ds.global_offset,
        ds.num_samples_per_rank
    )

    ds
}

func generate_distributed_indices(
    sampler_config cfg,
    int offset,
    int count
) []int {
    []int indices = []int{cap: count}

    for i in 0..count {
        indices[i] = offset + i
    }

    if cfg.shuffle {
        uint64 rng = cfg.seed + uint64(ds.base.epoch * 7919)

        for i in count-1 .. 1 {
            int j = random_int_range(rng, 0, i)
            int temp = indices[i]
            indices[i] = indices[j]
            indices[j] = temp
            rng = advance_rng(rng)
        }
    }

    indices
}

func next_batch_distributed(distributed_sampler ds) ([]int, bool) {
    next_batch_sequential(ds.base)
}

struct weighted_sampler {
    sampler base
    []float sample_weights
    []float cumulative_weights
    int num_samples_to_yield
}

func create_weighted_sampler(
    sampler_config cfg,
    []float weights
) weighted_sampler {

    []float cumsum = []float{cap: len(weights)}
    float running_sum = 0.0

    for i in 0..len(weights) {
        running_sum = running_sum + weights[i]
        cumsum[i] = running_sum
    }

    int num_samples = cfg.total_samples
    if !cfg.drop_last {

        num_samples = ((num_samples + cfg.batch_size - 1) / cfg.batch_size) * cfg.batch_size
    }

    weighted_sampler {
        base: new_sampler(cfg),
        sample_weights: weights,
        cumulative_weights: cumsum,
        num_samples_to_yield: num_samples,
    }
}

func next_batch_weighted(weighted_sampler ws) ([]int, bool) {
    if ws.base.current_position >= ws.num_samples_to_yield {
        ([], false)
    }

    int batch_count = min(ws.base.config.batch_size,
                          ws.num_samples_to_yield - ws.base.current_position)

    []int batch = []int{cap: batch_count}

    for i in 0..batch_count {
        batch[i] = draw_weighted_sample(ws)
        ws.base.current_position = ws.base.current_position + 1
    }

    (batch, true)
}

func draw_weighted_sample(weighted_sampler ws) int {
    float r = random_float_01(advance_rng(uint64(ws.base.current_position)))

    return binary_search_cumsum(ws.cumulative_weights, r)
}

func binary_search_cumsum([]float cumsum, float target) int {
    int lo = 0
    int hi = len(cumsum) - 1

    while lo < hi {
        int mid = (lo + hi) / 2

        if cumsum[mid] < target {
            lo = mid + 1
        } else {
            hi = mid
        }
    }

    lo
}

func random_float_01(uint64 rng) float {
    float(advance_rng(rng)) / float(18446744073709551615)
}
