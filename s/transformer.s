 

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
    let mut layers = []
    let i = 0
    while i < config.num_layers {
        let layer = transformer_layer{
            w_q: tensor_randn([config.d_model, config.d_model]),
            w_k: tensor_randn([config.d_model, config.d_model]),
            w_v: tensor_randn([config.d_model, config.d_model]),
            w_o: tensor_randn([config.d_model, config.d_model]),
            w_ff1: tensor_randn([config.d_model, config.d_ff]),
            w_ff2: tensor_randn([config.d_ff, config.d_model]),
            b_ff1: tensor_zeros([config.d_ff]),
            b_ff2: tensor_zeros([config.d_model]),
        }
        layers = array_push(layers, layer)
        i = i + 1
    }
    return transformer{config: config, layers: layers}
}

func transformer_forward(m transformer, x tensor) tensor {
    let i = 0
    let out = x
    while i < m.config.num_layers {
        out = transformer_layer_forward(m.layers[i], out, m.config)
        i = i + 1
    }
    return out
}

func transformer_layer_forward(layer transformer_layer, x tensor, config transformer_config) tensor {
    let q = matmul(x, layer.w_q)
    let k = matmul(x, layer.w_k)
    let v = matmul(x, layer.w_v)
    let attn = multihead_attention(q, k, v, config.num_heads)
    let attn_out = matmul(attn, layer.w_o)
    let x2 = add(x, attn_out)
    let ff1 = add(matmul(x2, layer.w_ff1), layer.b_ff1)
    let ff1_act = relu(ff1)
    let ff2 = add(matmul(ff1_act, layer.w_ff2), layer.b_ff2)
    let out = add(x2, ff2)
    return out
}

func multihead_attention(q tensor, k tensor, v tensor, num_heads int) tensor {
    
    let attn_scores = matmul(q, transpose(k))
    let attn_weights = softmax(attn_scores)
    let attn = matmul(attn_weights, v)
    return attn
}
