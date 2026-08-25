package neurx.lora.weight_fusion

use std.vec.vec
use std.option.option
use std.result.result
use std.map.map

struct fusion_error {
    code: string
    message: string
}

struct weight_update {
    module_name: string
    delta: *vec[vec[float]]
    scale: float
}

struct weight_fusion_engine {
    lora_rank: int
    lora_alpha: float
    scaling_factor: float
    fused: map[string, &vec[vec[float]]]
}

func weight_fusion_engine::new(lora_rank: int, lora_alpha: float) weight_fusion_engine {
    weight_fusion_engine {
        lora_rank: lora_rank,
        lora_alpha: lora_alpha,
        scaling_factor: lora_alpha / lora_rank as float,
        fused: map[string, &vec[vec[float]]](),
    }
}

func compute_lora_delta(
    lora_a: *vec[vec[float]],
    lora_b: *vec[vec[float]],
    scaling: float
) result[&vec[vec[float]], fusion_error] {
    if lora_a.len() == 0 || lora_b.len() == 0 {
        return (fusion_error {
            code: "INVALID_MATRIX",
            message: "LoRA matrices cannot be empty",
        })
    }

    if lora_a[0].len() == 0 || lora_b[0].len() == 0 {
        return (fusion_error {
            code: "INVALID_MATRIX",
            message: "LoRA matrix dimensions are invalid",
        })
    }

    let rank = lora_a[0].len()
    if lora_b.len() != rank {
        return (fusion_error {
            code: "DIMENSION_MISMATCH",
            message: "LoRA A and B dimension mismatch: " +
                     rank.to_string() + " vs " + lora_b.len().to_string(),
        })
    }

    let mut delta = vec[vec[float]]()

    let i = 0
    while i < lora_a.len() {
        let row_a = lora_a[i]
        let mut delta_row = vec[float]()

        let j = 0
        while j < lora_b[0].len() {
            let mut sum = 0.0

            let k = 0
            while k < rank {
                sum = sum + row_a[k] * lora_b[k][j]
                k = k + 1
            }

            delta_row.push(sum * scaling)
            j = j + 1
        }

        delta.push(delta_row)
        i = i + 1
    }

    (delta, "")
}

func (mut weight_fusion_engine* engine) fuse_weights(
    module_name: string,
    original_weights: *vec[vec[float]],
    lora_delta: *vec[vec[float]]
) result[(), fusion_error] {
    if original_weights.len() != lora_delta.len() {
        return (fusion_error {
            code: "SHAPE_MISMATCH",
            message: "Original and LoRA delta shape mismatch",
        })
    }

    if original_weights[0].len() != lora_delta[0].len() {
        return (fusion_error {
            code: "SHAPE_MISMATCH",
            message: "Original and LoRA delta width mismatch",
        })
    }

    let mut fused = vec[vec[float]]()

    let i = 0
    while i < original_weights.len() {
        let orig_row = original_weights[i]
        let delta_row = lora_delta[i]
        let mut fused_row = vec[float]()

        let j = 0
        while j < orig_row.len() {
            fused_row.push(orig_row[j] + delta_row[j])
            j = j + 1
        }

        fused.push(fused_row)
        i = i + 1
    }

    engine.fused.insert(module_name, fused)
    ((, ""))
}

func (mut weight_fusion_engine* engine) unfuse_weights(
    module_name: string,
    fused_weights: *vec[vec[float]],
    lora_delta: *vec[vec[float]]
) result[&vec[vec[float]], fusion_error] {
    if fused_weights.len() != lora_delta.len() {
        return (fusion_error {
            code: "SHAPE_MISMATCH",
            message: "Fused and LoRA delta shape mismatch",
        })
    }

    let mut original = vec[vec[float]]()

    let i = 0
    while i < fused_weights.len() {
        let fused_row = fused_weights[i]
        let delta_row = lora_delta[i]
        let mut orig_row = vec[float]()

        let j = 0
        while j < fused_row.len() {
            orig_row.push(fused_row[j] - delta_row[j])
            j = j + 1
        }

        original.push(orig_row)
        i = i + 1
    }

    engine.fused.remove(module_name)
    (original, "")
}

func (weight_fusion_engine* engine) get_fused_weights(
    module_name: string
) option[&vec[vec[float]]] {
    engine.fused.get(module_name)
}

func (weight_fusion_engine* engine) is_fused(module_name: string) bool {
    engine.fused.contains(module_name)
}

func (weight_fusion_engine* engine) get_fused_modules() &vec[string] {
    let mut modules = vec[string]()

    for name in engine.fused.keys() {
        modules.push(name)
    }

    modules
}

func (mut weight_fusion_engine* engine) clear_fused_weights() {
    engine.fused.clear()
}

func (weight_fusion_engine* engine) get_fused_weights_size_mb() int {
    let mut total_size = 0

    for name in engine.fused.keys() {
        switch engine.fused.get(name) {
            option::some(weights) : {
                let rows = weights.len()
                let cols = if rows > 0 { weights[0].len() } else { 0 }

                total_size = total_size + rows * cols * 4
            },
            option::none : {},
        }
    }

    total_size / 1024 / 1024
}

func fuse_multiple_adapters(
    original_weights: *map[string, &vec[vec[float]]],
    lora_deltas: *vec[&map[string, &vec[vec[float]]]],
    adapter_scales: *vec[float]
) result[&map[string, &vec[vec[float]]], fusion_error] {
    if lora_deltas.len() != adapter_scales.len() {
        return (fusion_error {
            code: "LENGTH_MISMATCH",
            message: "LoRA deltas and scales length mismatch",
        })
    }

    let mut result_weights = map[string, &vec[vec[float]]]()

    for module_name in original_weights.keys() {
        switch original_weights.get(module_name) {
            option::some(orig) : {
                let mut combined_delta = vec[vec[float]]()

                let i = 0
                while i < orig.len() {
                    let mut row = vec[float]()
                    let j = 0
                    while j < orig[0].len() {
                        row.push(0.0)
                        j = j + 1
                    }
                    combined_delta.push(row)
                    i = i + 1
                }

                let adapter_idx = 0
                while adapter_idx < lora_deltas.len() {
                    let deltas = lora_deltas[adapter_idx]
                    let scale = adapter_scales[adapter_idx]

                    switch deltas.get(module_name) {
                        option::some(delta) : {
                            let i = 0
                            while i < delta.len() {
                                let j = 0
                                while j < delta[0].len() {
                                    combined_delta[i][j] = combined_delta[i][j] + delta[i][j] * scale
                                    j = j + 1
                                }
                                i = i + 1
                            }
                        },
                        option::none : {},
                    }

                    adapter_idx = adapter_idx + 1
                }

                let mut fused = vec[vec[float]]()
                let i = 0
                while i < orig.len() {
                    let mut row = vec[float]()
                    let j = 0
                    while j < orig[0].len() {
                        row.push(orig[i][j] + combined_delta[i][j])
                        j = j + 1
                    }
                    fused.push(row)
                    i = i + 1
                }

                result_weights.insert(module_name, fused)
            },
            option::none : {},
        }
    }

    (result_weights, "")
}
