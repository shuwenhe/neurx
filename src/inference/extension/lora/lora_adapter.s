package neurx.lora.lora_adapter

use std.vec.vec
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
    weights: map[string, (vec[vec[float]], vec[vec[float]])]
    is_loaded: bool
    fused: bool
    fusion_engine: option[&weight_fusion_engine]
    metadata: map[string, string]
}

impl lora_adapter {

    func new(string name, *lora_config config) lora_adapter {
        lora_adapter {
            name: name,
            config: config,
            weights: map[string, (vec[vec[float]], vec[vec[float]])](),
            is_loaded: false,
            fused: false,
            fusion_engine: option::none,
            metadata: map[string, string](),
        }
    }

    func(mut lora_adapter* adapter) add_module_weights(
        module_name: string,
        lora_a: *vec[vec[float]],
        lora_b: *vec[vec[float]]
    ) result[(), lora_adapter_error] {
        if !adapter.config.is_target_module(module_name) {
            return (lora_adapter_error {
                code: "NOT_TARGET_MODULE",
                message: "Module " + module_name + " is not a target module for this adapter",
            })
        }

        if lora_a.len() == 0 || lora_b.len() == 0 {
            return (lora_adapter_error {
                code: "INVALID_WEIGHTS",
                message: "LoRA weights cannot be empty",
            })
        }

        adapter.weights.insert(module_name, (lora_a, lora_b))
        ((, ""))
    }

    func(lora_adapter* adapter) get_module_weights(
        module_name: string
    ) option[(vec[vec[float]], vec[vec[float]])] {
        adapter.weights.get(module_name)
    }

    func(mut lora_adapter* adapter) remove_module_weights(
        module_name: string
    ) result[(), lora_adapter_error] {
        if !adapter.weights.contains(module_name) {
            return (lora_adapter_error {
                code: "MODULE_NOT_FOUND",
                message: "Weights not found for module: " + module_name,
            })
        }

        adapter.weights.remove(module_name)
        ((, ""))
    }

    func(lora_adapter* adapter) apply_lora(
        module_name: string,
        input: *vec[float],
        scale: float
    ) result[&vec[float], lora_adapter_error] {
        switch adapter.weights.get(module_name) {
            option::some((lora_a, lora_b)) : {

                scaling := adapter.config.get_lora_scaling() * scale

                intermediate := vec[float]()
                if lora_a.len() > 0 && input.len() > 0 {
                    j := 0
                    for j < lora_a[0].len() {
                        sum := 0.0
                        k := 0
                        for k < input.len() && k < lora_a.len() {
                            sum = sum + input[k] * lora_a[k][j]
                            k = k + 1
                        }
                        intermediate.push(sum)
                        j = j + 1
                    }
                }

                output := vec[float]()
                if lora_b.len() > 0 {
                    j := 0
                    for j < lora_b[0].len() {
                        sum := 0.0
                        k := 0
                        for k < intermediate.len() && k < lora_b.len() {
                            sum = sum + intermediate[k] * lora_b[k][j]
                            k = k + 1
                        }
                        output.push(sum * scaling)
                        j = j + 1
                    }
                }

                (output, "")
            },
            option::none : {
                (lora_adapter_error {
                    code: "MODULE_NOT_FOUND",
                    message: "LoRA weights not found for module: " + module_name,
                })
            },
        }
    }

    func(lora_adapter* adapter) apply_lora_batch(
        module_name: string,
        inputs: *vec[&vec[float]],
        scale: float
    ) result[&vec[&vec[float]], lora_adapter_error] {
        outputs := vec[&vec[float]]()

        i := 0
        for i < inputs.len() {
            output := adapter.apply_lora(module_name, inputs[i], scale)
            outputs.push(output)
            i = i + 1
        }

        (outputs, "")
    }

    func(mut lora_adapter* adapter) fuse_weights(
        original_weights: *map[string, &vec[vec[float]]]
    ) result[(), lora_adapter_error] {
        if adapter.fused {
            return (lora_adapter_error {
                code: "ALREADY_FUSED",
                message: "Adapter weights are already fused",
            })
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
                            return (lora_adapter_error {
                                code: "MISSING_WEIGHTS",
                                message: "Original weights not found for module: " + module_name,
                            })
                        },
                    }
                },
                option::none : {},
            }
        }

        adapter.fusion_engine = option::some(&engine)
        adapter.fused = true
        ((, ""))
    }

    func(mut lora_adapter* adapter) unfuse_weights(
        original_weights: *map[string, &vec[vec[float]]]
    ) result[(), lora_adapter_error] {
        if !adapter.fused {
            return (lora_adapter_error {
                code: "NOT_FUSED",
                message: "Adapter weights are not fused",
            })
        }

        adapter.fused = false
        adapter.fusion_engine = option::none

        ((, ""))
    }

    func(lora_adapter* adapter) is_fused() bool {
        adapter.fused
    }

    func(lora_adapter* adapter) get_info() string {
        info := "LoRA Adapter: " + adapter.name + "\n"
        info = info + "  Config: rank=" + adapter.config.lora_rank.to_string() +
                      ", alpha=" + adapter.config.lora_alpha.to_string() + "\n"
        info = info + "  Modules: " + adapter.weights.len().to_string() + "\n"
        info = info + "  Fused: " + adapter.fused.to_string() + "\n"
        info
    }

    func(lora_adapter* adapter) get_size_mb() int {
        total := 0

        for module_name in adapter.weights.keys() {
            switch adapter.weights.get(module_name) {
                option::some((lora_a, lora_b)) : {
                    a_size := lora_a.len() *
                                 (if lora_a.len() > 0 { lora_a[0].len() } else { 0 }) * 4
                    b_size := lora_b.len() *
                                 (if lora_b.len() > 0 { lora_b[0].len() } else { 0 }) * 4
                    total = total + a_size + b_size
                },
                option::none : {},
            }
        }

        total / 1024 / 1024
    }

    func(lora_adapter* adapter) get_module_names() &vec[string] {
        names := vec[string]()
        for name in adapter.weights.keys() {
            names.push(name)
        }
        names
    }

    func(mut lora_adapter* adapter) set_metadata(string key, string value) {
        adapter.metadata.insert(key, value)
    }

    func(lora_adapter* adapter) get_metadata(string key) option[string] {
        adapter.metadata.get(key)
    }

    func(lora_adapter* adapter) validate() result[(), lora_adapter_error] {
        if adapter.name.len() == 0 {
            return (lora_adapter_error {
                code: "INVALID_NAME",
                message: "Adapter name cannot be empty",
            })
        }

        for module_name in adapter.weights.keys() {
            switch adapter.weights.get(module_name) {
                option::some((lora_a, lora_b)) : {
                    if lora_a.len() == 0 || lora_b.len() == 0 {
                        return (lora_adapter_error {
                            code: "INVALID_WEIGHTS",
                            message: "Empty weights for module: " + module_name,
                        })
                    }

                    if lora_a[0].len() != lora_b.len() {
                        return (lora_adapter_error {
                            code: "SHAPE_MISMATCH",
                            message: "LoRA A and B shape mismatch for module: " + module_name,
                        })
                    }
                },
                option::none : {},
            }
        }

        ((, ""))
    }
}
