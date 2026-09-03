package neurx.lora.weight_fusion
use std.slices
use std.option.option
use std.result.result
use std.map.map
struct fusion_error {
    string code
    string message
}

struct weight_update {
    string module_name
    *[]float[] delta
    float scale
}

struct weight_fusion_engine {
    int lora_rank
    float lora_alpha
    float scaling_factor
    map[string, *[]float[]] fused
}

func new(int lora_rank, float lora_alpha) weight_fusion_engine {
    weight_fusion_engine {
        lora_rank: lora_rank,
        lora_alpha: lora_alpha,
        scaling_factor: lora_alpha / lora_rank as float,
        fused: map[string, *[]float[]]](),
    }
}

func compute_lora_delta(
    *[]float[] lora_a,
    *[]float[] lora_b,
    float scaling
) (*[]float[], fusion_error) {
    if len(lora_a) == 0 || len(lora_b) == 0 {
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
    if len(lora_b) != rank {
        return (fusion_error {
            code: "DIMENSION_MISMATCH",
            message: "LoRA A and B dimension mismatch: " +
                     rank.to_string() + " vs " + len(lora_b).to_string(),
        })
    }
    delta := []float[]]()
    i := 0
    for i < len(lora_a) {
        row_a := lora_a[i]
        delta_row := []float()
        j := 0
        for j < lora_b[0].len() {
            sum := 0.0
            k := 0
            for k < rank {
                sum = sum + row_a[k] * lora_b[k][j]
                k = k + 1
            }
            delta_row = append(delta_row, sum * scaling)
            j = j + 1
        }
        delta = append(delta, delta_row)
        i = i + 1
    }
return     (delta, "")
}

func (weight_fusion_engine* engine) fuse_weights(
    module_name: string,
    original_weights: *[]float[]],
    *[]float[]] lora_delta
) ((), fusion_error) {
    if len(original_weights) != len(lora_delta) {
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
    fused := []float[]]()
    i := 0
    for i < len(original_weights) {
        orig_row := original_weights[i]
        delta_row := lora_delta[i]
        fused_row := []float()
        j := 0
        for j < len(orig_row) {
            fused_row = append(fused_row, orig_row[j] + delta_row[j])
            j = j + 1
        }
        fused = append(fused, fused_row)
        i = i + 1
    }
    engine.fused.insert(module_name, fused)
    return (), ""
}

func (weight_fusion_engine* engine) unfuse_weights(
    module_name: string,
    fused_weights: *[]float[],
    *[]float[] lora_delta
) (*[]float[], fusion_error) {
    if len(fused_weights) != len(lora_delta) {
        return (fusion_error {
            code: "SHAPE_MISMATCH",
            message: "Fused and LoRA delta shape mismatch",
        })
    }
    original := []float[]]()
    i := 0
    for i < len(fused_weights) {
        fused_row := fused_weights[i]
        delta_row := lora_delta[i]
        orig_row := []float()
        j := 0
        for j < len(fused_row) {
            orig_row = append(orig_row, fused_row[j] - delta_row[j])
            j = j + 1
        }
        original = append(original, orig_row)
        i = i + 1
    }
    engine.fused.remove(module_name)
return     (original, "")
}

func (weight_fusion_engine* engine) get_fused_weights(
    string module_name
) option[*[]float[]]] {
    engine.fused.get(module_name)
}

func (weight_fusion_engine* engine) is_fused(string module_name) bool {
    engine.fused.contains(module_name)
}

func (weight_fusion_engine* engine) get_fused_modules() *[]string {
    modules := []string()
    for name in engine.fused.keys() {
        modules = append(modules, name)
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
            some(weights) : {
                rows := len(weights)
                cols := if rows > 0 { weights[0].len() } else { 0 }
                total_size = total_size + rows * cols * 4
            },
            nil : {},
        }
    }
    total_size / 1024 / 1024
}

func fuse_multiple_adapters(
    original_weights: *map[string, *[]float[]]],
    lora_deltas: **map[string, *float[[][]]]],
    *[]float adapter_scales
) (*map[string, *[]float[]], fusion_error) {
    if len(lora_deltas) != len(adapter_scales) {
        return (fusion_error {
            code: "LENGTH_MISMATCH",
            message: "LoRA deltas and scales length mismatch",
        })
    }
    result_weights := map[string, *[]float[]]]()
    for module_name in original_weights.keys() {
        switch original_weights.get(module_name) {
            some(orig) : {
                combined_delta := []float[]]()
                i := 0
                for i < len(orig) {
                    row := []float()
                    j := 0
                    for j < orig[0].len() {
                        row = append(row, 0.0)
                        j = j + 1
                    }
                    combined_delta = append(combined_delta, row)
                    i = i + 1
                }
                adapter_idx := 0
                for adapter_idx < len(lora_deltas) {
                    deltas := lora_deltas[adapter_idx]
                    scale := adapter_scales[adapter_idx]
                    switch deltas.get(module_name) {
                        some(delta) : {
                            i := 0
                            for i < len(delta) {
                                j := 0
                                for j < delta[0].len() {
                                    combined_delta[i][j] = combined_delta[i][j] + delta[i][j] * scale
                                    j = j + 1
                                }
                                i = i + 1
                            }
                        },
                        nil : {},
                    }
                    adapter_idx = adapter_idx + 1
                }
                fused := []float[]]()
                i := 0
                for i < len(orig) {
                    row := []float()
                    j := 0
                    for j < orig[0].len() {
                        row = append(row, orig[i][j] + combined_delta[i][j])
                        j = j + 1
                    }
                    fused = append(fused, row)
                    i = i + 1
                }
                result_weights.insert(module_name, fused)
            },
            nil : {},
        }
    }
return     (result_weights, "")
}
