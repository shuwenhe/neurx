package neurx.distributed.eplb
struct eplb_config {
    int expert_count
    int rank_count
    int replicas_per_expert
    int rebalance_threshold_percent
    bool enabled
}

struct eplb_state {
    eplb_config config
    int[] expert_rank
    int[] expert_load
    int[] rank_load
    int routing_samples
    int rebalance_count
    bool initialized
    string error_message
}

struct eplb_rebalance_plan {
    int expert_id
    int source_rank
    int destination_rank
    int source_load
    int destination_load
    bool required
}

func eplb_config_valid(eplb_config config) bool {
    if !config.enabled { return true }
    config.expert_count > 0 && config.rank_count > 0 && config.replicas_per_expert > 0 && config.rebalance_threshold_percent >= 0
}

func eplb_zero_array(int count) []int {
    int[] values = make([]int, count)
    int i = 0
    for i < count { values[i] = 0; i = i + 1 }
    values
}

func eplb_initial_placement(int expert_count, int rank_count) []int {
    int[] placement = make([]int, expert_count)
    int i = 0
    for i < expert_count {
        placement[i] = i - (i / rank_count) * rank_count
        i = i + 1
    }
    placement
}

func init_eplb(eplb_config config) eplb_state {
    bool initialized = eplb_config_valid(config)
    string error_message = ""
    if !initialized { error_message = "invalid EPLB configuration" }
    eplb_state {
        config: config,
        expert_rank: eplb_initial_placement(config.expert_count, config.rank_count),
        expert_load: eplb_zero_array(config.expert_count),
        rank_load: eplb_zero_array(config.rank_count),
        routing_samples: 0,
        rebalance_count: 0,
        initialized: initialized,
        error_message: error_message,
    }
}

func eplb_record_routing(eplb_state state, int expert_id, int token_count) eplb_state {
    if !state.initialized || expert_id < 0 || expert_id >= len(state.expert_rank) || token_count <= 0 { return state }
    int rank = state.expert_rank[expert_id]
    state.expert_load[expert_id] = state.expert_load[expert_id] + token_count
    state.rank_load[rank] = state.rank_load[rank] + token_count
    state.routing_samples = state.routing_samples + token_count
    state
}

func eplb_heaviest_rank(eplb_state state) int {
    int result = 0
    int i = 1
    for i < len(state.rank_load) {
        if state.rank_load[i] > state.rank_load[result] { result = i }
        i = i + 1
    }
    result
}

func eplb_lightest_rank(eplb_state state) int {
    int result = 0
    int i = 1
    for i < len(state.rank_load) {
        if state.rank_load[i] < state.rank_load[result] { result = i }
        i = i + 1
    }
    result
}

func eplb_imbalance_percent(eplb_state state) int {
    if len(state.rank_load) == 0 { return 0 }
    int heavy = state.rank_load[eplb_heaviest_rank(state)]
    int light = state.rank_load[eplb_lightest_rank(state)]
    if heavy == 0 { return 0 }
    (heavy - light) * 100 / heavy
}

func eplb_plan_rebalance(eplb_state state) eplb_rebalance_plan {
    if !state.initialized || len(state.rank_load) < 2 || eplb_imbalance_percent(state) <= state.config.rebalance_threshold_percent {
        return eplb_rebalance_plan {expert_id: 0 - 1, source_rank: 0 - 1, destination_rank: 0 - 1, source_load: 0, destination_load: 0, required: false}
    }
    int source = eplb_heaviest_rank(state)
    int destination = eplb_lightest_rank(state)
    int expert = 0 - 1
    int expert_load = 0 - 1
    int i = 0
    for i < len(state.expert_rank) {
        if state.expert_rank[i] == source && state.expert_load[i] > expert_load {
            expert = i
            expert_load = state.expert_load[i]
        }
        i = i + 1
    }
    eplb_rebalance_plan {expert_id: expert, source_rank: source, destination_rank: destination, source_load: state.rank_load[source], destination_load: state.rank_load[destination], required: expert >= 0}
}

func eplb_apply_rebalance(eplb_state state, eplb_rebalance_plan plan) eplb_state {
    if !plan.required || plan.expert_id < 0 || plan.expert_id >= len(state.expert_rank) { return state }
    int load = state.expert_load[plan.expert_id]
    state.expert_rank[plan.expert_id] = plan.destination_rank
    state.rank_load[plan.source_rank] = state.rank_load[plan.source_rank] - load
    state.rank_load[plan.destination_rank] = state.rank_load[plan.destination_rank] + load
    state.rebalance_count = state.rebalance_count + 1
    state
}
