package neurx.nn

use neurx.tensor.tensor

struct linear {
    int32 in_features
    int32 out_features
    []f32 weight
    []f32 bias
}

func new_linear(int32 in_features, int32 out_features) linear {
    let weight_size = in_features * out_features
    let mut weight = []f32{cap: weight_size}
    let mut bias = []f32{cap: out_features}

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
    let batch = input.shape[0]
    let in_features = layer.in_features
    let out_features = layer.out_features
    let mut out = []f32{cap: batch * out_features}

    for b in 0..batch {
        for j in 0..out_features {
            let mut acc = layer.bias[j]
            for i in 0..in_features {
                let x = input.data[b * in_features + i]
                let w = layer.weight[j * in_features + i]
                acc = acc + x * w
            }
            out.push(acc)
        }
    }

    neurx.tensor.new(out, [batch, out_features], input.requires_grad)
}
