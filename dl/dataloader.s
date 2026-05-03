package neurx.dl.dataloader

struct dataloader_config {
    int batch_size
    int seq_len
    bool drop_last
    bool shuffle
}

struct dataloader_state {
    []int token_ids
    int cursor
    int epoch
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
    dataloader_state {
        token_ids: token_ids,
        cursor: 0,
        epoch: 0,
        config: new_config(batch_size, seq_len),
    }
}

func reset_state(dataloader_state state) dataloader_state {
    dataloader_state {
        token_ids: copy_int(state.token_ids),
        cursor: 0,
        epoch: state.epoch + 1,
        config: copy_config(state.config),
    }
}

func with_config(dataloader_state state, dataloader_config config) dataloader_state {
    dataloader_state {
        token_ids: copy_int(state.token_ids),
        cursor: state.cursor,
        epoch: state.epoch,
        config: copy_config(config),
    }
}

func has_next(dataloader_state state) bool {
    int total = len(state.token_ids)
    int batch_span = state.config.batch_size * state.config.seq_len
    if batch_span <= 0 {
        return false
    }
    if total <= state.config.seq_len + 1 {
        return false
    }
    if state.config.drop_last {
        int usable = total - 1
        usable >= batch_span
    }
    state.cursor + state.config.seq_len + 1 <= total
}

func batch_count(dataloader_state state) int {
    int usable = len(state.token_ids) - 1
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

func next_batch(dataloader_state state) dataloader_step_output {
    int total = len(state.token_ids)
    int batch_size = state.config.batch_size
    int seq_len = state.config.seq_len
    int batch_span = batch_size * seq_len

    []int input_ids = []int{cap: batch_span}
    []int target_ids = []int{cap: batch_span}

    int cursor = state.cursor
    int batch_index = 0
    int b = 0
    while b < batch_size {
        if cursor + seq_len + 1 >= total {
            cursor = 0
        }

        int j = 0
        while j < seq_len {
            int out_idx = b * seq_len + j
            input_ids[out_idx] = state.token_ids[cursor + j]
            target_ids[out_idx] = state.token_ids[cursor + j + 1]
            j = j + 1
        }
        int next_cursor = cursor + seq_len
        int limit = total - seq_len - 1
        if limit < 0 {
            next_cursor = 0
        } else {
            if next_cursor > limit {
                next_cursor = 0
            }
        }
        cursor = next_cursor
        batch_index = batch_index + 1
        b = b + 1
    }

    dataloader_state next_state = dataloader_state {
        token_ids: state.token_ids,
        cursor: cursor,
        epoch: state.epoch,
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
        cursor: state.cursor,
        epoch: state.epoch,
        config: copy_config(state.config),
    }
}

func dataloader_load_state_dict(dataloader_state state, dataloader_state other) dataloader_state {
    dataloader_state {
        token_ids: copy_int(other.token_ids),
        cursor: other.cursor,
        epoch: other.epoch,
        config: copy_config(other.config),
    }
}
