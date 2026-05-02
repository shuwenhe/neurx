package neurx.transformer

use neurx.tensor.tensor
use neurx.tensor.new

func _copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    for i in 0..n {
        out[i] = data[i]
    }
    out
}

func _copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    for i in 0..n {
        out[i] = data[i]
    }
    out
}

func _copy_tensor(tensor value) tensor {
    new(_copy_float(value.data), _copy_int(value.shape), value.requires_grad)
}

func _copy_layer(transformer_layer layer) transformer_layer {
    transformer_layer {
        w_q: _copy_tensor(layer.w_q),
        w_k: _copy_tensor(layer.w_k),
        w_v: _copy_tensor(layer.w_v),
        w_o: _copy_tensor(layer.w_o),
        w_ff1: _copy_tensor(layer.w_ff1),
        w_ff2: _copy_tensor(layer.w_ff2),
        b_ff1: _copy_tensor(layer.b_ff1),
        b_ff2: _copy_tensor(layer.b_ff2),
    }
}

func _copy_layers(transformer_layer[] layers) transformer_layer[] {
    int n = len(layers)
    transformer_layer[] out = []transformer_layer{cap: n}
    for i in 0..n {
        out.push(_copy_layer(layers[i]))
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
    transformer_layer[] layers
}

func transformer_init(config transformer_config) transformer {
    transformer_layer[] mut layers = []
    int i = 0
    while i < config.num_layers {
        transformer_layer layer = transformer_layer {
            w_q: tensor_randn([config.d_model, config.d_model]),
            w_k: tensor_randn([config.d_model, config.d_model]),
            w_v: tensor_randn([config.d_model, config.d_model]),
            w_o: tensor_randn([config.d_model, config.d_model]),
            w_ff1: tensor_randn([config.d_model, config.d_ff]),
            w_ff2: tensor_randn([config.d_ff, config.d_model]),
            b_ff1: tensor_zeros([config.d_ff]),
            b_ff2: tensor_zeros([config.d_model])
        }
        layers.push(layer)
        i += 1
    }
    transformer {
        config: config,
        layers: layers
    }
}

func transformer_state_dict(transformer state) transformer {
    transformer {
        config: state.config,
        layers: _copy_layers(state.layers),
    }
}

func transformer_load_state_dict(transformer state, transformer other) transformer {
    del state
    transformer {
        config: other.config,
        layers: _copy_layers(other.layers),
    }
}

func transformer_forward(m transformer, x tensor) tensor {
    int i = 0
    tensor out = x
    while i < m.config.num_layers {
        out = transformer_layer_forward(m.layers[i], out, m.config)
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
