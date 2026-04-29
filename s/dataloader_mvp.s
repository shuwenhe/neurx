package neurx.dataloader_mvp

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

func has_next(dataloader_state state) bool {
    len(state.token_ids) > state.config.seq_len
}

func next_batch(dataloader_state state) dataloader_step_output {
    var total = len(state.token_ids)
    var batch_size = state.config.batch_size
    var seq_len = state.config.seq_len

    var input_ids = []int{cap: batch_size * seq_len}
    var target_ids = []int{cap: batch_size * seq_len}

    var cursor = state.cursor
    for b in 0..batch_size {
        if cursor + seq_len + 1 >= total {
            cursor = 0
        }

        for i in 0..seq_len {
            input_ids.push(state.token_ids[cursor + i])
            target_ids.push(state.token_ids[cursor + i + 1])
        }
        cursor = cursor + seq_len
    }

    var next_state = dataloader_state {
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
