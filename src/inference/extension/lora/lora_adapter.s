package neurx.lora.lora_adapter

use std.slices
use std.option.option
use std.result.result
use std.map.map

use neurx.lora.lora_config::{lora_config, lora_config_error}
use neurx.lora.weight_fusion::{compute_lora_delta, weight_fusion_engine}

struct lora_adapter_error {
    code: string
    message: string
}

struct lora_adapter {
    name: string
    config: *lora_config
    weights: map[string, (float[][], float[][])]
    is_loaded: bool
    fused: bool
    fusion_engine: option[*weight_fusion_engine]
    metadata: map[string, string]
}

func new(string name, *lora_config config) *lora_adapter {
    lora_adapter {
        name: name,
        config: config,
        weights: map[string, (float[][], float[][])]()
        is_loaded: false,
        fused: false,
        fusion_engine: option::none,
        metadata: map[string, string]()
    }
}

func (lora_adapter* adapter) add_module_weights(
    module_name: string,
    lora_a: *float[][],
    lora_b: *float[][]
) ((), string) {
    if !adapter.config.is_target_module(module_name) {
        return (), "NOT_TARGET_MODULE: Module " + module_name + " is not a target module for this adapter"
    }

    if len(lora_a) == 0 || len(lora_b) == 0 {
        return (), "INVALID_WEIGHTS: LoRA weights cannot be empty"
    }

    adapter.weights.insert(module_name, (lora_a, lora_b))
    return (), ""
}

func (lora_adapter* adapter) get_module_weights(
    module_name: string
) option[(float[][], float[][])] {
    adapter.weights.get(module_name)
}

func (lora_adapter* adapter) remove_module_weights(
    module_name: string
) ((), string) {
    if !adapter.weights.contains(module_name) {
        return (), "MODULE_NOT_FOUND: Weights not found for module: " + module_name
    }

    adapter.weights.remove(module_name)
    return (), ""
}

func (lora_adapter* adapter) apply_lora(
    module_name: string,
    input: *float[],
    scale: float
) (*float[], string) {
    switch adapter.weights.get(module_name) {
        option::some((lora_a, lora_b)) : {
            scaling := adapter.config.get_lora_scaling() * scale

            intermediate := float[]()
            if len(lora_a) > 0 && len(input) > 0 {
                j := 0
                for j < lora_a[0].len() {
                    sum := 0.0
                    k := 0
                    for k < len(input) && k < len(lora_a) {
                        sum = sum + input[k] * lora_a[k][j]
                        k = k + 1
                    }
                    intermediate = append(intermediate, sum)
                    j = j + 1
                }
            }

            output := float[]()
            if len(lora_b) > 0 {
                j := 0
                for j < lora_b[0].len() {
                    sum := 0.0
                    k := 0
                    for k < len(intermediate) && k < len(lora_b) {
                        sum = sum + intermediate[k] * lora_b[k][j]
                        k = k + 1
                    }
                    output = append(output, sum * scaling)
                    j = j + 1
                }
            }

            return output, ""
        },
        option::none: {
            return nil, "MODULE_NOT_FOUND: LoRA weights not found for module: " + module_name
        },
    }
}

func (lora_adapter* adapter) apply_lora_batch(
    module_name: string,
    inputs: **float[][],
    scale: float
) (**float[][], string) {
    outputs := *float[[]]()

    i := 0
    for i < len(inputs) {
        output, err := adapter.apply_lora(module_name, inputs[i], scale)
        if err != "" {
            return nil, err
        }
        outputs = append(outputs, output)
        i = i + 1
    }

    return outputs, ""
}

func (lora_adapter* adapter) fuse_weights(
    original_weights: *map[string, *float[][]]
) ((), string) {
    if adapter.fused {
        return (), "ALREADY_FUSED: Adapter weights are already fused"
    }

    engine := weight_fusion_engine::new(
        adapter.config.lora_rank,
        adapter.config.lora_alpha as float
    )

    for module_name in adapter.weights.keys() {
        switch adapter.weights.get(module_name) {
            option::some((lora_a, lora_b)) : {
                scaling := adapter.config.get_lora_scaling()
                delta := compute_lora_delta(lora_a, lora_b, scaling)

                switch original_weights.get(module_name) {
                    option::some(orig) : {
                        engine.fuse_weights(module_name, orig, delta)
                    },
                    option::none : {
                        return (), "MISSING_WEIGHTS: Original weights not found for module: " + module_name
                    },
                }
            },
            option::none : {},
        }
    }

    adapter.fusion_engine = option::some(*engine)
    adapter.fused = true
    return (), ""
}

func (lora_adapter* adapter) unfuse_weights(
    original_weights: *map[string, *float[][]]
) ((), string) {
    if !adapter.fused {
        return (), "NOT_FUSED: Adapter weights are not fused"
    }

    adapter.fused = false
    adapter.fusion_engine = option::none

    return (), ""
}

func (lora_adapter* adapter) is_fused() bool {
    adapter.fused
}

func (lora_adapter* adapter) get_info() string {
    info := "LoRA Adapter: " + adapter.name + "\n"
    info = info + "  Config: rank=" + adapter.config.lora_rank.to_string() +
        ", alpha=" + adapter.config.lora_alpha.to_string() + "\n"
    info = info + "  Modules: " + len(adapter.weights).to_string() + "\n"
    info = info + "  Fused: " + adapter.fused.to_string() + "\n"
    info
}

func (lora_adapter* adapter) get_size_mb() int {
    total := 0

    for module_name in adapter.weights.keys() {
        switch adapter.weights.get(module_name) {
            option::some((lora_a, lora_b)) : {
                a_size := len(lora_a) *
                    (if len(lora_a) > 0 { lora_a[0].len() } else { 0 }) * 4
                b_size := len(lora_b) *
                    (if len(lora_b) > 0 { lora_b[0].len() } else { 0 }) * 4
                total = total + a_size + b_size
            },
            option::none : {},
        }
    }

    total / 1024 / 1024
}

func (lora_adapter* adapter) get_module_names() *string[] {
    names := string[]()
    for name in adapter.weights.keys() {
        names = append(names, name)
    }
    names
}

func (lora_adapter* adapter) set_metadata(string key, string value) {
    adapter.metadata.insert(key, value)
}

func (lora_adapter* adapter) get_metadata(string key) option[string] {
    adapter.metadata.get(key)
}

func (lora_adapter* adapter) validate() ((), string) {
    if len(adapter.name) == 0 {
        return (), "INVALID_NAME: Adapter name cannot be empty"
    }

    for module_name in adapter.weights.keys() {
        switch adapter.weights.get(module_name) {
            option::some((lora_a, lora_b)) : {
                if len(lora_a) == 0 || len(lora_b) == 0 {
                    return (), "INVALID_WEIGHTS: Empty weights for module: " + module_name
                }

                if lora_a[0].len() != len(lora_b) {
                    return (), "SHAPE_MISMATCH: LoRA A and B shape mismatch for module: " + module_name
                }
            },
            option::none : {},
        }
    }

    return (), ""
}
