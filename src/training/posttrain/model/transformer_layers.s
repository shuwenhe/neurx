package neurx.posttrain.model.transformer_layers
use neurx.posttrain.model.model_loader.{fill_model_tensor}

struct embedding_layer {
    float[] weight
    int vocab_size
    int hidden_size
}

struct position_embedding {
    float[][] weight
    int max_seq_len
    int hidden_size
}

struct rope_config {
    int dim
    int max_seq_len
    float base
}

struct rms_norm {
    float[] weight
    float[] bias
    float epsilon
    int hidden_size
}

struct linear_layer {
    float[] weight
    float[] bias
    int in_features
    int out_features
}

struct multi_head_attention {
    linear_layer q_proj
    linear_layer k_proj
    linear_layer v_proj
    linear_layer o_proj
    int num_heads
    int head_dim
    int hidden_size
}

struct mlp_layer {
    linear_layer gate_proj
    linear_layer up_proj
    linear_layer down_proj
    int hidden_size
    int intermediate_size
}

struct transformer_block {
    rms_norm attention_norm
    multi_head_attention attention
    rms_norm mlp_norm
    mlp_layer mlp
    int hidden_size
}

func create_embedding(int vocab_size, int hidden_size) embedding_layer {
    embedding_layer emb
    emb.vocab_size = vocab_size
    emb.hidden_size = hidden_size
    emb.weight = fill_model_tensor(vocab_size * hidden_size, 0.01)
    return emb
}

func embedding_forward(embedding_layer emb, int[] token_ids) float[][] {
    float[][] embeddings = float[][]{}
    int i = 0
    for i < len(token_ids) {
        int token_id = token_ids[i]
        if token_id >= 0 && token_id < emb.vocab_size {
            float[] embedding = fill_model_tensor(emb.hidden_size, 0.0)
            int j = 0
            for j < emb.hidden_size {
                int idx = token_id * emb.hidden_size + j
                if idx < len(emb.weight) {
                    embedding[j] = emb.weight[idx]
                }
                j = j + 1
            }
            embeddings = append(embeddings, embedding)
        }
        i = i + 1
    }
    return embeddings
}

func create_rms_norm(int hidden_size) rms_norm {
    rms_norm norm
    norm.hidden_size = hidden_size
    norm.epsilon = 1e-6
    norm.weight = fill_model_tensor(hidden_size, 1.0)
    norm.bias = fill_model_tensor(hidden_size, 0.0)
    return norm
}

func rms_norm_forward(rms_norm norm, float[] hidden_state) float[] {
    float[] normalized = fill_model_tensor(len(hidden_state), 0.0)
    float sum_sq = 0.0
    int i = 0
    for i < len(hidden_state) {
        sum_sq = sum_sq + hidden_state[i] * hidden_state[i]
        i = i + 1
    }
    float rms = sqrt((sum_sq / ((len(hidden_state) as float))) + norm.epsilon)
    i = 0
    for i < len(hidden_state) {
        normalized[i] = (hidden_state[i] / rms) * norm.weight[i] + norm.bias[i]
        i = i + 1
    }
    return normalized
}

func create_linear(int in_features, int out_features) linear_layer {
    linear_layer linear
    linear.in_features = in_features
    linear.out_features = out_features
    linear.weight = fill_model_tensor(out_features * in_features, 0.01)
    linear.bias = fill_model_tensor(out_features, 0.0)
    return linear
}

func linear_forward(linear_layer layer, float[] input) float[] {
    float[] output = fill_model_tensor(layer.out_features, 0.0)
    int out_idx = 0
    for out_idx < layer.out_features {
        float sum = layer.bias[out_idx]
        int in_idx = 0
        for in_idx < layer.in_features && in_idx < len(input) {
            int w_idx = out_idx * layer.in_features + in_idx
            if w_idx < len(layer.weight) {
                sum = sum + input[in_idx] * layer.weight[w_idx]
            }
            in_idx = in_idx + 1
        }
        output[out_idx] = sum
        out_idx = out_idx + 1
    }
    return output
}

func create_rope_config(int dim, int max_seq_len) rope_config {
    rope_config config
    config.dim = dim
    config.max_seq_len = max_seq_len
    config.base = 10000.0
    return config
}

func rope_apply(rope_config config, float[] query, int position) float[] {
    float[] rotated = fill_model_tensor(len(query), 0.0)
    int i = 0
    for i < len(query) && i < config.dim {
        float freq = 1.0 / (pow(config.base, (((i as float) / (config.dim as float)) * 2.0)))
        float angle = (position as float) * freq
        if i - (i / 2) * 2 == 0 {
            rotated[i] = query[i] * cos(angle) - query[i + 1] * sin(angle)
        } else if i + 1 < len(query) {
            rotated[i] = query[i] * sin(angle) + query[i + 1] * cos(angle)
        }
        i = i + 2
    }
    int j = i
    for j < len(query) {
        rotated[j] = query[j]
        j = j + 1
    }
    return rotated
}

func create_multi_head_attention(int hidden_size, int num_heads) multi_head_attention {
    multi_head_attention attn
    attn.hidden_size = hidden_size
    attn.num_heads = num_heads
    attn.head_dim = hidden_size / num_heads
    attn.q_proj = create_linear(hidden_size, hidden_size)
    attn.k_proj = create_linear(hidden_size, hidden_size)
    attn.v_proj = create_linear(hidden_size, hidden_size)
    attn.o_proj = create_linear(hidden_size, hidden_size)
    return attn
}

func scaled_dot_product_attention(float[] query, float[] key, float[] value, float scale) float[] {
    float[] attention = fill_model_tensor(len(query), 0.0)
    float dot_product = 0.0
    int i = 0
    for i < len(query) && i < len(key) {
        dot_product = dot_product + query[i] * key[i]
        i = i + 1
    }
    dot_product = dot_product * scale
    float attention_weight = exp(dot_product)
    int j = 0
    for j < len(value) {
        attention[j] = attention_weight * value[j]
        j = j + 1
    }
    return attention
}

func multi_head_attention_forward(multi_head_attention attn, float[] hidden_state, float[] context) float[] {
    float[] q = linear_forward(attn.q_proj, hidden_state)
    float[] k = linear_forward(attn.k_proj, context)
    float[] v = linear_forward(attn.v_proj, context)
    float scale = 1.0 / sqrt((attn.head_dim as float))
    float[] attention_output = scaled_dot_product_attention(q, k, v, scale)
    float[] output = linear_forward(attn.o_proj, attention_output)
    return output
}

func create_mlp(int hidden_size, int intermediate_size) mlp_layer {
    mlp_layer mlp
    mlp.hidden_size = hidden_size
    mlp.intermediate_size = intermediate_size
    mlp.gate_proj = create_linear(hidden_size, intermediate_size)
    mlp.up_proj = create_linear(hidden_size, intermediate_size)
    mlp.down_proj = create_linear(intermediate_size, hidden_size)
    return mlp
}

func mlp_forward(mlp_layer mlp, float[] hidden_state) float[] {
    float[] gate = linear_forward(mlp.gate_proj, hidden_state)
    float[] up = linear_forward(mlp.up_proj, hidden_state)
    float[] gated = fill_model_tensor(len(gate), 0.0)
    int i = 0
    for i < len(gate) {
        gated[i] = gate[i] * up[i]
        i = i + 1
    }
    float[] output = linear_forward(mlp.down_proj, gated)
    return output
}

func create_transformer_block(int hidden_size, int intermediate_size, int num_heads) transformer_block {
    transformer_block block
    block.hidden_size = hidden_size
    block.attention_norm = create_rms_norm(hidden_size)
    block.attention = create_multi_head_attention(hidden_size, num_heads)
    block.mlp_norm = create_rms_norm(hidden_size)
    block.mlp = create_mlp(hidden_size, intermediate_size)
    return block
}

func transformer_block_forward(transformer_block block, float[] hidden_state) float[] {
    float[] normed_hidden = rms_norm_forward(block.attention_norm, hidden_state)
    float[] attention_output = multi_head_attention_forward(block.attention, normed_hidden, normed_hidden)
    float[] residual1 = fill_model_tensor(len(hidden_state), 0.0)
    int i = 0
    for i < len(hidden_state) {
        residual1[i] = hidden_state[i] + attention_output[i]
        i = i + 1
    }
    float[] normed_residual1 = rms_norm_forward(block.mlp_norm, residual1)
    float[] mlp_output = mlp_forward(block.mlp, normed_residual1)
    float[] final_output = fill_model_tensor(len(residual1), 0.0)
    i = 0
    for i < len(residual1) {
        final_output[i] = residual1[i] + mlp_output[i]
        i = i + 1
    }
    return final_output
}
