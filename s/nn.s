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
