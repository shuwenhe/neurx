package neurx.nn

use neurx.tensor.tensor

struct linear {
    int in_features
    int out_features
    []float weight
    []float bias
}

func new_linear(int in_features, int out_features) linear {
    int weight_size = in_features * out_features
    []float weight = []float{cap: weight_size}
    []float bias = []float{cap: out_features}

    for i in 0..weight_size {
        weight.push(0.0)
    }

    for i in 0..out_features {
        bias.push(0.0)
    }

    linear {
        in_features: in_features,
        out_features: out_features,
        weight: weight,
        bias: bias,
    }
}

func linear_forward(linear layer, tensor input) tensor {
    int batch = input.shape[0]
    int in_features = layer.in_features
    int out_features = layer.out_features
    []float out = []float{cap: batch * out_features}

    for b in 0..batch {
        for j in 0..out_features {
            float acc = layer.bias[j]
            for i in 0..in_features {
                float x = input.data[b * in_features + i]
                float w = layer.weight[j * in_features + i]
                acc = acc + x * w
            }
            out.push(acc)
        }
    }

    neurx.tensor.new(out, [batch, out_features], input.requires_grad)
}

func layer_norm(tensor input, tensor weight, tensor bias, int normalized_dims, float eps) tensor {
    layer_norm(input, weight, bias, normalized_dims, eps)
}

func rms_norm(tensor input, tensor weight, tensor bias, int normalized_dims, float eps) tensor {
    rms_norm(input, weight, bias, normalized_dims, eps)
}

func mlp_block(tensor input, tensor fc1_weight, tensor fc1_bias, tensor fc2_weight, tensor fc2_bias) tensor {
    mlp_block(input, fc1_weight, fc1_bias, fc2_weight, fc2_bias)
}

func transformer_block_forward(tensor input, tensor ln1_weight, tensor ln1_bias, tensor qkv_weight, tensor qkv_bias, tensor out_weight, tensor out_bias, tensor ln2_weight, tensor ln2_bias, tensor fc1_weight, tensor fc1_bias, tensor fc2_weight, tensor fc2_bias, float eps, int n_heads) tensor {
    transformer_block_forward(input, ln1_weight, ln1_bias, qkv_weight, qkv_bias, out_weight, out_bias, ln2_weight, ln2_bias, fc1_weight, fc1_bias, fc2_weight, fc2_bias, eps, n_heads)
}

func qkv_projection(tensor input, tensor weight, tensor bias, int n_heads) tensor {
    qkv_projection(input, weight, bias, n_heads)
}

func rope_apply(tensor input, tensor cos, tensor sin) tensor {
    rope_apply(input, cos, sin)
}

func embedding_lookup(tensor weight, tensor input_ids, int padding_idx) tensor {
    embedding_lookup(weight, input_ids, padding_idx)
}
