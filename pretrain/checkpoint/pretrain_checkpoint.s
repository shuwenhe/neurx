package neurx.pretrain.checkpoint

struct pretrain_checkpoint_state {
    string run_name
    string root
    int keep_last
    int keep_every_n_steps
    bool save_best_only
    int last_saved_step
    int best_step
    float best_metric
    int save_count
    int prune_count
    int next_save_step
    bool has_best
}

func new_pretrain_checkpoint_state(string run_name, string root) pretrain_checkpoint_state {
    int next_save_step = 1000
    pretrain_checkpoint_state {
        run_name: run_name,
        root: root,
        keep_last: 5,
        keep_every_n_steps: 1000,
        save_best_only: false,
        last_saved_step: -1,
        best_step: -1,
        best_metric: 999999999999999999999999999999.0,
        save_count: 0,
        prune_count: 0,
        next_save_step: next_save_step,
        has_best: false
    }
}

func pretrain_checkpoint_should_save(pretrain_checkpoint_state state, int step) bool {
    if state.save_best_only {
        return false
    }
    if state.keep_every_n_steps <= 0 {
        return true
    }
    step >= state.next_save_step
}

func pretrain_checkpoint_should_save_best(pretrain_checkpoint_state state, float metric) bool {
    if !state.has_best {
        return true
    }
    metric < state.best_metric
}

func pretrain_checkpoint_next_save_step(pretrain_checkpoint_state state) int {
    state.next_save_step
}

func pretrain_checkpoint_has_best(pretrain_checkpoint_state state) bool {
    state.has_best
}

func pretrain_checkpoint_prune_count(pretrain_checkpoint_state state) int {
    state.prune_count
}

func mark_saved(pretrain_checkpoint_state state, int step) pretrain_checkpoint_state {
    int save_count = state.save_count + 1
    int prune_count = state.prune_count
    if state.keep_last > 0 && save_count > state.keep_last {
        prune_count = save_count - state.keep_last
    }

    int next_save_step = state.next_save_step
    if state.keep_every_n_steps > 0 {
        next_save_step = step + state.keep_every_n_steps
    } else {
        next_save_step = step + 1
    }

    pretrain_checkpoint_state {
        run_name: state.run_name,
        root: state.root,
        keep_last: state.keep_last,
        keep_every_n_steps: state.keep_every_n_steps,
        save_best_only: state.save_best_only,
        last_saved_step: step,
        best_step: state.best_step,
        best_metric: state.best_metric,
        save_count: save_count,
        prune_count: prune_count,
        next_save_step: next_save_step,
        has_best: state.has_best,
    }
}

func mark_best(pretrain_checkpoint_state state, int step, float metric) pretrain_checkpoint_state {
    if state.has_best && metric >= state.best_metric {
        return state
    }

    pretrain_checkpoint_state {
        run_name: state.run_name,
        root: state.root,
        keep_last: state.keep_last,
        keep_every_n_steps: state.keep_every_n_steps,
        save_best_only: state.save_best_only,
        last_saved_step: state.last_saved_step,
        best_step: step,
        best_metric: metric,
        save_count: state.save_count,
        prune_count: state.prune_count,
        next_save_step: state.next_save_step,
        has_best: true,
    }
}

func pretrain_checkpoint_state_dict(pretrain_checkpoint_state state) pretrain_checkpoint_state {
    state
}

func pretrain_checkpoint_load_state_dict(pretrain_checkpoint_state state, pretrain_checkpoint_state other) pretrain_checkpoint_state {
    other
}
