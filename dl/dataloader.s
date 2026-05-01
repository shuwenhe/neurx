package neurx.dl.dataloader

struct dataloader_config {
    int batch_size
    int seq_len
}

struct dataloader_state {
    []int token_ids
    int cursor
    dataloader_config config
}

struct dataloader_batch {
    []int input_ids
    []int target_ids
    int valid_tokens
}

struct dataloader_step_output {
    dataloader_state state
    dataloader_batch batch
}

func _copy_int([]int values) []int {
    int n = len(values)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = values[i]
        i = i + 1
    }
    out
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
    }
}

func new_state([]int token_ids, int batch_size, int seq_len) dataloader_state {
    dataloader_state {
        token_ids: token_ids,
        cursor: 0,
        config: new_config(batch_size, seq_len),
    }
}

func reset_state(dataloader_state state) dataloader_state {
    dataloader_state {
        token_ids: state.token_ids,
        cursor: 0,
        config: state.config,
    }
}

func has_next(dataloader_state state) bool {
    len(state.token_ids) > state.config.seq_len + 1
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
    usable / tokens_per_batch
}

func _copy_batch_tokens([]int token_ids, int cursor, int seq_len) []int {
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

    []int input_ids = []int{cap: batch_size * seq_len}
    []int target_ids = []int{cap: batch_size * seq_len}

    int cursor = state.cursor
    int i = 0
    for b in 0..batch_size {
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
        cursor = cursor + seq_len
        i = i + 1
    }

    dataloader_state next_state = dataloader_state {
        token_ids: state.token_ids,
        cursor: cursor,
        config: state.config,
    }

    dataloader_step_output {
        state: next_state,
        batch: dataloader_batch {
            input_ids: input_ids,
            target_ids: target_ids,
            valid_tokens: len(input_ids),
        },
    }
}

func peek_batch(dataloader_state state) dataloader_batch {
    dataloader_step_output output = next_batch(state)
    output.batch
}
