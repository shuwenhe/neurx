package neurx.lib.nn

// Neural network layers for S language
// Implements LoRA (Low-Rank Adaptation) components

use neurx.lib.tensor.{Vector, Matrix, create_vector, create_matrix, random_matrix, vector_scale, matrix_scale, matrix_multiply, matrix_vector_multiply, matrix_add, vector_add, outer_product}

// Linear layer: y = Wx + b
struct LinearLayer {
    Matrix weight      // Weight matrix (out_features x in_features)
    Vector bias        // Bias vector (out_features)
    int in_features
    int out_features
    float learning_rate
}

// LoRA adapter: adds low-rank matrices A and B to frozen weights
struct LoRAAdapter {
    Matrix lora_a      // (in_features x rank)
    Matrix lora_b      // (rank x out_features)
    float alpha        // Scaling factor
    int rank
    int in_features
    int out_features
    float learning_rate
}

// LoRA linear layer: combines base weight with LoRA
struct LoRALinearLayer {
    Matrix base_weight      // Frozen base weight
    Vector base_bias        // Bias (trainable or frozen)
    LoRAAdapter adapter     // LoRA adapter
    int in_features
    int out_features
}

// Embedding layer
struct EmbeddingLayer {
    Matrix embeddings       // (vocab_size x embedding_dim)
    int vocab_size
    int embedding_dim
}

// LayerNorm
struct LayerNorm {
    Vector gamma            // Scale parameter
    Vector beta             // Shift parameter
    float epsilon           // Small constant for numerical stability
    int hidden_size
}

// Creates a linear layer with random initialization
func create_linear_layer(int in_features, int out_features, float lr, int seed) LinearLayer {
    LinearLayer layer
    layer.in_features = in_features
    layer.out_features = out_features
    layer.learning_rate = lr
    
    // Xavier initialization for weights
    layer.weight = random_matrix(out_features, in_features, seed)
    
    // Scale weights by sqrt(1 / in_features)
    float scale = 1.0
    float x = in_features as float
    float result = x
    int i = 0
    while i < 10 {
        result = (result + x / result) * 0.5
        i = i + 1
    }
    scale = 1.0 / result
    
    layer.weight = matrix_scale(layer.weight, scale)
    
    // Initialize bias to zero
    layer.bias = create_vector(out_features)
    
    layer
}

// Forward pass of linear layer: y = Wx + b
func linear_forward(LinearLayer layer, Vector x) Vector {
    // y = Wx
    Vector y = matrix_vector_multiply(layer.weight, x)
    
    // y = Wx + b
    y = vector_add(y, layer.bias)
    y
}

// Creates a LoRA adapter
func create_lora_adapter(int in_features, int out_features, int rank, float alpha, float lr, int seed) LoRAAdapter {
    LoRAAdapter adapter
    adapter.in_features = in_features
    adapter.out_features = out_features
    adapter.rank = rank
    adapter.alpha = alpha
    adapter.learning_rate = lr
    
    // Initialize LoRA A: (in_features x rank) with small random values
    adapter.lora_a = random_matrix(in_features, rank, seed)
    adapter.lora_a = matrix_scale(adapter.lora_a, 0.01)  // Small initialization
    
    // Initialize LoRA B: (rank x out_features) with zeros
    adapter.lora_b = create_matrix(rank, out_features)
    
    adapter
}

// LoRA forward: output = W_base @ x + (alpha/rank) * (B @ A) @ x
func lora_forward(LoRALinearLayer layer, Vector x) Vector {
    // Base output: W_base @ x + b
    Vector output = matrix_vector_multiply(layer.base_weight, x)
    output = vector_add(output, layer.base_bias)
    
    // LoRA contribution: (alpha/rank) * (B @ A) @ x
    // Compute A @ x first
    Vector ax = matrix_vector_multiply(layer.adapter.lora_a, x)
    
    // Compute B @ (A @ x)
    Vector b_ax = matrix_vector_multiply(layer.adapter.lora_b, ax)
    
    // Scale by alpha/rank
    float scale = layer.adapter.alpha / (layer.adapter.rank as float)
    b_ax = vector_scale(b_ax, scale)
    
    // Add to output
    output = vector_add(output, b_ax)
    output
}

// Creates a LoRA linear layer
func create_lora_linear_layer(int in_features, int out_features, int rank, float alpha, float lr, int seed) LoRALinearLayer {
    LoRALinearLayer layer
    layer.in_features = in_features
    layer.out_features = out_features
    
    // Initialize base weight as identity (or small random)
    layer.base_weight = random_matrix(out_features, in_features, seed)
    float init_scale = 0.01
    layer.base_weight = matrix_scale(layer.base_weight, init_scale)
    
    // Initialize bias to zero
    layer.base_bias = create_vector(out_features)
    
    // Create LoRA adapter
    layer.adapter = create_lora_adapter(in_features, out_features, rank, alpha, lr, seed + 1)
    
    layer
}

// Creates an embedding layer
func create_embedding_layer(int vocab_size, int embedding_dim, int seed) EmbeddingLayer {
    EmbeddingLayer layer
    layer.vocab_size = vocab_size
    layer.embedding_dim = embedding_dim
    
    // Initialize embeddings with random values
    layer.embeddings = random_matrix(vocab_size, embedding_dim, seed)
    
    // Scale by 0.02
    layer.embeddings = matrix_scale(layer.embeddings, 0.02)
    
    layer
}

// Embedding lookup: returns embedding vector for token ID
func embedding_lookup(EmbeddingLayer layer, int token_id) Vector {
    Vector result = create_vector(layer.embedding_dim)
    
    if token_id < 0 || token_id >= layer.vocab_size {
        return result
    }
    
    // Copy embedding
    int i = 0
    while i < layer.embedding_dim {
        result.data[i] = layer.embeddings.data[token_id * layer.embedding_dim + i]
        i = i + 1
    }
    
    result
}

// Creates LayerNorm
func create_layer_norm(int hidden_size) LayerNorm {
    LayerNorm ln
    ln.hidden_size = hidden_size
    ln.epsilon = 0.00001  // 1e-5
    
    // Initialize gamma (scale) to 1
    ln.gamma = create_vector(hidden_size)
    int i = 0
    while i < hidden_size {
        ln.gamma.data[i] = 1.0
        i = i + 1
    }
    
    // Initialize beta (shift) to 0
    ln.beta = create_vector(hidden_size)
    
    ln
}

// LayerNorm forward pass: normalize and scale/shift
func layer_norm_forward(LayerNorm ln, Vector x) Vector {
    // Compute mean
    float mean = 0.0
    int i = 0
    while i < ln.hidden_size {
        mean = mean + x.data[i]
        i = i + 1
    }
    mean = mean / (ln.hidden_size as float)
    
    // Compute variance
    float variance = 0.0
    i = 0
    while i < ln.hidden_size {
        float diff = x.data[i] - mean
        variance = variance + diff * diff
        i = i + 1
    }
    variance = variance / (ln.hidden_size as float)
    
    // Compute standard deviation
    float std_dev = variance
    float sqrt_result = std_dev
    int j = 0
    while j < 10 {
        sqrt_result = (sqrt_result + std_dev / sqrt_result) * 0.5
        j = j + 1
    }
    std_dev = sqrt_result
    
    // Normalize
    Vector normalized = create_vector(ln.hidden_size)
    i = 0
    while i < ln.hidden_size {
        normalized.data[i] = (x.data[i] - mean) / (std_dev + ln.epsilon)
        i = i + 1
    }
    
    // Scale and shift
    Vector output = create_vector(ln.hidden_size)
    i = 0
    while i < ln.hidden_size {
        output.data[i] = ln.gamma.data[i] * normalized.data[i] + ln.beta.data[i]
        i = i + 1
    }
    
    output
}

// Dropout (simplified: randomly zeros elements with probability p)
func dropout(Vector x, float dropout_rate, int seed) Vector {
    Vector result = create_vector(x.size)
    
    int state = seed
    int i = 0
    while i < x.size {
        // Simple pseudo-random number
        state = (state * 1103515245 + 12345) - ((state * 1103515245 + 12345) / 2147483648) * 2147483648
        if state < 0 {
            state = 0 - state
        }
        
        float rand_val = ((state / 65536) - ((state / 65536) / 32768) * 32768) as float / 32768.0
        
        if rand_val > dropout_rate {
            // Don't drop: scale by 1/(1-dropout_rate)
            result.data[i] = x.data[i] / (1.0 - dropout_rate)
        } else {
            // Drop
            result.data[i] = 0.0
        }
        
        i = i + 1
    }
    
    result
}

// Batch normalization statistics
struct BatchNormStats {
    Vector running_mean
    Vector running_var
    float momentum
    int feature_size
}

// Create batch norm stats tracker
func create_batch_norm_stats(int feature_size) BatchNormStats {
    BatchNormStats stats
    stats.feature_size = feature_size
    stats.momentum = 0.9
    
    // Initialize running mean to 0
    stats.running_mean = create_vector(feature_size)
    
    // Initialize running variance to 1
    stats.running_var = create_vector(feature_size)
    int i = 0
    while i < feature_size {
        stats.running_var.data[i] = 1.0
        i = i + 1
    }
    
    stats
}
