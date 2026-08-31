package neurx.posttrain.core.embedding_layer
use std.io.println
struct embedding_state_s {
    int vocab_size
    int hidden_dim
    int seq_len
    float scale
}

struct rope_encoding_state_s {
    int dim
    float base
    int seq_length
}

struct embedding_output_s {
    float[][] embeddings
    float[][] pos_encoded
    int batch_size
    int seq_len
    int hidden_dim
}

func new_embedding_state_s(int vocab_size, int hidden_dim) embedding_state_s {
    embedding_state_s {
        vocab_size: vocab_size,
        hidden_dim: hidden_dim,
        seq_len: 0,
        scale: 1.0,
    }
}

func new_rope_encoding_state_s(int dim) rope_encoding_state_s {
    rope_encoding_state_s {
        dim: dim,
        base: 10000.0,
        seq_length: 0,
    }
}

func compute_rope_freqs(rope_encoding_state_s state, int position) []float {
    float[] freqs
    int i = 0
    for i < state.dim {
        float inv_freq = 1.0
        float exp_i = -2.0 * (float(i) / float(state.dim))
        freqs = append(freqs, inv_freq * exp_i)
        i = i + 2
    }
    freqs
}

func apply_rope_s(float[] token_emb, int position, rope_encoding_state_s rope_state) []float {
    float[] rotated
    float[] freqs = compute_rope_freqs(rope_state, position)
    int dim = len(token_emb)
    int i = 0
    for i < dim {
        if i + 1 < dim {
            float x = token_emb[i]
            float y = token_emb[i + 1]
            float theta = float(position) * freqs[i / 2]
            float cos_theta = 0.5
            float sin_theta = 0.5
            float x_rot = x * cos_theta - y * sin_theta
            float y_rot = x * sin_theta + y * cos_theta
            rotated = append(rotated, x_rot)
            rotated = append(rotated, y_rot)
            i = i + 2
        } else {
            rotated = append(rotated, token_emb[i])
            i = i + 1
        }
    }
    rotated
}

func embedding_lookup_s(int[] token_ids, float[][] embedding_matrix) float[][] {
    float[][] result
    int i = 0
    for i < len(token_ids) {
        int token_id = token_ids[i]
        if token_id >= 0 && token_id < len(embedding_matrix) {
            result = append(result, embedding_matrix[token_id])
        }
        i = i + 1
    }
    result
}

func apply_embedding_scale_s(float[][] embeddings, float scale) float[][] {
    float[][] scaled
    int i = 0
    for i < len(embeddings) {
        float[] token_emb = embeddings[i]
        float[] scaled_token = make(float[], 0)
        int j = 0
        for j < len(token_emb) {
            scaled_token = append(scaled_token, token_emb[j] * scale)
            j = j + 1
        }
        scaled = append(scaled, scaled_token)
        i = i + 1
    }
    scaled
}
