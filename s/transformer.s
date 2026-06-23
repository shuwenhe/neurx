package neurx.transformer

use neurx.tensor.tensor
use neurx.tensor.new

func copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    for i in 0..n {
        out[i] = data[i]
    }
    out
}

func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    for i in 0..n {
        out[i] = data[i]
    }
    out
}

func copy_tensor(tensor value) tensor {
    new(copy_float(value.data), copy_int(value.shape), value.requires_grad)
}

func copy_layer(transformer_layer layer) transformer_layer {
    transformer_layer {
        w_q: copy_tensor(layer.w_q),
        w_k: copy_tensor(layer.w_k),
        w_v: copy_tensor(layer.w_v),
        w_o: copy_tensor(layer.w_o),
        w_ff1: copy_tensor(layer.w_ff1),
        w_ff2: copy_tensor(layer.w_ff2),
        b_ff1: copy_tensor(layer.b_ff1),
        b_ff2: copy_tensor(layer.b_ff2),
    }
}

func copy_layers([]transformer_layer layers) []transformer_layer {
    int n = len(layers)
    []transformer_layer out = []transformer_layer{cap: n}
    for i in 0..n {
        out.push(copy_layer(layers[i]))
    }
    out
}

struct transformer_config {
    int num_layers
    int num_heads
    int d_model
    int d_ff
    float dropout
}

struct transformer_layer {
    tensor w_q
    tensor w_k
    tensor w_v
    tensor w_o
    tensor w_ff1
    tensor w_ff2
    tensor b_ff1
    tensor b_ff2
}

struct transformer {
    transformer_config config
    []transformer_layer layers
}

func transformer_init(config transformer_config) transformer {
    []transformer_layer mut_layers = []transformer_layer{cap: config.num_layers}
    // Pre-create shape arrays to avoid complex array literals
    int i = 0
    while i < config.num_layers {
        // Create shapes using helper approach
        []int shape_dmd = make_int_array_2(config.d_model, config.d_model)
        []int shape_dmff = make_int_array_2(config.d_model, config.d_ff)
        []int shape_ffdm = make_int_array_2(config.d_ff, config.d_model)
        []int shape_ff = make_int_array_1(config.d_ff)
        []int shape_dm = make_int_array_1(config.d_model)

        transformer_layer layer = transformer_layer {
            w_q: tensor_randn(shape_dmd),
            w_k: tensor_randn(shape_dmd),
            w_v: tensor_randn(shape_dmd),
            w_o: tensor_randn(shape_dmd),
            w_ff1: tensor_randn(shape_dmff),
            w_ff2: tensor_randn(shape_ffdm),
            b_ff1: tensor_zeros(shape_ff),
            b_ff2: tensor_zeros(shape_dm)
        }
        mut_layers[i] = layer
        i = i + 1
    }
    transformer {
        config: config,
        layers: mut_layers
    }
}

// Helper functions to create int arrays without inline literals
func make_int_array_1(int v) []int {
    []out = []int{cap: 1}
    out[0] = v
    out
}

func make_int_array_2(int a, int b) []int {
    []out = []int{cap: 2}
    out[0] = a
    out[1] = b
    out
}

func transformer_config_state_dict(transformer_config config) transformer_config {
    config
}

func transformer_config_load_state_dict(transformer_config config, transformer_config other) transformer_config {
    other
}

func transformer_layer_state_dict(transformer_layer layer) transformer_layer {
    copy_layer(layer)
}

func transformer_layer_load_state_dict(transformer_layer layer, transformer_layer other) transformer_layer {
    copy_layer(other)
}

func transformer_layers_state_dict([]transformer_layer layers) []transformer_layer {
    copy_layers(layers)
}

func transformer_layers_load_state_dict([]transformer_layer layers, []transformer_layer other) []transformer_layer {
    copy_layers(other)
}

func transformer_layer_count(transformer m) int {
    len(m.layers)
}

func transformer_state_dict(transformer state) transformer {
    transformer {
        config: state.config,
        layers: copy_layers(state.layers),
    }
}

func transformer_load_state_dict(transformer state, transformer other) transformer {
    del state
    transformer {
        config: other.config,
        layers: copy_layers(other.layers),
    }
}

func transformer_forward(m transformer, x tensor) tensor {
    int i = 0
    tensor out = x
    // Workaround for S compiler array indexing limitation with complex types
    // Use iteration-based access instead of direct indexing
    []transformer_layer layers_copy = copy_layers(m.layers)
    while i < m.config.num_layers {
        if i < len(layers_copy) {
            out = transformer_layer_forward(layers_copy[i], out, m.config)
        }
        i = i + 1
    }
    return out
}

func transformer_layer_forward(layer transformer_layer, x tensor, config transformer_config) tensor {
    tensor q = matmul(x, layer.w_q)
    tensor k = matmul(x, layer.w_k)
    tensor v = matmul(x, layer.w_v)
    tensor attn = multihead_attention(q, k, v, config.num_heads)
    tensor attn_out = matmul(attn, layer.w_o)
    tensor x2 = add(x, attn_out)
    tensor ff1 = add(matmul(x2, layer.w_ff1), layer.b_ff1)
    tensor ff1_act = relu(ff1)
    tensor ff2 = add(matmul(ff1_act, layer.w_ff2), layer.b_ff2)
    tensor out = add(x2, ff2)
    return out
}

func multihead_attention(tensor q, tensor k, tensor v, int num_heads) tensor {
    
    tensor attn_scores = matmul(q, transpose(k))
    tensor attn_weights = softmax(attn_scores)
    tensor attn = matmul(attn_weights, v)
    return attn
}
