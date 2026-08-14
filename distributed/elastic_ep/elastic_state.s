package neurx.distributed.elastic_ep
func elastic_phase_stable() int { 0 }

func elastic_phase_staging() int { 1 }

func elastic_phase_committing() int { 2 }

func elastic_phase_failed() int { 3 }

struct elastic_ep_config {
    int minimum_world_size
    int maximum_world_size
    int initial_world_size
    int expert_count
    int rebalance_threshold_percent
    bool enabled
}

struct elastic_ep_state {
    elastic_ep_config config
    int active_world_size
    int target_world_size
    int generation
    int phase
    []int active_ranks
    []int staged_ranks
    bool initialized
    string error_message
}

struct elastic_ep_transition {
    elastic_ep_state state
    bool accepted
    string error_message
}

func elastic_ep_config_valid(elastic_ep_config config) bool {
    if !config.enabled { return true }
    if config.minimum_world_size <= 0 || config.maximum_world_size < config.minimum_world_size { return false }
    if config.initial_world_size < config.minimum_world_size || config.initial_world_size > config.maximum_world_size { return false }
    if config.expert_count <= 0 || config.rebalance_threshold_percent < 0 { return false }
    true
}

func elastic_rank_range(int count) []int {
    []int ranks = []int{cap: count}
    int i = 0
    while i < count {
        ranks[i] = i
        i = i + 1
    }
    ranks
}

func elastic_copy_ranks([]int ranks) []int {
    []int copied = []int{cap: len(ranks)}
    int i = 0
    while i < len(ranks) {
        copied[i] = ranks[i]
        i = i + 1
    }
    copied
}

func init_elastic_ep(elastic_ep_config config) elastic_ep_state {
    bool initialized = elastic_ep_config_valid(config)
    int world_size = config.initial_world_size
    if !config.enabled { world_size = 0 }
    string error_message = ""
    if !initialized { error_message = "invalid elastic expert parallel configuration" }
    elastic_ep_state {
        config: config,
        active_world_size: world_size,
        target_world_size: world_size,
        generation: 0,
        phase: elastic_phase_stable(),
        active_ranks: elastic_rank_range(world_size),
        staged_ranks: [],
        initialized: initialized,
        error_message: error_message,
    }
}

func stage_elastic_ep_resize(elastic_ep_state state, int target_world_size) elastic_ep_transition {
    if !state.initialized || !state.config.enabled {
        return elastic_ep_transition {state: state, accepted: false, error_message: "elastic expert parallel is not initialized"}
    }
    if state.phase != elastic_phase_stable() {
        return elastic_ep_transition {state: state, accepted: false, error_message: "another elastic transition is active"}
    }
    if target_world_size < state.config.minimum_world_size || target_world_size > state.config.maximum_world_size {
        return elastic_ep_transition {state: state, accepted: false, error_message: "target world size is outside configured bounds"}
    }
    if target_world_size == state.active_world_size {
        return elastic_ep_transition {state: state, accepted: false, error_message: "target world size is unchanged"}
    }
    elastic_ep_state staged = elastic_ep_state {
        config: state.config,
        active_world_size: state.active_world_size,
        target_world_size: target_world_size,
        generation: state.generation,
        phase: elastic_phase_staging(),
        active_ranks: elastic_copy_ranks(state.active_ranks),
        staged_ranks: elastic_rank_range(target_world_size),
        initialized: state.initialized,
        error_message: "",
    }
    elastic_ep_transition {state: staged, accepted: true, error_message: ""}
}

func commit_elastic_ep_resize(elastic_ep_state state) elastic_ep_transition {
    if state.phase != elastic_phase_staging() || len(state.staged_ranks) != state.target_world_size {
        return elastic_ep_transition {state: state, accepted: false, error_message: "no valid elastic resize is staged"}
    }
    elastic_ep_state committed = elastic_ep_state {
        config: state.config,
        active_world_size: state.target_world_size,
        target_world_size: state.target_world_size,
        generation: state.generation + 1,
        phase: elastic_phase_stable(),
        active_ranks: elastic_copy_ranks(state.staged_ranks),
        staged_ranks: [],
        initialized: state.initialized,
        error_message: "",
    }
    elastic_ep_transition {state: committed, accepted: true, error_message: ""}
}

func abort_elastic_ep_resize(elastic_ep_state state, string reason) elastic_ep_state {
    elastic_ep_state {
        config: state.config,
        active_world_size: state.active_world_size,
        target_world_size: state.active_world_size,
        generation: state.generation,
        phase: elastic_phase_stable(),
        active_ranks: elastic_copy_ranks(state.active_ranks),
        staged_ranks: [],
        initialized: state.initialized,
        error_message: reason,
    }
}
