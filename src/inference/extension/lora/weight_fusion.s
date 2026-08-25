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

func weight_fusion_engine::new(int lora_rank, float lora_alpha) weight_fusion_engine {
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

    rank := lora_a[0].len()
    if lora_b.len() != rank {
        return (fusion_error {
            code: "DIMENSION_MISMATCH",
            message: "LoRA A and B dimension mismatch: " +
                     rank.to_string() + " vs " + lora_b.len().to_string(),
        })
    }

    delta := vec[vec[float]]()

    i := 0
    for i < lora_a.len() {
        row_a := lora_a[i]
        delta_row := vec[float]()

        j := 0
        for j < lora_b[0].len() {
            sum := 0.0

            k := 0
            for k < rank {
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

func (weight_fusion_engine* engine) fuse_weights(
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

    fused := vec[vec[float]]()

    i := 0
    for i < original_weights.len() {
        orig_row := original_weights[i]
        delta_row := lora_delta[i]
        fused_row := vec[float]()

        j := 0
        for j < orig_row.len() {
            fused_row.push(orig_row[j] + delta_row[j])
            j = j + 1
        }

        fused.push(fused_row)
        i = i + 1
    }

    engine.fused.insert(module_name, fused)
    ((, ""))
}

func (weight_fusion_engine* engine) unfuse_weights(
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

    original := vec[vec[float]]()

    i := 0
    for i < fused_weights.len() {
        fused_row := fused_weights[i]
        delta_row := lora_delta[i]
        orig_row := vec[float]()

        j := 0
        for j < fused_row.len() {
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

func (weight_fusion_engine* engine) is_fused(string module_name) bool {
    engine.fused.contains(module_name)
}

func (weight_fusion_engine* engine) get_fused_modules() &vec[string] {
    modules := vec[string]()

    for name in engine.fused.keys() {
        modules.push(name)
    }

    modules
}

func (weight_fusion_engine* engine) clear_fused_weights() {
    engine.fused.clear()
}

func (weight_fusion_engine* engine) get_fused_weights_size_mb() int {
    total_size := 0

    for name in engine.fused.keys() {
        switch engine.fused.get(name) {
            option::some(weights) : {
                rows := weights.len()
                cols := if rows > 0 { weights[0].len() } else { 0 }

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

    result_weights := map[string, &vec[vec[float]]]()

    for module_name in original_weights.keys() {
        switch original_weights.get(module_name) {
            option::some(orig) : {
                combined_delta := vec[vec[float]]()

                i := 0
                for i < orig.len() {
                    row := vec[float]()
                    j := 0
                    for j < orig[0].len() {
                        row.push(0.0)
                        j = j + 1
                    }
                    combined_delta.push(row)
                    i = i + 1
                }

                adapter_idx := 0
                for adapter_idx < lora_deltas.len() {
                    deltas := lora_deltas[adapter_idx]
                    scale := adapter_scales[adapter_idx]

                    switch deltas.get(module_name) {
                        option::some(delta) : {
                            i := 0
                            for i < delta.len() {
                                j := 0
                                for j < delta[0].len() {
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

                fused := vec[vec[float]]()
                i := 0
                for i < orig.len() {
                    row := vec[float]()
                    j := 0
                    for j < orig[0].len() {
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
