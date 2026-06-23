package neurx.dl.dataloader

struct dataloader_config {
    int batch_size
    int seq_len
    bool drop_last
    bool shuffle
}

struct dataloader_state {
    []int token_ids
    []int indices
    int cursor
    int epoch
    int shuffle_seed
    dataloader_config config
}

struct dataloader_batch {
    []int input_ids
    []int target_ids
    int valid_tokens
    int batch_index
    int epoch
}

struct dataloader_step_output {
    dataloader_state state
    dataloader_batch batch
}

func copy_int([]int values) []int {
    int n = len(values)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func build_identity_indices(int total) []int {
    if total <= 0 {
        return []int{cap: 0}
    }
    []int indices = []int{cap: total}
    int i = 0
    while i < total {
        indices[i] = i
        i = i + 1
    }
    indices
}

func positive_mod(int value, int modulus) int {
    if modulus <= 0 {
        return 0
    }
    int div_result = value / modulus
    int result = value - div_result * modulus
    if result < 0 {
        result = result + modulus
    }
    result
}

func mix_seed(int seed, int epoch, int total) int {
    int mixed = seed + epoch * 1103515245
    mixed = mixed + total * 265443576
    mixed
}

func shuffle_indices([]int indices, int seed) []int {
    int total = len(indices)
    if total <= 1 {
        return copy_int(indices)
    }

    []int out = copy_int(indices)
    int state = seed
    int i = total - 1
    while i > 0 {
        state = state * 1664525 + 1013904223
        int j = positive_mod(state, i + 1)
        int tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
        i = i - 1
    }
    out
}

func build_indices_for_epoch_from_parts([]int token_ids, bool shuffle, int shuffle_seed, int epoch) []int {
    []int base = build_identity_indices(len(token_ids))
    if !shuffle {
        return base
    }
    shuffle_indices(base, mix_seed(shuffle_seed, epoch, len(base)))
}

func copy_config(dataloader_config config) dataloader_config {
    dataloader_config {
        batch_size: config.batch_size,
        seq_len: config.seq_len,
        drop_last: config.drop_last,
        shuffle: config.shuffle,
    }
}

func default_collate([]float values) []float {
    []float out = []float{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func new_config(int batch_size, int seq_len) dataloader_config {
    dataloader_config {
        batch_size: batch_size,
        seq_len: seq_len,
        drop_last: false,
        shuffle: false,
    }
}

func set_drop_last(dataloader_config config, bool drop_last) dataloader_config {
    dataloader_config {
        batch_size: config.batch_size,
        seq_len: config.seq_len,
        drop_last: drop_last,
        shuffle: config.shuffle,
    }
}

func set_shuffle(dataloader_config config, bool shuffle) dataloader_config {
    dataloader_config {
        batch_size: config.batch_size,
        seq_len: config.seq_len,
        drop_last: config.drop_last,
        shuffle: shuffle,
    }
}

func new_state([]int token_ids, int batch_size, int seq_len) dataloader_state {
    []int copied = copy_int(token_ids)
    []int indices = build_identity_indices(len(copied))
    dataloader_state {
        token_ids: copied,
        indices: indices,
        cursor: 0,
        epoch: 0,
        shuffle_seed: 0,
        config: new_config(batch_size, seq_len),
    }
}

func reset_state(dataloader_state state) dataloader_state {
    dataloader_state {
        token_ids: copy_int(state.token_ids),
        indices: build_indices_for_epoch_from_parts(state.token_ids, state.config.shuffle, state.shuffle_seed, state.epoch + 1),
        cursor: 0,
        epoch: state.epoch + 1,
        shuffle_seed: state.shuffle_seed,
        config: copy_config(state.config),
    }
}

func with_config(dataloader_state state, dataloader_config config) dataloader_state {
    dataloader_state {
        token_ids: copy_int(state.token_ids),
        indices: build_indices_for_epoch_from_parts(state.token_ids, config.shuffle, state.shuffle_seed, state.epoch),
        cursor: state.cursor,
        epoch: state.epoch,
        shuffle_seed: state.shuffle_seed,
        config: copy_config(config),
    }
}

func has_next(dataloader_state state) bool {
    int total = len(state.token_ids)
    int batch_span = state.config.batch_size * state.config.seq_len
    if batch_span <= 0 {
        return false
    }
    if total <= state.config.seq_len {
        return false
    }
    if state.config.drop_last && total - 1 < batch_span {
        return false
    }
    true
}

func batch_count(dataloader_state state) int {
    int usable = len(state.indices) - 1
    if usable <= 0 {
        return 0
    }
    int tokens_per_batch = state.config.batch_size * state.config.seq_len
    if tokens_per_batch <= 0 {
        return 0
    }
    int count = usable / tokens_per_batch
    if !state.config.drop_last && count * tokens_per_batch < usable {
        count = count + 1
    }
    count
}

func copy_batch_tokens([]int token_ids, int cursor, int seq_len) []int {
    []int out = []int{cap: seq_len}
    int i = 0
    while i < seq_len {
        out[i] = token_ids[cursor + i]
        i = i + 1
    }
    out
}

func set_shuffle_seed(dataloader_state state, int seed) dataloader_state {
    dataloader_state {
        token_ids: copy_int(state.token_ids),
        indices: build_indices_for_epoch_from_parts(state.token_ids, state.config.shuffle, seed, state.epoch),
        cursor: state.cursor,
        epoch: state.epoch,
        shuffle_seed: seed,
        config: copy_config(state.config),
    }
}

func dataloader_resolve_token(dataloader_state state, int offset) int {
    int total = len(state.indices)
    if total <= 0 {
        return 0
    }
    int index = positive_mod(offset, total)
    int resolved = state.indices[index]
    if resolved < 0 || resolved >= len(state.token_ids) {
        return 0
    }
    state.token_ids[resolved]
}

func next_batch(dataloader_state state) dataloader_step_output {
    int total = len(state.indices)
    int batch_size = state.config.batch_size
    int seq_len = state.config.seq_len
    int batch_span = batch_size * seq_len

    []int input_ids = []int{cap: batch_span}
    []int target_ids = []int{cap: batch_span}

    int cursor = state.cursor
    int batch_index = 0
    int b = 0
    while b < batch_size {
        int j = 0
        while j < seq_len {
            int out_idx = b * seq_len + j
            int input_offset = cursor + j
            int target_offset = cursor + j + 1
            input_ids[out_idx] = dataloader_resolve_token(state, input_offset)
            target_ids[out_idx] = dataloader_resolve_token(state, target_offset)
            j = j + 1
        }
        int next_cursor = cursor + seq_len
        if total <= 0 {
            next_cursor = 0
        } else if next_cursor >= total {
            int div_result = next_cursor / total
            next_cursor = next_cursor - div_result * total
        }
        cursor = next_cursor
        batch_index = batch_index + 1
        b = b + 1
    }

    dataloader_state next_state = dataloader_state {
        token_ids: state.token_ids,
        indices: copy_int(state.indices),
        cursor: cursor,
        epoch: state.epoch,
        shuffle_seed: state.shuffle_seed,
        config: state.config,
    }

    dataloader_step_output {
        state: next_state,
        batch: dataloader_batch {
            input_ids: input_ids,
            target_ids: target_ids,
            valid_tokens: len(input_ids),
            batch_index: batch_index,
            epoch: state.epoch,
        },
    }
}

func peek_batch(dataloader_state state) dataloader_batch {
    dataloader_step_output output = next_batch(state)
    output.batch
}

func drop_last_enabled(dataloader_state state) bool {
    state.config.drop_last
}

func shuffle_enabled(dataloader_state state) bool {
    state.config.shuffle
}

func dataloader_state_dict(dataloader_state state) dataloader_state {
    dataloader_state {
        token_ids: copy_int(state.token_ids),
        indices: copy_int(state.indices),
        cursor: state.cursor,
        epoch: state.epoch,
        shuffle_seed: state.shuffle_seed,
        config: copy_config(state.config),
    }
}

func dataloader_load_state_dict(dataloader_state state, dataloader_state other) dataloader_state {
    dataloader_state {
        token_ids: copy_int(other.token_ids),
        indices: copy_int(other.indices),
        cursor: other.cursor,
        epoch: other.epoch,
        shuffle_seed: other.shuffle_seed,
        config: copy_config(other.config),
    }
}
