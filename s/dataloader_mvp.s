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

func dataloader_config_state_dict(dataloader_config config) dataloader_config {
    config
}

func dataloader_config_load_state_dict(dataloader_config config, dataloader_config other) dataloader_config {
    other
}

func dataloader_state_state_dict(dataloader_state state) dataloader_state {
    state
}

func dataloader_state_load_state_dict(dataloader_state state, dataloader_state other) dataloader_state {
    other
}

func dataloader_batch_state_dict(dataloader_batch batch) dataloader_batch {
    batch
}

func dataloader_batch_load_state_dict(dataloader_batch batch, dataloader_batch other) dataloader_batch {
    other
}

func dataloader_step_output_state_dict(dataloader_step_output output) dataloader_step_output {
    output
}

func dataloader_step_output_load_state_dict(dataloader_step_output output, dataloader_step_output other) dataloader_step_output {
    other
}

func dataloader_token_count(dataloader_state state) int {
    len(state.token_ids)
}

func dataloader_batch_span(dataloader_config config) int {
    config.batch_size * config.seq_len
}

func dataloader_config_batch_size(dataloader_config config) int {
    config.batch_size
}

func dataloader_config_seq_len(dataloader_config config) int {
    config.seq_len
}

func dataloader_state_cursor(dataloader_state state) int {
    state.cursor
}

func dataloader_state_tokens(dataloader_state state) []int {
    state.token_ids
}

func dataloader_state_config(dataloader_state state) dataloader_config {
    state.config
}

func dataloader_batch_input_ids(dataloader_batch batch) []int {
    batch.input_ids
}

func dataloader_batch_target_ids(dataloader_batch batch) []int {
    batch.target_ids
}

func dataloader_batch_valid_tokens(dataloader_batch batch) int {
    batch.valid_tokens
}

func dataloader_step_output_state(dataloader_step_output output) dataloader_state {
    output.state
}

func dataloader_step_output_batch(dataloader_step_output output) dataloader_batch {
    output.batch
}

func has_next(dataloader_state state) bool {
    dataloader_mvp_has_next(state)
}

func next_batch(dataloader_state state) dataloader_step_output {
    dataloader_mvp_next_batch(state)
}

