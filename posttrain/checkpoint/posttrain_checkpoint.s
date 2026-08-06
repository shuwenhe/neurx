package neurx.posttrain.checkpoint

struct posttrain_checkpoint_state {
    string run_name
    string root
    int keep_last
    int last_saved_step
    int best_step
    float best_score
    int save_count
}

func new_posttrain_checkpoint_state(string run_name, string root) posttrain_checkpoint_state {
    posttrain_checkpoint_state {
        run_name: run_name,
        root: root,
        keep_last: 5,
        last_saved_step: -1,
        best_step: -1,
        best_score: -1.0,
        save_count: 0,
    }
}

func mark_posttrain_saved(posttrain_checkpoint_state state, int step) posttrain_checkpoint_state {
    posttrain_checkpoint_state {
        run_name: state.run_name,
        root: state.root,
        keep_last: state.keep_last,
        last_saved_step: step,
        best_step: state.best_step,
        best_score: state.best_score,
        save_count: state.save_count + 1,
    }
}

func mark_posttrain_best(posttrain_checkpoint_state state, int step, float score) posttrain_checkpoint_state {
    posttrain_checkpoint_state {
        run_name: state.run_name,
        root: state.root,
        keep_last: state.keep_last,
        last_saved_step: state.last_saved_step,
        best_step: step,
        best_score: score,
        save_count: state.save_count,
    }
}

func posttrain_checkpoint_state_dict(posttrain_checkpoint_state state) posttrain_checkpoint_state {
    state
}

func posttrain_checkpoint_load_state_dict(posttrain_checkpoint_state state, posttrain_checkpoint_state other) posttrain_checkpoint_state {
    other
}

