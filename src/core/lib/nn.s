package neurx.lib.nn
use neurx.lib.tensor.{vector, matrix, create_vector, create_matrix, random_matrix, vector_scale, matrix_scale, matrix_multiply, matrix_vector_multiply, matrix_add, vector_add, outer_product}

struct linear_layer {
    matrix weight
    vector bias
    int in_features
    int out_features
    float learning_rate
}

struct lora_adapter {
    matrix lora_a
    matrix lora_b
    float alpha
    int rank
    int in_features
    int out_features
    float learning_rate
}

struct lora_linear_layer {
    matrix base_weight
    vector base_bias
    lora_adapter adapter
    int in_features
    int out_features
}

struct embedding_layer {
    matrix embeddings
    int vocab_size
    int embedding_dim
}

struct layer_norm {
    vector gamma
    vector beta
    float epsilon
    int hidden_size
}

func create_linear_layer(int in_features, int out_features, float lr, int seed) linear_layer {
    linear_layer layer
    layer.in_features = in_features
    layer.out_features = out_features
    layer.learning_rate = lr
    layer.weight = random_matrix(out_features, in_features, seed)
    float scale = 1.0
    float x = in_features as float
    float result = x
    int i = 0
    for i < 10 {
        result = (result + x / result) * 0.5
        i = i + 1
    }
    scale = 1.0 / result
    layer.weight = matrix_scale(layer.weight, scale)
    layer.bias = create_vector(out_features)
    layer
}

func linear_forward(linear_layer layer, vector x) vector {
    vector y = matrix_vector_multiply(layer.weight, x)
    y = vector_add(y, layer.bias)
    y
}

func create_lora_adapter(int in_features, int out_features, int rank, float alpha, float lr, int seed) lora_adapter {
    lora_adapter adapter
    adapter.in_features = in_features
    adapter.out_features = out_features
    adapter.rank = rank
    adapter.alpha = alpha
    adapter.learning_rate = lr
    adapter.lora_a = random_matrix(in_features, rank, seed)
    adapter.lora_a = matrix_scale(adapter.lora_a, 0.01)
    adapter.lora_b = create_matrix(rank, out_features)
    adapter
}

func lora_forward(lora_linear_layer layer, vector x) vector {
    vector output = matrix_vector_multiply(layer.base_weight, x)
    output = vector_add(output, layer.base_bias)
    vector ax = matrix_vector_multiply(layer.adapter.lora_a, x)
    vector b_ax = matrix_vector_multiply(layer.adapter.lora_b, ax)
    float scale = layer.adapter.alpha / (layer.adapter.rank as float)
    b_ax = vector_scale(b_ax, scale)
    output = vector_add(output, b_ax)
    output
}

func create_lora_linear_layer(int in_features, int out_features, int rank, float alpha, float lr, int seed) lora_linear_layer {
    lora_linear_layer layer
    layer.in_features = in_features
    layer.out_features = out_features
    layer.base_weight = random_matrix(out_features, in_features, seed)
    float init_scale = 0.01
    layer.base_weight = matrix_scale(layer.base_weight, init_scale)
    layer.base_bias = create_vector(out_features)
    layer.adapter = create_lora_adapter(in_features, out_features, rank, alpha, lr, seed + 1)
    layer
}

func create_embedding_layer(int vocab_size, int embedding_dim, int seed) embedding_layer {
    embedding_layer layer
    layer.vocab_size = vocab_size
    layer.embedding_dim = embedding_dim
    layer.embeddings = random_matrix(vocab_size, embedding_dim, seed)
    layer.embeddings = matrix_scale(layer.embeddings, 0.02)
    layer
}

func embedding_lookup(embedding_layer layer, int token_id) vector {
    vector result = create_vector(layer.embedding_dim)
    if token_id < 0 || token_id >= layer.vocab_size {
        return result
    }
    int i = 0
    for i < layer.embedding_dim {
        result.data[i] = layer.embeddings.data[token_id * layer.embedding_dim + i]
        i = i + 1
    }
    result
}

func create_layer_norm(int hidden_size) layer_norm {
    layer_norm ln
    ln.hidden_size = hidden_size
    ln.epsilon = 0.00001
    ln.gamma = create_vector(hidden_size)
    int i = 0
    for i < hidden_size {
        ln.gamma.data[i] = 1.0
        i = i + 1
    }
    ln.beta = create_vector(hidden_size)
    ln
}

func layer_norm_forward(layer_norm ln, vector x) vector {
    float mean = 0.0
    int i = 0
    for i < ln.hidden_size {
        mean = mean + x.data[i]
        i = i + 1
    }
    mean = mean / (ln.hidden_size as float)
    float variance = 0.0
    i = 0
    for i < ln.hidden_size {
        float diff = x.data[i] - mean
        variance = variance + diff * diff
        i = i + 1
    }
    variance = variance / (ln.hidden_size as float)
    float std_dev = variance
    float sqrt_result = std_dev
    int j = 0
    for j < 10 {
        sqrt_result = (sqrt_result + std_dev / sqrt_result) * 0.5
        j = j + 1
    }
    std_dev = sqrt_result
    vector normalized = create_vector(ln.hidden_size)
    i = 0
    for i < ln.hidden_size {
        normalized.data[i] = (x.data[i] - mean) / (std_dev + ln.epsilon)
        i = i + 1
    }
    vector output = create_vector(ln.hidden_size)
    i = 0
    for i < ln.hidden_size {
        output.data[i] = ln.gamma.data[i] * normalized.data[i] + ln.beta.data[i]
        i = i + 1
    }
    output
}

func dropout(vector x, float dropout_rate, int seed) vector {
    vector result = create_vector(x.size)
    int state = seed
    int i = 0
    for i < x.size {
        state = (state * 1103515245 + 12345) - ((state * 1103515245 + 12345) / 2147483648) * 2147483648
        if state < 0 {
            state = 0 - state
        }
        float rand_val = ((state / 65536) - ((state / 65536) / 32768) * 32768) as float / 32768.0
        if rand_val > dropout_rate {
            result.data[i] = x.data[i] / (1.0 - dropout_rate)
        } else {
            result.data[i] = 0.0
        }
        i = i + 1
    }
    result
}

struct batch_norm_stats {
    vector running_mean
    vector running_var
    float momentum
    int feature_size
}

func create_batch_norm_stats(int feature_size) batch_norm_stats {
    batch_norm_stats stats
    stats.feature_size = feature_size
    stats.momentum = 0.9
    stats.running_mean = create_vector(feature_size)
    stats.running_var = create_vector(feature_size)
    int i = 0
    for i < feature_size {
        stats.running_var.data[i] = 1.0
        i = i + 1
    }
    stats
}
