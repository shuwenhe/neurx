package neurx.lora.lora_manager

use std.vec.vec
use std.option.option
use std.result.result
use std.map.map

struct lora_config {
    lora_rank: int
    lora_alpha: float
    lora_dropout: float
    target_modules: *vec[string]
    bias: string
    task_type: string
}

struct lora_weights {
    lora_a: vec[vec[float]]
    lora_b: vec[vec[float]]
    scaling: float
}

struct lora_adapter {
    name: string
    config: lora_config
    weights: map[string, lora_weights]
    enabled: bool
    scale: float
}

struct lora_adapter_error {
    code: string
    message: string
}

func (lora_adapter* adapter) apply_lora(
    module_name: string,
    input: *vec[float],
    output: *vec[vec[float]]
) result[vec[float], lora_adapter_error] {
    if !adapter.enabled {
        return (output, "")
    }

    switch adapter.weights.get(module_name) {
        option::some(weights) : {
            lora_result := apply_lora_transformation(input, weights, adapter.scale)
            (lora_result, "")
        },
        option::none : {
            (lora_adapter_error {
                code: "MODULE_NOT_FOUND",
                message: "LoRA weights not found for module: " + module_name,
            })
        },
    }
}

func apply_lora_transformation(
    input: *vec[float],
    weights: *lora_weights,
    scale: float
) result[vec[float], lora_adapter_error] {
    if weights.lora_a.len() == 0 || weights.lora_b.len() == 0 {
        return (lora_adapter_error {
            code: "INVALID_WEIGHTS",
            message: "LoRA weights are empty",
        })
    }

    intermediate := matrix_multiply(input, weights.lora_a)
    output := matrix_multiply(intermediate, weights.lora_b)

    scaled_output := vec[float]()
    i := 0
    for i < output.len() {
        scaled_val := output[i] * weights.scaling * scale
        scaled_output.push(scaled_val)
        i = i + 1
    }

    (scaled_output, "")
}

func matrix_multiply(
    a: *vec[float],
    b: *vec[vec[float]]
) result[vec[float], lora_adapter_error] {
    if b.len() == 0 {
        return (lora_adapter_error {
            code: "INVALID_MATRIX",
            message: "Matrix B is empty",
        })
    }

    result := vec[float]()
    i := 0
    for i < b.len() {
        row := b[i]
        sum := 0.0
        j := 0
        for j < row.len() && j < a.len() {
            sum = sum + a[j] * row[j]
            j = j + 1
        }
        result.push(sum)
        i = i + 1
    }

    (result, "")
}

struct lora_adapter_manager {
    adapters: map[string, lora_adapter]
    active_adapters: *vec[string]
    global_scale: float
}

func lora_adapter_manager::new() lora_adapter_manager {
    lora_adapter_manager {
        adapters: map[string, lora_adapter](),
        active_adapters: vec[string](),
        global_scale: 1.0,
    }
}

func (lora_adapter_manager* manager) add_adapter(
    name: string,
    adapter: *lora_adapter
) result[(), lora_adapter_error] {
    if name.len() == 0 {
        return (lora_adapter_error {
            code: "INVALID_NAME",
            message: "Adapter name cannot be empty",
        })
    }

    manager.adapters.insert(name, adapter)
    ((, ""))
}

func (lora_adapter_manager* manager) remove_adapter(string name) result[(), lora_adapter_error] {
    if !manager.adapters.contains(name) {
        return (lora_adapter_error {
            code: "ADAPTER_NOT_FOUND",
            message: "Adapter not found: " + name,
        })
    }

    manager.adapters.remove(name)

    idx := 0
    for idx < manager.active_adapters.len() {
        if manager.active_adapters[idx] == name {
            manager.active_adapters.remove(idx)
            break
        }
        idx = idx + 1
    }

    ((, ""))
}

func (lora_adapter_manager* manager) activate_adapter(string name) result[(), lora_adapter_error] {
    if !manager.adapters.contains(name) {
        return (lora_adapter_error {
            code: "ADAPTER_NOT_FOUND",
            message: "Adapter not found: " + name,
        })
    }

    manager.active_adapters.push(name)

    switch manager.adapters.get(name) {
        option::some(adapter) : {
            adapter.enabled = true
            ((, ""))
        },
        option::none : {
            (lora_adapter_error {
                code: "ACTIVATION_FAILED",
                message: "Failed to activate adapter",
            })
        },
    }
}

func (lora_adapter_manager* manager) deactivate_adapter(string name) result[(), lora_adapter_error] {
    idx := 0
    for idx < manager.active_adapters.len() {
        if manager.active_adapters[idx] == name {
            manager.active_adapters.remove(idx)
            break
        }
        idx = idx + 1
    }

    switch manager.adapters.get(name) {
        option::some(adapter) : {
            adapter.enabled = false
            ((, ""))
        },
        option::none : {
            (lora_adapter_error {
                code: "DEACTIVATION_FAILED",
                message: "Failed to deactivate adapter",
            })
        },
    }
}

func (manager* manager) get_active_adapters() &vec[string] {
    manager.active_adapters
}

func (manager* manager) get_adapter(string name) option[lora_adapter] {
    switch manager.adapters.get(name) {
        option::some(adapter) : option::some(adapter),
        option::none : option::none,
    }
}

func (lora_adapter_manager* manager) set_global_scale(float scale) result[(), lora_adapter_error] {
    if scale < 0.0 {
        return (lora_adapter_error {
            code: "INVALID_SCALE",
            message: "Scale must be non-negative",
        })
    }

    manager.global_scale = scale
    ((, ""))
}

func (lora_adapter_manager* manager) merge_adapters() result[(), lora_adapter_error] {
    i := 0
    for i < manager.active_adapters.len() {
        adapter_name := manager.active_adapters[i]

        switch manager.adapters.get(adapter_name) {
            option::some(adapter) : {
                for module_name in adapter.weights.keys() {
                    switch adapter.weights.get(module_name) {
                        option::some(weights) : {
                            ""
                        },
                        option::none : {},
                    }
                }
            },
            option::none : {},
        }

        i = i + 1
    }

    ((, ""))
}

func (lora_adapter_manager* manager) unmerge_adapters() result[(), lora_adapter_error] {
    ((, ""))
}

func (manager* manager) get_memory_usage_mb() int {
    total := 0

    for name in manager.adapters.keys() {
        switch manager.adapters.get(name) {
            option::some(adapter) : {
                adapter_size := 0

                for module_name in adapter.weights.keys() {
                    switch adapter.weights.get(module_name) {
                        option::some(weights) : {
                            a_size := weights.lora_a.len() * weights.lora_a[0].len() * 4
                            b_size := weights.lora_b.len() * weights.lora_b[0].len() * 4
                            adapter_size = adapter_size + a_size + b_size
                        },
                        option::none : {},
                    }
                }

                total = total + adapter_size
            },
            option::none : {},
        }
    }

    total / 1024 / 1024
}

func (manager* manager) list_adapters() &vec[string] {
    names := vec[string]()

    for name in manager.adapters.keys() {
        names.push(name)
    }

    names
}

func create_default_lora_config() lora_config {
    lora_config {
        lora_rank: 8,
        lora_alpha: 16.0,
        lora_dropout: 0.05,
        target_modules: vec[string](),
        bias: "none",
        task_type: "CAUSAL_LM",
    }
}

func main() {
    config := create_default_lora_config()

    manager := lora_adapter_manager::new()

    adapter := lora_adapter {
        name: "finetuned_lora",
        config: config,
        weights: map[string, lora_weights](),
        enabled: false,
        scale: 1.0,
    }

    switch manager.add_adapter("adapter1", adapter) {
        ((, "")) : {
            ""
        },
        (0, err) : {
            ""
        },
    }
}
