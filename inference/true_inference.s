package neurx.inference.true_model_inference
use neurx.inference.safetensors_real.{load_model_safetensors}
use neurx.inference.tokenizer_loader.{load_tokenizer, tokenize}
use step2_embedding.{embed_tokens}
use step3_transformer.{create_transformer_config, transformer_forward}
use step5_sampling_step6_decode.{create_sampling_config, generate, decode_tokens}
extern "intrinsic" func __host_slice(string text, int start, int end) string
struct mean_std {
    float mean
    float std
}

func sqrt_approx(float x) float {
    if x <= 0.0 { return 0.0 }
    float y = x
    int k = 0
    while k < 10 {
        y = 0.5 * (y + x / y)
        k = k + 1
    }
    return y
}

func compute_mean_std([][]float mat) mean_std {
    int rows = len(mat)
    if rows == 0 {
        return mean_std{mean: 0.0, std: 0.0}
    }
    int cols = len(mat[0])
    float sum = 0.0
    int i = 0
    while i < rows {
        int j = 0
        while j < cols {
            sum = sum + mat[i][j]
            j = j + 1
        }
        i = i + 1
    }
    int N = rows * cols
    float mean = sum / float(N)
    float acc = 0.0
    i = 0
    while i < rows {
        int j = 0
        while j < cols {
            float d = mat[i][j] - mean
            acc = acc + d * d
            j = j + 1
        }
        i = i + 1
    }
    float variance = acc / float(N)
    float std = sqrt_approx(variance)
    return mean_std{mean: mean, std: std}
}

