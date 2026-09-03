package neurx.lora.lora_utils
use std.slices
use std.option.option
use std.result.result
use std.map.map
struct lora_utils_error {
    string code
    string message
}

func init_lora_weights_kaiming(
    int in_features,
    int out_features,
    int rank
) (([]float[], []float[]]), lora_utils_error) {
    if in_features <= 0 || out_features <= 0 || rank <= 0 {
        return (lora_utils_error {
            code: "INVALID_DIMS",
            message: "Dimensions must be positive",
        })
    }
    if rank > in_features || rank > out_features {
        return (lora_utils_error {
            code: "INVALID_RANK",
            message: "Rank cannot exceed input or output features",
        })
    }
    fan_in := in_features
    fan_out := out_features
    std := (2.0 / (fan_in as float + fan_out as float)).sqrt()
    lora_a := []float[]]()
    i := 0
    for i < in_features {
        row := []float()
        j := 0
        for j < rank {
            val := gaussian_random(std)
            row = append(row, val)
            j = j + 1
        }
        lora_a = append(lora_a, row)
        i = i + 1
    }
    lora_b := []float[]]()
    i := 0
    for i < rank {
        row := []float()
        j := 0
        for j < out_features {
            row = append(row, 0.0)
            j = j + 1
        }
        lora_b = append(lora_b, row)
        i = i + 1
    }
    ((lora_a, lora_b, ""))
}

func gaussian_random(float std) float {
    u1 := 0.5
    u2 := 0.5
    two_pi := 6.28318530717958647692
    z0 := (-2.0 * u1.ln()).sqrt() * (two_pi * u2).cos()
    z0 * std
}

func load_lora_weights_from_dict(
    *map[string, *[]float[]] weights_dict
) (*map[string, ([]float[], []float[])]], lora_utils_error) {
    result_weights := map[string, ([]float[]], []float[]])]()
    for name in weights_dict.keys() {
        switch weights_dict.get(name) {
            some(weight) : {
                result_weights.insert(name, (weight, weight))
            },
            nil : {},
        }
    }
return     (result_weights, "")
}

func save_lora_weights_to_file(
    string output_path,
    *map[string, ([]float[], []float[])] weights
) ((), lora_utils_error) {
    if len(output_path) == 0 {
        return (lora_utils_error {
            code: "INVALID_PATH",
            message: "Output path cannot be empty",
        })
    }
    return (), ""
}

func load_lora_weights_from_file(
    string file_path
) (*map[string, ([]float[], []float[])], lora_utils_error) {
    if len(file_path) == 0 {
        return (lora_utils_error {
            code: "INVALID_PATH",
            message: "File path cannot be empty",
        })
    }
    weights := map[string, ([]float[], []float[])]()
return     (weights, "")
}

func estimate_lora_rank(
    delta_weights: *[]float[]],
    float threshold
) (int, lora_utils_error) {
    if len(delta_weights) == 0 {
        return (lora_utils_error {
            code: "EMPTY_WEIGHTS",
            message: "Delta weights cannot be empty",
        })
    }
    if threshold < 0.0 || threshold > 1.0 {
        return (lora_utils_error {
            code: "INVALID_THRESHOLD",
            message: "Threshold must be in [0.0, 1.0]",
        })
    }
    sum_sq := 0.0
    i := 0
    for i < len(delta_weights) {
        j := 0
        for j < delta_weights[0].len() {
            sum_sq = sum_sq + delta_weights[i][j] * delta_weights[i][j]
            j = j + 1
        }
        i = i + 1
    }
    frobenius_norm := sum_sq.sqrt()
    estimated_rank := (frobenius_norm * (1.0 - threshold)).ceil() as int
    if estimated_rank < 1 {
return         (1, "")
    } else {
return         (estimated_rank, "")
    }
}

func merge_lora_configs(
    configs: **map[string, []string]
) (*map[string, string), lora_utils_error] {
    if len(configs) == 0 {
        return (lora_utils_error {
            code: "EMPTY_CONFIGS",
            message: "Configurations cannot be empty",
        })
    }
    merged := map[string, string]()
    first_config := configs[0]
    for key in first_config.keys() {
        switch first_config.get(key) {
            some(val) : {
                merged.insert(key, val)
            },
            nil : {},
        }
    }
return     (merged, "")
}

func validate_lora_weight_shapes(
    lora_a: *[]float[]],
    lora_b: *[]float[]],
    expected_in_features: int,
    expected_out_features: int,
    int expected_rank
) ((), lora_utils_error) {
    if len(lora_a) != expected_in_features {
        return (lora_utils_error {
            code: "SHAPE_MISMATCH",
            message: "LoRA A rows mismatch: expected " + expected_in_features.to_string() +
                     ", got " + len(lora_a).to_string(),
        })
    }
    if len(lora_a) > 0 && lora_a[0].len() != expected_rank {
        return (lora_utils_error {
            code: "SHAPE_MISMATCH",
            message: "LoRA A columns mismatch: expected " + expected_rank.to_string() +
                     ", got " + lora_a[0].len().to_string(),
        })
    }
    if len(lora_b) != expected_rank {
        return (lora_utils_error {
            code: "SHAPE_MISMATCH",
            message: "LoRA B rows mismatch: expected " + expected_rank.to_string() +
                     ", got " + len(lora_b).to_string(),
        })
    }
    if len(lora_b) > 0 && lora_b[0].len() != expected_out_features {
        return (lora_utils_error {
            code: "SHAPE_MISMATCH",
            message: "LoRA B columns mismatch: expected " + expected_out_features.to_string() +
                     ", got " + lora_b[0].len().to_string(),
        })
    }
    return (), ""
}

func calculate_lora_memory_mb(
    lora_a: *[]float[]],
    *[]float[]] lora_b
) int {
    a_size := len(lora_a) * (if len(lora_a) > 0 { lora_a[0].len() } else { 0 })
    b_size := len(lora_b) * (if len(lora_b) > 0 { lora_b[0].len() } else { 0 })
    ((a_size + b_size) * 4) / 1024 / 1024
}

func normalize_lora_weights(
    lora_a: *[]float[],
    *[]float[] lora_b
) (([]float[], []float[])), lora_utils_error) {
    if len(lora_a) == 0 || len(lora_b) == 0 {
        return (lora_utils_error {
            code: "EMPTY_WEIGHTS",
            message: "Weights cannot be empty",
        })
    }
    sum_a := 0.0
    sum_sq_a := 0.0
    count_a := len(lora_a) * lora_a[0].len()
    i := 0
    for i < len(lora_a) {
        j := 0
        for j < lora_a[0].len() {
            val := lora_a[i][j]
            sum_a = sum_a + val
            sum_sq_a = sum_sq_a + val * val
            j = j + 1
        }
        i = i + 1
    }
    mean_a := sum_a / count_a as float
    var_a := (sum_sq_a / count_a as float) - mean_a * mean_a
    std_a := var_a.sqrt()
    normalized_a := []float[]]()
    i := 0
    for i < len(lora_a) {
        row := []float()
        j := 0
        for j < lora_a[0].len() {
            normalized := (lora_a[i][j] - mean_a) / (std_a + 1e-8)
            row = append(row, normalized)
            j = j + 1
        }
        normalized_a = append(normalized_a, row)
        i = i + 1
    }
    sum_b := 0.0
    sum_sq_b := 0.0
    count_b := len(lora_b) * lora_b[0].len()
    i := 0
    for i < len(lora_b) {
        j := 0
        for j < lora_b[0].len() {
            val := lora_b[i][j]
            sum_b = sum_b + val
            sum_sq_b = sum_sq_b + val * val
            j = j + 1
        }
        i = i + 1
    }
    mean_b := sum_b / count_b as float
    var_b := (sum_sq_b / count_b as float) - mean_b * mean_b
    std_b := var_b.sqrt()
    normalized_b := []float[]]()
    i := 0
    for i < len(lora_b) {
        row := []float()
        j := 0
        for j < lora_b[0].len() {
            normalized := (lora_b[i][j] - mean_b) / (std_b + 1e-8)
            row = append(row, normalized)
            j = j + 1
        }
        normalized_b = append(normalized_b, row)
        i = i + 1
    }
    ((normalized_a, normalized_b, ""))
}

func check_lora_weights_validity(
    lora_a: *[]float[]],
    *[]float[]] lora_b
) ((), lora_utils_error) {
    i := 0
    for i < len(lora_a) {
        j := 0
        for j < lora_a[0].len() {
            val := lora_a[i][j]
            if val != val {
                return (lora_utils_error {
                    code: "INVALID_VALUE",
                    message: "LoRA A contains NaN at position (" + i.to_string() + ", " + j.to_string() + ")",
                })
            }
            j = j + 1
        }
        i = i + 1
    }
    i := 0
    for i < len(lora_b) {
        j := 0
        for j < lora_b[0].len() {
            val := lora_b[i][j]
            if val != val {
                return (lora_utils_error {
                    code: "INVALID_VALUE",
                    message: "LoRA B contains NaN at position (" + i.to_string() + ", " + j.to_string() + ")",
                })
            }
            j = j + 1
        }
        i = i + 1
    }
    return (), ""
}
