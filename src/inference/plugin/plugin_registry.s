package neurx.inference.plugins.plugin_registry

func plugin_group_general() int { 1 }

func plugin_group_io_processor() int { 2 }

func plugin_group_platform() int { 3 }

func plugin_group_stat_logger() int { 4 }

func plugin_group_endpoint() int { 5 }

func plugin_group_lora_resolver() int { 6 }

func plugin_status_discovered() int { 1 }

func plugin_status_active() int { 2 }

func plugin_status_skipped() int { 3 }

func plugin_status_failed() int { 4 }

struct plugin_registry_config {
    int capacity
    int supported_task_mask
    bool endpoint_allowlist_configured
}

struct plugin_registry_state {
    plugin_registry_config config
    []int plugin_ids
    []int groups
    []int required_task_masks
    []int allowlisted
    []int statuses
    int plugin_count
    int active_count
    int failed_count
    bool initialized
}

struct plugin_registration_result {
    plugin_registry_state state
    int slot
    bool registered
    int error_code
}

func plugin_zero_array(int capacity) []int {
    []int values = []int{cap: capacity}
    int i = 0
    while i < capacity { values[i] = 0; i = i + 1 }
    values
}

func init_plugin_registry(plugin_registry_config config) plugin_registry_state {
    plugin_registry_state {config: config, plugin_ids: plugin_zero_array(config.capacity), groups: plugin_zero_array(config.capacity), required_task_masks: plugin_zero_array(config.capacity), allowlisted: plugin_zero_array(config.capacity), statuses: plugin_zero_array(config.capacity), plugin_count: 0, active_count: 0, failed_count: 0, initialized: config.capacity > 0}
}

func plugin_tasks_intersect(int required, int supported) bool {
    if required == 0 { return true }
    int flag = 1
    int i = 0
    while i < 30 {
        int required_bit = (required / flag) - (required / flag / 2) * 2
        int supported_bit = (supported / flag) - (supported / flag / 2) * 2
        if required_bit == 1 && supported_bit == 1 { return true }
        flag = flag * 2
        i = i + 1
    }
    false
}

func register_plugin(plugin_registry_state state, int plugin_id, int group, int required_task_mask, bool allowlisted) plugin_registration_result {
    if !state.initialized || plugin_id <= 0 || group < plugin_group_general() || group > plugin_group_lora_resolver() { return plugin_registration_result {state: state, slot: 0 - 1, registered: false, error_code: 1} }
    int i = 0
    while i < state.plugin_count {
        if state.plugin_ids[i] == plugin_id && state.groups[i] == group { return plugin_registration_result {state: state, slot: i, registered: false, error_code: 2} }
        i = i + 1
    }
    if state.plugin_count >= state.config.capacity { return plugin_registration_result {state: state, slot: 0 - 1, registered: false, error_code: 3} }
    int slot = state.plugin_count
    state.plugin_ids[slot] = plugin_id
    state.groups[slot] = group
    state.required_task_masks[slot] = required_task_mask
    if allowlisted { state.allowlisted[slot] = 1 }
    state.statuses[slot] = plugin_status_discovered()
    state.plugin_count = state.plugin_count + 1
    plugin_registration_result {state: state, slot: slot, registered: true, error_code: 0}
}

func activate_plugin(plugin_registry_state state, int slot) plugin_registry_state {
    if slot < 0 || slot >= state.plugin_count || state.statuses[slot] != plugin_status_discovered() { return state }
    bool allowed = true
    if state.groups[slot] == plugin_group_endpoint() && (!state.config.endpoint_allowlist_configured || state.allowlisted[slot] == 0) { allowed = false }
    if !plugin_tasks_intersect(state.required_task_masks[slot], state.config.supported_task_mask) { allowed = false }
    if allowed {
        state.statuses[slot] = plugin_status_active()
        state.active_count = state.active_count + 1
    } else { state.statuses[slot] = plugin_status_skipped() }
    state
}

func fail_plugin(plugin_registry_state state, int slot) plugin_registry_state {
    if slot < 0 || slot >= state.plugin_count { return state }
    if state.statuses[slot] == plugin_status_active() && state.active_count > 0 { state.active_count = state.active_count - 1 }
    state.statuses[slot] = plugin_status_failed()
    state.failed_count = state.failed_count + 1
    state
}
