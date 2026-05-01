package neurx.training.checkpoint_manager

struct checkpoint_manager_state {
    int keep_last_n
    int keep_every_n_steps
    bool save_best_only
}

func new_checkpoint_manager(int keep_last_n, int keep_every_n_steps, bool save_best_only) checkpoint_manager_state {
    checkpoint_manager_state {
        keep_last_n: keep_last_n,
        keep_every_n_steps: keep_every_n_steps,
        save_best_only: save_best_only,
    }
}

func checkpoint_manager_save(checkpoint_manager_state state, int step, int epoch) checkpoint_manager_state {
    del step
    del epoch
    state
}

func checkpoint_manager_load_latest(checkpoint_manager_state state) checkpoint_manager_state {
    state
}

func checkpoint_manager_load_best(checkpoint_manager_state state) checkpoint_manager_state {
    state
}
