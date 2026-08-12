package neurx.posttrain.data
struct posttrain_data_state {
    string dataset_name
    string sample_mode
    string source_kind
    int source_size
    int pair_cursor
    int sample_cursor
    int epoch
    bool exhausted
}
func new_posttrain_data_state(string dataset_name, string sample_mode) posttrain_data_state {
    posttrain_data_state {
        dataset_name: dataset_name,
        sample_mode: sample_mode,
        source_kind: "dataset",
        source_size: 0,
        pair_cursor: 0,
        sample_cursor: 0,
        epoch: 0,
        exhausted: false,
    }
}
func new_reasoning_posttrain_data_state(string dataset_name, string sample_mode, int source_size) posttrain_data_state {
    int size = source_size
    if size < 0 {
        size = 0
    }
    posttrain_data_state {
        dataset_name: dataset_name,
        sample_mode: sample_mode,
        source_kind: "reasoning_trace",
        source_size: size,
        pair_cursor: 0,
        sample_cursor: 0,
        epoch: 0,
        exhausted: false,
    }
}
func posttrain_data_mark_source(posttrain_data_state state, string source_kind, int source_size) posttrain_data_state {
    int size = source_size
    if size < 0 {
        size = 0
    }
    posttrain_data_state {
        dataset_name: state.dataset_name,
        sample_mode: state.sample_mode,
        source_kind: source_kind,
        source_size: size,
        pair_cursor: state.pair_cursor,
        sample_cursor: state.sample_cursor,
        epoch: state.epoch,
        exhausted: state.exhausted,
    }
}
func advance_pairs(posttrain_data_state state, int pair_count) posttrain_data_state {
    posttrain_data_state {
        dataset_name: state.dataset_name,
        sample_mode: state.sample_mode,
        source_kind: state.source_kind,
        source_size: state.source_size,
        pair_cursor: state.pair_cursor + pair_count,
        sample_cursor: state.sample_cursor,
        epoch: state.epoch,
        exhausted: state.exhausted,
    }
}
func advance_samples(posttrain_data_state state, int sample_count) posttrain_data_state {
    posttrain_data_state {
        dataset_name: state.dataset_name,
        sample_mode: state.sample_mode,
        source_kind: state.source_kind,
        source_size: state.source_size,
        pair_cursor: state.pair_cursor,
        sample_cursor: state.sample_cursor + sample_count,
        epoch: state.epoch,
        exhausted: state.exhausted,
    }
}
func next_epoch(posttrain_data_state state) posttrain_data_state {
    posttrain_data_state {
        dataset_name: state.dataset_name,
        sample_mode: state.sample_mode,
        source_kind: state.source_kind,
        source_size: state.source_size,
        pair_cursor: 0,
        sample_cursor: 0,
        epoch: state.epoch + 1,
        exhausted: false,
    }
}
func posttrain_data_state_dict(posttrain_data_state state) posttrain_data_state {
    state
}
func posttrain_data_load_state_dict(posttrain_data_state state, posttrain_data_state other) posttrain_data_state {
    other
}
func posttrain_data_source_kind(posttrain_data_state state) string {
    state.source_kind
}
func posttrain_data_source_size(posttrain_data_state state) int {
    state.source_size
}
