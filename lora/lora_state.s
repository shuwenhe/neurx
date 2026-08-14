package neurx.lora.lora_state

use std.vec.vec
use std.option.option
use std.result.result
use std.map.map

struct lora_request_state {
    request_id: string
    adapter_names: &vec[string]
    adapter_scales: &vec[float]
    is_active: bool
    created_at: int
    updated_at: int
}

struct lora_state_error {
    code: string
    message: string
}

struct lora_state_manager {
    request_states: map[string, lora_request_state]
    adapter_cache: map[string, &vec[vec[float]]]
    max_adapters_per_request: int
    enable_cache: bool
}

func lora_state_manager::new(max_adapters: int) lora_state_manager {
    lora_state_manager {
        request_states: map[string, lora_request_state](),
        adapter_cache: map[string, &vec[vec[float]]](),
        max_adapters_per_request: max_adapters,
        enable_cache: true,
    }
}

func (manager: &mut lora_state_manager) create_request_state(
    request_id: string,
    adapter_names: &vec[string],
    adapter_scales: &vec[float]
) result[(), lora_state_error] {

    if request_id.len() == 0 {
        return result::err(lora_state_error {
            code: "INVALID_REQUEST_ID",
            message: "Request ID cannot be empty",
        })
    }

    if adapter_names.len() != adapter_scales.len() {
        return result::err(lora_state_error {
            code: "LENGTH_MISMATCH",
            message: "Adapter names and scales length mismatch",
        })
    }

    if adapter_names.len() > manager.max_adapters_per_request {
        return result::err(lora_state_error {
            code: "TOO_MANY_ADAPTERS",
            message: "Number of adapters exceeds limit: " +
                     adapter_names.len().to_string() + " > " +
                     manager.max_adapters_per_request.to_string(),
        })
    }

    let i = 0
    while i < adapter_scales.len() {
        if adapter_scales[i] < 0.0 {
            return result::err(lora_state_error {
                code: "INVALID_SCALE",
                message: "Adapter scale cannot be negative",
            })
        }
        i = i + 1
    }

    if manager.request_states.contains(request_id) {
        return result::err(lora_state_error {
            code: "DUPLICATE_REQUEST",
            message: "Request state already exists for ID: " + request_id,
        })
    }

    let now = 0

    let state = lora_request_state {
        request_id: request_id,
        adapter_names: adapter_names,
        adapter_scales: adapter_scales,
        is_active: true,
        created_at: now,
        updated_at: now,
    }

    manager.request_states.insert(request_id, state)
    result::ok(())
}

func (manager: &lora_state_manager) get_request_state(
    request_id: string
) option[lora_request_state] {
    manager.request_states.get(request_id)
}

func (manager: &mut lora_state_manager) update_adapter_scales(
    request_id: string,
    new_scales: &vec[float]
) result[(), lora_state_error] {
    switch manager.request_states.get(request_id) {
        option::some(mut state) : {
            if new_scales.len() != state.adapter_names.len() {
                return result::err(lora_state_error {
                    code: "LENGTH_MISMATCH",
                    message: "New scales length does not match adapters",
                })
            }

            state.adapter_scales = new_scales
            state.updated_at = 0

            manager.request_states.insert(request_id, state)
            result::ok(())
        },
        option::none : {
            result::err(lora_state_error {
                code: "REQUEST_NOT_FOUND",
                message: "Request state not found for ID: " + request_id,
            })
        },
    }
}

func (manager: &mut lora_state_manager) switch_adapters(
    request_id: string,
    new_adapter_names: &vec[string],
    new_scales: &vec[float]
) result[(), lora_state_error] {
    if new_adapter_names.len() != new_scales.len() {
        return result::err(lora_state_error {
            code: "LENGTH_MISMATCH",
            message: "Adapter names and scales length mismatch",
        })
    }

    if new_adapter_names.len() > manager.max_adapters_per_request {
        return result::err(lora_state_error {
            code: "TOO_MANY_ADAPTERS",
            message: "Number of adapters exceeds limit",
        })
    }

    switch manager.request_states.get(request_id) {
        option::some(mut state) : {
            state.adapter_names = new_adapter_names
            state.adapter_scales = new_scales
            state.updated_at = 0

            manager.request_states.insert(request_id, state)

            manager.clear_request_cache(request_id)?

            result::ok(())
        },
        option::none : {
            result::err(lora_state_error {
                code: "REQUEST_NOT_FOUND",
                message: "Request state not found for ID: " + request_id,
            })
        },
    }
}

func (manager: &mut lora_state_manager) remove_request_state(
    request_id: string
) result[(), lora_state_error] {
    if !manager.request_states.contains(request_id) {
        return result::err(lora_state_error {
            code: "REQUEST_NOT_FOUND",
            message: "Request state not found for ID: " + request_id,
        })
    }

    manager.request_states.remove(request_id)
    manager.clear_request_cache(request_id)?

    result::ok(())
}

func (manager: &mut lora_state_manager) activate_request(
    request_id: string
) result[(), lora_state_error] {
    switch manager.request_states.get(request_id) {
        option::some(mut state) : {
            state.is_active = true
            state.updated_at = 0
            manager.request_states.insert(request_id, state)
            result::ok(())
        },
        option::none : {
            result::err(lora_state_error {
                code: "REQUEST_NOT_FOUND",
                message: "Request state not found for ID: " + request_id,
            })
        },
    }
}

func (manager: &mut lora_state_manager) deactivate_request(
    request_id: string
) result[(), lora_state_error] {
    switch manager.request_states.get(request_id) {
        option::some(mut state) : {
            state.is_active = false
            state.updated_at = 0
            manager.request_states.insert(request_id, state)
            result::ok(())
        },
        option::none : {
            result::err(lora_state_error {
                code: "REQUEST_NOT_FOUND",
                message: "Request state not found for ID: " + request_id,
            })
        },
    }
}

func (manager: &lora_state_manager) is_request_active(request_id: string) bool {
    switch manager.request_states.get(request_id) {
        option::some(state) : state.is_active,
        option::none : false,
    }
}

func (manager: &lora_state_manager) get_active_requests() &vec[string] {
    let mut active = vec[string]()

    for req_id in manager.request_states.keys() {
        switch manager.request_states.get(req_id) {
            option::some(state) : {
                if state.is_active {
                    active.push(req_id)
                }
            },
            option::none : {},
        }
    }

    active
}

func (manager: &mut lora_state_manager) cache_fused_weights(
    cache_key: string,
    weights: &vec[vec[float]]
) result[(), lora_state_error] {
    if !manager.enable_cache {
        return result::ok(())
    }

    if cache_key.len() == 0 {
        return result::err(lora_state_error {
            code: "INVALID_CACHE_KEY",
            message: "Cache key cannot be empty",
        })
    }

    manager.adapter_cache.insert(cache_key, weights)
    result::ok(())
}

func (manager: &lora_state_manager) get_cached_weights(
    cache_key: string
) option[&vec[vec[float]]] {
    manager.adapter_cache.get(cache_key)
}

func (manager: &mut lora_state_manager) clear_request_cache(
    request_id: string
) result[(), lora_state_error] {
    let mut keys_to_remove = vec[string]()

    for key in manager.adapter_cache.keys() {
        if key.starts_with(request_id + "_") {
            keys_to_remove.push(key)
        }
    }

    let i = 0
    while i < keys_to_remove.len() {
        manager.adapter_cache.remove(keys_to_remove[i])
        i = i + 1
    }

    result::ok(())
}

func (manager: &mut lora_state_manager) clear_all_cache() {
    manager.adapter_cache.clear()
}

func (manager: &mut lora_state_manager) set_cache_enabled(enabled: bool) {
    manager.enable_cache = enabled
}

func (manager: &lora_state_manager) get_cache_stats() (int, int) {
    let mut total_size_mb = 0

    for key in manager.adapter_cache.keys() {
        switch manager.adapter_cache.get(key) {
            option::some(weights) : {
                let rows = weights.len()
                let cols = if rows > 0 { weights[0].len() } else { 0 }
                total_size_mb = total_size_mb + rows * cols * 4
            },
            option::none : {},
        }
    }

    (manager.adapter_cache.keys().len(), total_size_mb / 1024 / 1024)
}

func (manager: &lora_state_manager) get_request_count() int {
    manager.request_states.len()
}

func (manager: &lora_state_manager) get_active_request_count() int {
    let count = manager.get_active_requests()
    count.len()
}
