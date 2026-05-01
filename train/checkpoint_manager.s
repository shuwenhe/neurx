package neurx.train.checkpoint_manager

struct checkpoint_manager_state {
    int keep_last_n
    int keep_every_n_steps
    bool save_best_only
    int last_saved_step
    int last_saved_epoch
    int best_step
    int best_epoch
    float best_score
    int save_count
}

func new_checkpoint_manager(int keep_last_n, int keep_every_n_steps, bool save_best_only) checkpoint_manager_state {
    checkpoint_manager_state {
        keep_last_n: keep_last_n,
        keep_every_n_steps: keep_every_n_steps,
        save_best_only: save_best_only,
        last_saved_step: -1,
        last_saved_epoch: -1,
        best_step: -1,
        best_epoch: -1,
        best_score: 0.0,
        save_count: 0,
    }
}

func checkpoint_manager_save(checkpoint_manager_state state, int step, int epoch) checkpoint_manager_state {
    int save_count = state.save_count + 1
    checkpoint_manager_state {
        keep_last_n: state.keep_last_n,
        keep_every_n_steps: state.keep_every_n_steps,
        save_best_only: state.save_best_only,
        last_saved_step: step,
        last_saved_epoch: epoch,
        best_step: state.best_step,
        best_epoch: state.best_epoch,
        best_score: state.best_score,
        save_count: save_count,
    }
}

func checkpoint_manager_mark_best(checkpoint_manager_state state, int step, int epoch, float score) checkpoint_manager_state {
    int next_best_step = state.best_step
    int next_best_epoch = state.best_epoch
    float next_best_score = state.best_score
    if state.best_step < 0 || score >= state.best_score {
        next_best_step = step
        next_best_epoch = epoch
        next_best_score = score
    }
    checkpoint_manager_state {
        keep_last_n: state.keep_last_n,
        keep_every_n_steps: state.keep_every_n_steps,
        save_best_only: state.save_best_only,
        last_saved_step: state.last_saved_step,
        last_saved_epoch: state.last_saved_epoch,
        best_step: next_best_step,
        best_epoch: next_best_epoch,
        best_score: next_best_score,
        save_count: state.save_count,
    }
}

func checkpoint_manager_load_latest(checkpoint_manager_state state) checkpoint_manager_state {
    state
}

func checkpoint_manager_load_best(checkpoint_manager_state state) checkpoint_manager_state {
    state
}
