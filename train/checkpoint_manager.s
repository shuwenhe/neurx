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
    int prune_count
    int next_save_step
    bool has_best
}

func new_checkpoint_manager(int keep_last_n, int keep_every_n_steps, bool save_best_only) checkpoint_manager_state {
    int next_save_step = keep_every_n_steps
    if next_save_step <= 0 {
        next_save_step = 1
    }
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
        prune_count: 0,
        next_save_step: next_save_step,
        has_best: false,
    }
}

func checkpoint_manager_should_save(checkpoint_manager_state state, int step) bool {
    if state.save_best_only {
        return false
    }
    if state.keep_every_n_steps <= 0 {
        return true
    }
    int bucket = step / state.keep_every_n_steps
    bucket * state.keep_every_n_steps == step
}

func checkpoint_manager_save(checkpoint_manager_state state, int step, int epoch) checkpoint_manager_state {
    int save_count = state.save_count + 1
    int prune_count = state.prune_count
    if state.keep_last_n > 0 && save_count > state.keep_last_n {
        prune_count = save_count - state.keep_last_n
    }
    int next_save_step = state.next_save_step
    if state.keep_every_n_steps > 0 {
        next_save_step = step + state.keep_every_n_steps
    } else {
        next_save_step = step + 1
    }
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
        prune_count: prune_count,
        next_save_step: next_save_step,
        has_best: state.has_best,
    }
}

func checkpoint_manager_mark_best(checkpoint_manager_state state, int step, int epoch, float score) checkpoint_manager_state {
    int next_best_step = state.best_step
    int next_best_epoch = state.best_epoch
    float next_best_score = state.best_score
    bool next_has_best = state.has_best
    if !state.has_best || score >= state.best_score {
        next_best_step = step
        next_best_epoch = epoch
        next_best_score = score
        next_has_best = true
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
        prune_count: state.prune_count,
        next_save_step: state.next_save_step,
        has_best: next_has_best,
    }
}

func checkpoint_manager_load_latest(checkpoint_manager_state state) checkpoint_manager_state {
    state
}

func checkpoint_manager_load_best(checkpoint_manager_state state) checkpoint_manager_state {
    state
}

func checkpoint_manager_state_dict(checkpoint_manager_state state) checkpoint_manager_state {
    state
}

func checkpoint_manager_load_state_dict(checkpoint_manager_state state, checkpoint_manager_state other) checkpoint_manager_state {
    other
}

func checkpoint_manager_should_save_best(checkpoint_manager_state state, float score) bool {
    if !state.has_best {
        return true
    }
    score >= state.best_score
}

func checkpoint_manager_last_saved_step(checkpoint_manager_state state) int {
    state.last_saved_step
}

func checkpoint_manager_last_saved_epoch(checkpoint_manager_state state) int {
    state.last_saved_epoch
}

func checkpoint_manager_best_step(checkpoint_manager_state state) int {
    state.best_step
}

func checkpoint_manager_best_epoch(checkpoint_manager_state state) int {
    state.best_epoch
}

func checkpoint_manager_best_score(checkpoint_manager_state state) float {
    state.best_score
}

func checkpoint_manager_save_count(checkpoint_manager_state state) int {
    state.save_count
}

func checkpoint_manager_prune_count(checkpoint_manager_state state) int {
    state.prune_count
}

func checkpoint_manager_next_save_step(checkpoint_manager_state state) int {
    state.next_save_step
}

func checkpoint_manager_has_best(checkpoint_manager_state state) bool {
    state.has_best
}
