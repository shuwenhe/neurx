package neurx.loss.nn_losses
use neurx.tensor.tensor
func copy_int([]int data) []int {
    int n = len(data)
    []int out = make([]int, n)
    int i = 0
    for i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func exp_approx(float x) float {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    for i <= 10 {
        term = term * x / i
        result = result + term
        i = i + 1
    }
    result
}

func mse_loss(tensor input, tensor target) tensor {
    tensor diff = neurx.tensor.sub(input, target)
    tensor sq = neurx.tensor.mul(diff, diff)
    return neurx.tensor.mean(sq)
}

func l1_loss(tensor input, tensor target) tensor {
    tensor diff = neurx.tensor.sub(input, target)
    return neurx.tensor.mean(neurx.tensor.abs(diff))
}

func cross_entropy_loss(tensor logits, tensor target) tensor {
    tensor log_probs = neurx.tensor.log_softmax(logits, -1)
    int n = len(target.data)
    if n <= 0 {
        return neurx.tensor.scalar_tensor(0.0)
    }
    int classes = logits.shape[len(logits.shape) - 1]
    float loss = 0.0
    int i = 0
    for i < n {
        int cls = target.data[i]
        if cls < 0 {
            cls = 0
        }
        if cls >= classes {
            cls = classes - 1
        }
        loss = loss - log_probs.data[i * classes + cls]
        i = i + 1
    }
    loss = loss / n
    return neurx.tensor.scalar_tensor(loss)
}

func bce_with_logits_loss(tensor logits, tensor target) tensor {
    tensor probs = neurx.tensor.sigmoid(logits)
    tensor one = neurx.tensor.ones_like(probs)
    tensor safe_probs = neurx.tensor.clamp(probs, 1e-6, 1.0 - 1e-6)
    tensor loss_pos = neurx.tensor.mul(target, neurx.tensor.log(safe_probs))
    tensor loss_neg = neurx.tensor.mul(neurx.tensor.sub(one, target), neurx.tensor.log(neurx.tensor.sub(one, safe_probs)))
    tensor total = neurx.tensor.negative(neurx.tensor.add(loss_pos, loss_neg))
    return neurx.tensor.mean(total)
}

func nll_loss(tensor log_probs, tensor target) tensor {
    int n = len(target.data)
    if n <= 0 {
        return neurx.tensor.scalar_tensor(0.0)
    }
    int classes = log_probs.shape[len(log_probs.shape) - 1]
    float loss = 0.0
    int i = 0
    for i < n {
        int cls = target.data[i]
        if cls < 0 {
            cls = 0
        }
        if cls >= classes {
            cls = classes - 1
        }
        loss = loss - log_probs.data[i * classes + cls]
        i = i + 1
    }
    return neurx.tensor.scalar_tensor(loss / n)
}

func smooth_l1_loss(tensor input, tensor target, float beta) tensor {
    tensor diff = neurx.tensor.sub(input, target)
    tensor abs_diff = neurx.tensor.abs(diff)
    int n = len(abs_diff.data)
    []float out = make([]float, n)
    int i = 0
    for i < n {
        float d = abs_diff.data[i]
        if d < beta {
            out[i] = 0.5 * d * d / beta
        } else {
            out[i] = d - 0.5 * beta
        }
        i = i + 1
    }
    return neurx.tensor.new(out, copy_int(abs_diff.shape), diff.requires_grad)
}

func huber_loss(tensor input, tensor target, float delta) tensor {
    return smooth_l1_loss(input, target, delta)
}

func binary_cross_entropy(tensor input, tensor target) tensor {
    tensor one = neurx.tensor.ones_like(input)
    tensor safe_input = neurx.tensor.clamp(input, 1e-6, 1.0 - 1e-6)
    tensor loss_pos = neurx.tensor.mul(target, neurx.tensor.log(safe_input))
    tensor loss_neg = neurx.tensor.mul(neurx.tensor.sub(one, target), neurx.tensor.log(neurx.tensor.sub(one, safe_input)))
    tensor total = neurx.tensor.negative(neurx.tensor.add(loss_pos, loss_neg))
    return neurx.tensor.mean(total)
}

func kl_div_loss(tensor input_log_probs, tensor target, bool log_target) tensor {
    int n = len(input_log_probs.data)
    if len(target.data) < n {
        n = len(target.data)
    }
    if n <= 0 {
        return neurx.tensor.scalar_tensor(0.0)
    }
    float loss = 0.0
    int i = 0
    for i < n {
        float target_prob = target.data[i]
        float target_log = 0.0
        if log_target {
            target_log = target.data[i]
            target_prob = exp_approx(target.data[i])
        } else {
            if target_prob > 0.0 {
                target_log = neurx.tensor.log(neurx.tensor.scalar_tensor(target_prob)).data[0]
            }
        }
        if target_prob > 0.0 {
            loss = loss + target_prob * (target_log - input_log_probs.data[i])
        }
        i = i + 1
    }
    return neurx.tensor.scalar_tensor(loss / n)
}

func margin_ranking_loss(tensor input1, tensor input2, tensor target, float margin) tensor {
    int n = len(input1.data)
    if len(input2.data) < n {
        n = len(input2.data)
    }
    if len(target.data) < n {
        n = len(target.data)
    }
    if n <= 0 {
        return neurx.tensor.scalar_tensor(0.0)
    }
    float loss = 0.0
    int i = 0
    for i < n {
        float v = 0.0 - target.data[i] * (input1.data[i] - input2.data[i]) + margin
        if v > 0.0 {
            loss = loss + v
        }
        i = i + 1
    }
    return neurx.tensor.scalar_tensor(loss / n)
}

func triplet_margin_loss(tensor anchor, tensor positive, tensor negative, float margin, int p, float eps) tensor {
    tensor pos_dist = pairwise_distance(anchor, positive, p, eps)
    tensor neg_dist = pairwise_distance(anchor, negative, p, eps)
    float v = pos_dist.data[0] - neg_dist.data[0] + margin
    if v < 0.0 {
        v = 0.0
    }
    return neurx.tensor.scalar_tensor(v)
}

func cosine_embedding_loss(tensor input1, tensor input2, tensor target, float margin) tensor {
    tensor cos = cosine_similarity(input1, input2, len(input1.shape) - 1, 1e-8)
    int n = len(cos.data)
    if len(target.data) < n {
        n = len(target.data)
    }
    if n <= 0 {
        return neurx.tensor.scalar_tensor(0.0)
    }
    float loss = 0.0
    int i = 0
    for i < n {
        if target.data[i] >= 0.0 {
            loss = loss + (1.0 - cos.data[i])
        } else {
            float v = cos.data[i] - margin
            if v > 0.0 {
                loss = loss + v
            }
        }
        i = i + 1
    }
    return neurx.tensor.scalar_tensor(loss / n)
}

func cosine_similarity(tensor x, tensor y, int dim, float eps) tensor {
    tensor xy = neurx.tensor.mul(x, y)
    tensor x2 = neurx.tensor.mul(x, x)
    tensor y2 = neurx.tensor.mul(y, y)
    tensor num = neurx.tensor.sum_dim(xy, dim, false)
    tensor den_x = neurx.tensor.sqrt(neurx.tensor.sum_dim(x2, dim, false))
    tensor den_y = neurx.tensor.sqrt(neurx.tensor.sum_dim(y2, dim, false))
    tensor den = neurx.tensor.add(neurx.tensor.mul(den_x, den_y), neurx.tensor.scalar_tensor(eps))
    return neurx.tensor.div(num, den)
}

func pairwise_distance(tensor x, tensor y, int p, float eps) tensor {
    tensor diff = neurx.tensor.abs(neurx.tensor.sub(x, y))
    if p <= 1 {
        return neurx.tensor.add(neurx.tensor.sum(diff), neurx.tensor.scalar_tensor(eps))
    }
    if p == 2 {
        return neurx.tensor.sqrt(neurx.tensor.add(neurx.tensor.sum(neurx.tensor.mul(diff, diff)), neurx.tensor.scalar_tensor(eps)))
    }
    tensor powered = diff
    int i = 1
    for i < p {
        powered = neurx.tensor.mul(powered, diff)
        i = i + 1
    }
    tensor total = neurx.tensor.add(neurx.tensor.sum(powered), neurx.tensor.scalar_tensor(eps))
    return neurx.tensor.exp(neurx.tensor.div(neurx.tensor.log(total), neurx.tensor.scalar_tensor(p)))
}
