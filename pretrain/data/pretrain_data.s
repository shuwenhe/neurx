package neurx.pretrain.data
struct pretrain_data_state {
    string dataset_name
    int shard_id
    int num_shards
    int token_cursor
    int sample_cursor
    int epoch
    bool exhausted
}
func new_pretrain_data_state(string dataset_name, int shard_id, int num_shards) pretrain_data_state {
    pretrain_data_state {
        dataset_name: dataset_name,
        shard_id: shard_id,
        num_shards: num_shards,
        token_cursor: 0,
        sample_cursor: 0,
        epoch: 0,
        exhausted: false,
    }
}

func advance_tokens(pretrain_data_state state, int token_count) pretrain_data_state {
    pretrain_data_state {
        dataset_name: state.dataset_name,
        shard_id: state.shard_id,
        num_shards: state.num_shards,
        token_cursor: state.token_cursor + token_count,
        sample_cursor: state.sample_cursor,
        epoch: state.epoch,
        exhausted: state.exhausted,
    }
}

func advance_samples(pretrain_data_state state, int sample_count) pretrain_data_state {
    pretrain_data_state {
        dataset_name: state.dataset_name,
        shard_id: state.shard_id,
        num_shards: state.num_shards,
        token_cursor: state.token_cursor,
        sample_cursor: state.sample_cursor + sample_count,
        epoch: state.epoch,
        exhausted: state.exhausted,
    }
}

func mark_exhausted(pretrain_data_state state, bool exhausted) pretrain_data_state {
    pretrain_data_state {
        dataset_name: state.dataset_name,
        shard_id: state.shard_id,
        num_shards: state.num_shards,
        token_cursor: state.token_cursor,
        sample_cursor: state.sample_cursor,
        epoch: state.epoch,
        exhausted: exhausted,
    }
}

func next_epoch(pretrain_data_state state) pretrain_data_state {
    pretrain_data_state {
        dataset_name: state.dataset_name,
        shard_id: state.shard_id,
        num_shards: state.num_shards,
        token_cursor: 0,
        sample_cursor: 0,
        epoch: state.epoch + 1,
        exhausted: false,
    }
}

func pretrain_data_state_dict(pretrain_data_state state) pretrain_data_state {
    state
}

func pretrain_data_load_state_dict(pretrain_data_state state, pretrain_data_state other) pretrain_data_state {
    other
}
