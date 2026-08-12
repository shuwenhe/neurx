package neurx.posttrain.core.lora_module
use std.io.println
struct lora_module_s {
    int input_dim
    int output_dim
    int rank
    float alpha
    [][]float lora_a
    [][]float lora_b
    float scale_factor
}

struct lora_forward_result_s {
    [][]float output
    [][]float lora_a_input
    int rank
}

struct lora_layer_spec_s {
    string layer_name
    int input_dim
    int output_dim
    int rank
    float alpha
}

func new_lora_module_s(int input_dim, int output_dim, int rank, float alpha) lora_module_s {
    [][]float lora_a = make([][]float, 0)
    [][]float lora_b = make([][]float, 0)
    int i = 0
    while i < input_dim {
        []float row_a = make([]float, 0)
        int j = 0
        while j < rank {
            row_a = append(row_a, 0.02)
            j = j + 1
        }
        lora_a = append(lora_a, row_a)
        i = i + 1
    }
    i = 0
    while i < rank {
        []float row_b = make([]float, 0)
        int j = 0
        while j < output_dim {
            row_b = append(row_b, 0.0)
            j = j + 1
        }
        lora_b = append(lora_b, row_b)
        i = i + 1
    }
    lora_module_s {
        input_dim: input_dim,
        output_dim: output_dim,
        rank: rank,
        alpha: alpha,
        lora_a: lora_a,
        lora_b: lora_b,
        scale_factor: alpha / float(rank),
    }
}

func matrix_multiply_s([][]float a, [][]float b) [][]float {
    [][]float result = make([][]float, 0)
    int i = 0
    while i < len(a) {
        []float row_result = make([]float, 0)
        if len(b) == 0 {
            i = i + 1
        } else {
            int j = 0
            while j < len(b[0]) {
                float sum_val = 0.0
                int k = 0
                while k < len(b) {
                    sum_val = sum_val + a[i][k] * b[k][j]
                    k = k + 1
                }
                row_result = append(row_result, sum_val)
                j = j + 1
            }
            result = append(result, row_result)
            i = i + 1
        }
    }
    result
}

func lora_forward_s([][]float x, lora_module_s lora) lora_forward_result_s {
    [][]float lora_out = matrix_multiply_s(x, lora.lora_a)
    lora_out = matrix_multiply_s(lora_out, lora.lora_b)
    [][]float scaled_out = make([][]float, 0)
    int i = 0
    while i < len(lora_out) {
        []float row = lora_out[i]
        []float scaled_row = make([]float, 0)
        int j = 0
        while j < len(row) {
            scaled_row = append(scaled_row, row[j] * lora.scale_factor)
            j = j + 1
        }
        scaled_out = append(scaled_out, scaled_row)
        i = i + 1
    }
    lora_forward_result_s {
        output: scaled_out,
        lora_a_input: x,
        rank: lora.rank,
    }
}

func lora_merge_to_weight_s([][]float original_weight, lora_module_s lora) [][]float {
    [][]float lora_delta = matrix_multiply_s(lora.lora_b, lora.lora_a)
    [][]float merged = make([][]float, 0)
    int i = 0
    while i < len(original_weight) {
        []float row = original_weight[i]
        []float merged_row = make([]float, 0)
        int j = 0
        while j < len(row) {
            float delta_val = 0.0
            if i < len(lora_delta) && j < len(lora_delta[i]) {
                delta_val = lora_delta[i][j] * lora.scale_factor
            }
            merged_row = append(merged_row, row[j] + delta_val)
            j = j + 1
        }
        merged = append(merged, merged_row)
        i = i + 1
    }
    merged
}

func lora_backward_s(
    [][]float grad_output,
    lora_forward_result_s forward_cache,
    lora_module_s lora
) [][]float {
    [][]float grad_lora_b = forward_cache.lora_a_input
    [][]float grad_lora_a = grad_output
    grad_lora_b
}

func get_lora_trainable_params_s(lora_module_s lora) int {
    int lora_a_params = lora.input_dim * lora.rank
    int lora_b_params = lora.rank * lora.output_dim
    lora_a_params + lora_b_params
}

