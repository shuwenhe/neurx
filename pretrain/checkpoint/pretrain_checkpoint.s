package neurx.pretrain.checkpoint

struct pretrain_checkpoint_state {
    string run_name
    string root
    int keep_last
    int last_saved_step
    int best_step
    float best_metric
    int save_count
}

func new_pretrain_checkpoint_state(string run_name, string root) pretrain_checkpoint_state {
    pretrain_checkpoint_state {
        run_name: run_name,
        root: root,
        keep_last: 5,
        last_saved_step: -1,
        best_step: -1,
        best_metric: -1.0,
        save_count: 0,
    }
}

func mark_saved(pretrain_checkpoint_state state, int step) pretrain_checkpoint_state {
    pretrain_checkpoint_state {
        run_name: state.run_name,
        root: state.root,
        keep_last: state.keep_last,
        last_saved_step: step,
        best_step: state.best_step,
        best_metric: state.best_metric,
        save_count: state.save_count + 1,
    }
}

func mark_best(pretrain_checkpoint_state state, int step, float metric) pretrain_checkpoint_state {
    pretrain_checkpoint_state {
        run_name: state.run_name,
        root: state.root,
        keep_last: state.keep_last,
        last_saved_step: state.last_saved_step,
        best_step: step,
        best_metric: metric,
        save_count: state.save_count,
    }
}

func pretrain_checkpoint_state_dict(pretrain_checkpoint_state state) pretrain_checkpoint_state {
    state
}

func pretrain_checkpoint_load_state_dict(pretrain_checkpoint_state state, pretrain_checkpoint_state other) pretrain_checkpoint_state {
    other
}
