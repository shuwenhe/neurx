package neurx.inference.sglang.model_kernel_registry

func model_family_generic() int { 1 }

func model_family_deepseek_v2() int { 2 }

func model_family_deepseek_v4() int { 3 }

func model_family_qwen3_moe() int { 4 }

func model_family_mimo_v2() int { 5 }

func model_family_mamba() int { 6 }

func kernel_attention() int { 1 }

func kernel_moe() int { 2 }

func kernel_rms_norm() int { 3 }

func kernel_rotary() int { 4 }

func kernel_state_space() int { 5 }

func kernel_compressed_kv() int { 6 }

struct model_kernel_registry_config {
    int capacity
    int platform_mask
}

struct model_kernel_registry_state {
    model_kernel_registry_config config
    []int kernel_ids
    []int model_families
    []int kernel_types
    []int platform_masks
    []int minimum_sm
    []int maximum_sequence_lengths
    []int supports_prefill
    []int supports_decode
    []int supports_tbo
    []int priorities
    []int enabled
    int kernel_count
    int selected_count
    int fallback_count
}

struct model_kernel_selection {
    model_kernel_registry_state state
    int kernel_id
    int priority
    bool fallback
    bool supported
}

func kernel_int_array(int capacity) []int {
    []int values = []int{cap: capacity}
    int i = 0
    while i < capacity { values[i] = 0; i = i + 1 }
    values
}

func new_model_kernel_registry(model_kernel_registry_config config) model_kernel_registry_state {
    if config.capacity <= 0 { config.capacity = 1 }
    if config.capacity > 2048 { config.capacity = 2048 }
    model_kernel_registry_state {config: config, kernel_ids: kernel_int_array(config.capacity), model_families: kernel_int_array(config.capacity), kernel_types: kernel_int_array(config.capacity), platform_masks: kernel_int_array(config.capacity), minimum_sm: kernel_int_array(config.capacity), maximum_sequence_lengths: kernel_int_array(config.capacity), supports_prefill: kernel_int_array(config.capacity), supports_decode: kernel_int_array(config.capacity), supports_tbo: kernel_int_array(config.capacity), priorities: kernel_int_array(config.capacity), enabled: kernel_int_array(config.capacity), kernel_count: 0, selected_count: 0, fallback_count: 0}
}

func kernel_find(model_kernel_registry_state state, int kernel_id) int {
    int i = 0
    while i < state.kernel_count {
        if state.kernel_ids[i] == kernel_id { return i }
        i = i + 1
    }
    0 - 1
}

func kernel_register(model_kernel_registry_state state, int kernel_id, int model_family, int kernel_type, int platform_mask, int minimum_sm, int maximum_sequence_length, bool prefill, bool decode, bool tbo, int priority) model_kernel_registry_state {
    if kernel_id <= 0 || kernel_type < kernel_attention() || kernel_type > kernel_compressed_kv() || state.kernel_count >= state.config.capacity || kernel_find(state, kernel_id) >= 0 { return state }
    int slot = state.kernel_count
    state.kernel_ids[slot] = kernel_id
    state.model_families[slot] = model_family
    state.kernel_types[slot] = kernel_type
    state.platform_masks[slot] = platform_mask
    state.minimum_sm[slot] = minimum_sm
    state.maximum_sequence_lengths[slot] = maximum_sequence_length
    if prefill { state.supports_prefill[slot] = 1 }
    if decode { state.supports_decode[slot] = 1 }
    if tbo { state.supports_tbo[slot] = 1 }
    state.priorities[slot] = priority
    state.enabled[slot] = 1
    state.kernel_count = state.kernel_count + 1
    state
}

func kernel_platform_matches(int kernel_mask, int runtime_mask) bool {
    int left = kernel_mask
    int right = runtime_mask
    while left > 0 || right > 0 {
        if left % 2 == 1 && right % 2 == 1 { return true }
        left = left / 2
        right = right / 2
    }
    false
}

func kernel_select(model_kernel_registry_state state, int model_family, int kernel_type, int sm_version, int sequence_length, bool prefill, bool require_tbo) model_kernel_selection {
    int selected = 0 - 1
    int generic_selected = 0 - 1
    int best_priority = 0 - 2147483647
    int generic_priority = 0 - 2147483647
    bool fallback = false
    int i = 0
    while i < state.kernel_count {
        bool family_match = state.model_families[i] == model_family
        bool generic_match = state.model_families[i] == model_family_generic()
        bool mode_match = (prefill && state.supports_prefill[i] == 1) || (!prefill && state.supports_decode[i] == 1)
        bool compatible = state.enabled[i] == 1 && state.kernel_types[i] == kernel_type && kernel_platform_matches(state.platform_masks[i], state.config.platform_mask) && sm_version >= state.minimum_sm[i] && sequence_length <= state.maximum_sequence_lengths[i] && mode_match
        if require_tbo && state.supports_tbo[i] == 0 { compatible = false }
        if compatible && family_match && state.priorities[i] > best_priority { selected = i; best_priority = state.priorities[i] }
        if compatible && generic_match && state.priorities[i] > generic_priority { generic_selected = i; generic_priority = state.priorities[i] }
        i = i + 1
    }
    if selected < 0 && generic_selected >= 0 {
        selected = generic_selected
        fallback = true
    }
    if selected < 0 { return model_kernel_selection {state: state, kernel_id: 0, priority: 0, fallback: false, supported: false} }
    state.selected_count = state.selected_count + 1
    if fallback { state.fallback_count = state.fallback_count + 1 }
    model_kernel_selection {state: state, kernel_id: state.kernel_ids[selected], priority: state.priorities[selected], fallback: fallback, supported: true}
}

func kernel_disable(model_kernel_registry_state state, int kernel_id) model_kernel_registry_state {
    int slot = kernel_find(state, kernel_id)
    if slot >= 0 { state.enabled[slot] = 0 }
    state
}
