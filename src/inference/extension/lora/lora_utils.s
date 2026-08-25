package neurx.lora.lora_utils

use std.vec.vec
use std.option.option
use std.result.result
use std.map.map

struct lora_utils_error {
    code: string
    message: string
}

func init_lora_weights_kaiming(
    in_features: int,
    out_features: int,
    rank: int
) result[(vec[vec[float]], vec[vec[float]]), lora_utils_error] {
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

    lora_a := vec[vec[float]]()
    i := 0
    for i < in_features {
        row := vec[float]()
        j := 0
        for j < rank {

            val := gaussian_random(std)
            row.push(val)
            j = j + 1
        }
        lora_a.push(row)
        i = i + 1
    }

    lora_b := vec[vec[float]]()
    i := 0
    for i < rank {
        row := vec[float]()
        j := 0
        for j < out_features {
            row.push(0.0)
            j = j + 1
        }
        lora_b.push(row)
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
    weights_dict: *map[string, &vec[vec[float]]]
) result[&map[string, (vec[vec[float]], vec[vec[float]])], lora_utils_error] {
    result_weights := map[string, (vec[vec[float]], vec[vec[float]])]()

    for name in weights_dict.keys() {
        switch weights_dict.get(name) {
            option::some(weight) : {

                result_weights.insert(name, (weight, weight))
            },
            option::none : {},
        }
    }

    (result_weights, "")
}

func save_lora_weights_to_file(
    output_path: string,
    weights: *map[string, (vec[vec[float]], vec[vec[float]])]
) result[(), lora_utils_error] {
    if output_path.len() == 0 {
        return (lora_utils_error {
            code: "INVALID_PATH",
            message: "Output path cannot be empty",
        })
    }

    ((, ""))
}

func load_lora_weights_from_file(
    file_path: string
) result[&map[string, (vec[vec[float]], vec[vec[float]])], lora_utils_error] {
    if file_path.len() == 0 {
        return (lora_utils_error {
            code: "INVALID_PATH",
            message: "File path cannot be empty",
        })
    }

    weights := map[string, (vec[vec[float]], vec[vec[float]])]()

    (weights, "")
}

func estimate_lora_rank(
    delta_weights: *vec[vec[float]],
    threshold: float
) result[int, lora_utils_error] {
    if delta_weights.len() == 0 {
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
    for i < delta_weights.len() {
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
        (1, "")
    } else {
        (estimated_rank, "")
    }
}

func merge_lora_configs(
    configs: *vec[&map[string, string]]
) result[&map[string, string], lora_utils_error] {
    if configs.len() == 0 {
        return (lora_utils_error {
            code: "EMPTY_CONFIGS",
            message: "Configurations cannot be empty",
        })
    }

    merged := map[string, string]()

    first_config := configs[0]
    for key in first_config.keys() {
        switch first_config.get(key) {
            option::some(val) : {
                merged.insert(key, val)
            },
            option::none : {},
        }
    }

    (merged, "")
}

func validate_lora_weight_shapes(
    lora_a: *vec[vec[float]],
    lora_b: *vec[vec[float]],
    expected_in_features: int,
    expected_out_features: int,
    expected_rank: int
) result[(), lora_utils_error] {

    if lora_a.len() != expected_in_features {
        return (lora_utils_error {
            code: "SHAPE_MISMATCH",
            message: "LoRA A rows mismatch: expected " + expected_in_features.to_string() +
                     ", got " + lora_a.len().to_string(),
        })
    }

    if lora_a.len() > 0 && lora_a[0].len() != expected_rank {
        return (lora_utils_error {
            code: "SHAPE_MISMATCH",
            message: "LoRA A columns mismatch: expected " + expected_rank.to_string() +
                     ", got " + lora_a[0].len().to_string(),
        })
    }

    if lora_b.len() != expected_rank {
        return (lora_utils_error {
            code: "SHAPE_MISMATCH",
            message: "LoRA B rows mismatch: expected " + expected_rank.to_string() +
                     ", got " + lora_b.len().to_string(),
        })
    }

    if lora_b.len() > 0 && lora_b[0].len() != expected_out_features {
        return (lora_utils_error {
            code: "SHAPE_MISMATCH",
            message: "LoRA B columns mismatch: expected " + expected_out_features.to_string() +
                     ", got " + lora_b[0].len().to_string(),
        })
    }

    ((, ""))
}

func calculate_lora_memory_mb(
    lora_a: *vec[vec[float]],
    lora_b: *vec[vec[float]]
) int {
    a_size := lora_a.len() * (if lora_a.len() > 0 { lora_a[0].len() } else { 0 })
    b_size := lora_b.len() * (if lora_b.len() > 0 { lora_b[0].len() } else { 0 })

    ((a_size + b_size) * 4) / 1024 / 1024
}

func normalize_lora_weights(
    lora_a: *vec[vec[float]],
    lora_b: *vec[vec[float]]
) result[(vec[vec[float]], vec[vec[float]]), lora_utils_error] {
    if lora_a.len() == 0 || lora_b.len() == 0 {
        return (lora_utils_error {
            code: "EMPTY_WEIGHTS",
            message: "Weights cannot be empty",
        })
    }

    sum_a := 0.0
    sum_sq_a := 0.0
    count_a := lora_a.len() * lora_a[0].len()

    i := 0
    for i < lora_a.len() {
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

    normalized_a := vec[vec[float]]()
    i := 0
    for i < lora_a.len() {
        row := vec[float]()
        j := 0
        for j < lora_a[0].len() {
            normalized := (lora_a[i][j] - mean_a) / (std_a + 1e-8)
            row.push(normalized)
            j = j + 1
        }
        normalized_a.push(row)
        i = i + 1
    }

    sum_b := 0.0
    sum_sq_b := 0.0
    count_b := lora_b.len() * lora_b[0].len()

    i := 0
    for i < lora_b.len() {
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

    normalized_b := vec[vec[float]]()
    i := 0
    for i < lora_b.len() {
        row := vec[float]()
        j := 0
        for j < lora_b[0].len() {
            normalized := (lora_b[i][j] - mean_b) / (std_b + 1e-8)
            row.push(normalized)
            j = j + 1
        }
        normalized_b.push(row)
        i = i + 1
    }

    ((normalized_a, normalized_b, ""))
}

func check_lora_weights_validity(
    lora_a: *vec[vec[float]],
    lora_b: *vec[vec[float]]
) result[(), lora_utils_error] {
    i := 0
    for i < lora_a.len() {
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
    for i < lora_b.len() {
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

    ((, ""))
}
