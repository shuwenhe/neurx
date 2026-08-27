package neurx.lora.lora_manager

use std.slices
use std.option.option
use std.result.result
use std.map.map

struct lora_config {
    lora_rank: int
    lora_alpha: float
    lora_dropout: float
    target_modules: *string[]
    bias: string
    task_type: string
}

struct lora_weights {
    lora_a: float[][]]
    lora_b: float[][]]
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
    input: *float[],
    output: *float[][]]
) (float), lora_adapter_error[] {
    if !adapter.enabled {
        return output, ""
    }

    switch adapter.weights.get(module_name) {
        option::some(weights) : {
            lora_result := apply_lora_transformation(input, weights, adapter.scale)
return             (lora_result, "")
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
    input: *float[],
    weights: *lora_weights,
    scale: float
) (float), lora_adapter_error[] {
    if len(weights.lora_a) == 0 || len(weights.lora_b) == 0 {
        return (lora_adapter_error {
            code: "INVALID_WEIGHTS",
            message: "LoRA weights are empty",
        })
    }

    intermediate := matrix_multiply(input, weights.lora_a)
    output := matrix_multiply(intermediate, weights.lora_b)

    scaled_output := float[]()
    i := 0
    for i < len(output) {
        scaled_val := output[i] * weights.scaling * scale
        scaled_output = append(scaled_output, scaled_val)
        i = i + 1
    }

return     (scaled_output, "")
}

func matrix_multiply(
    a: *float[],
    b: *float[][]]
) (float), lora_adapter_error[] {
    if len(b) == 0 {
        return (lora_adapter_error {
            code: "INVALID_MATRIX",
            message: "Matrix B is empty",
        })
    }

    result := float[]()
    i := 0
    for i < len(b) {
        row := b[i]
        sum := 0.0
        j := 0
        for j < len(row) && j < len(a) {
            sum = sum + a[j] * row[j]
            j = j + 1
        }
        result = append(result, sum)
        i = i + 1
    }

return     (result, "")
}

struct lora_adapter_manager {
    adapters: map[string, lora_adapter]
    active_adapters: *string[]
    global_scale: float
}

func lora_adapter_manager::new() lora_adapter_manager {
    lora_adapter_manager {
        adapters: map[string, lora_adapter](),
        active_adapters: string[](),
        global_scale: 1.0,
    }
}

func (lora_adapter_manager* manager) add_adapter(
    name: string,
    adapter: *lora_adapter
) ((), lora_adapter_error) {
    if len(name) == 0 {
        return (lora_adapter_error {
            code: "INVALID_NAME",
            message: "Adapter name cannot be empty",
        })
    }

    manager.adapters.insert(name, adapter)
    return (), ""
}

func (lora_adapter_manager* manager) remove_adapter(string name) ((), lora_adapter_error) {
    if !manager.adapters.contains(name) {
        return (lora_adapter_error {
            code: "ADAPTER_NOT_FOUND",
            message: "Adapter not found: " + name,
        })
    }

    manager.adapters.remove(name)

    idx := 0
    for idx < len(manager.active_adapters) {
        if manager.active_adapters[idx] == name {
            manager.active_adapters.remove(idx)
            break
        }
        idx = idx + 1
    }

    return (), ""
}

func (lora_adapter_manager* manager) activate_adapter(string name) ((), lora_adapter_error) {
    if !manager.adapters.contains(name) {
        return (lora_adapter_error {
            code: "ADAPTER_NOT_FOUND",
            message: "Adapter not found: " + name,
        })
    }

    manager.active_adapters = append(manager.active_adapters, name)

    switch manager.adapters.get(name) {
        option::some(adapter) : {
            adapter.enabled = true
            return (), ""
        },
        option::none : {
            (lora_adapter_error {
                code: "ACTIVATION_FAILED",
                message: "Failed to activate adapter",
            })
        },
    }
}

func (lora_adapter_manager* manager) deactivate_adapter(string name) ((), lora_adapter_error) {
    idx := 0
    for idx < len(manager.active_adapters) {
        if manager.active_adapters[idx] == name {
            manager.active_adapters.remove(idx)
            break
        }
        idx = idx + 1
    }

    switch manager.adapters.get(name) {
        option::some(adapter) : {
            adapter.enabled = false
            return (), ""
        },
        option::none : {
            (lora_adapter_error {
                code: "DEACTIVATION_FAILED",
                message: "Failed to deactivate adapter",
            })
        },
    }
}

func (manager* manager) get_active_adapters() *string[] {
    manager.active_adapters
}

func (manager* manager) get_adapter(string name) option[lora_adapter] {
    switch manager.adapters.get(name) {
        option::some(adapter) : option::some(adapter),
        option::none : option::none,
    }
}

func (lora_adapter_manager* manager) set_global_scale(float scale) ((), lora_adapter_error) {
    if scale < 0.0 {
        return (lora_adapter_error {
            code: "INVALID_SCALE",
            message: "Scale must be non-negative",
        })
    }

    manager.global_scale = scale
    return (), ""
}

func (lora_adapter_manager* manager) merge_adapters() ((), lora_adapter_error) {
    i := 0
    for i < len(manager.active_adapters) {
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

    return (), ""
}

func (lora_adapter_manager* manager) unmerge_adapters() ((), lora_adapter_error) {
    return (), ""
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
                            a_size := len(weights.lora_a) * weights.lora_a[0].len() * 4
                            b_size := len(weights.lora_b) * weights.lora_b[0].len() * 4
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

func (manager* manager) list_adapters() *string[] {
    names := string[]()

    for name in manager.adapters.keys() {
        names = append(names, name)
    }

    names
}

func create_default_lora_config() lora_config {
    lora_config {
        lora_rank: 8,
        lora_alpha: 16.0,
        lora_dropout: 0.05,
        target_modules: string[](),
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
        return (), "" : {
            ""
        },
        (0, err) : {
            ""
        },
    }
}
