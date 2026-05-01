package neurx.lf.losses

use neurx.tensor.tensor
use neurx.tensor.new

struct loss {
    string name
}

func _shape1(int n) []int {
    []int shape = []int{cap: 1}
    shape[0] = n
    shape
}

func _copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func _copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func _scalar(float value, bool requires_grad) tensor {
    []float out = []float{cap: 1}
    out[0] = value
    new(out, _shape1(1), requires_grad)
}

func _mean_from_sum(float total, int n) float {
    if n <= 0 {
        return 0.0
    }
    total / n
}

func _abs(float x) float {
    if x < 0.0 {
        return 0.0 - x
    }
    x
}

func _sigmoid(float x) float {
    if x >= 0.0 {
        1.0 / (1.0 + 1.0 / (1.0 + x + (x * x / 2.0)))
    } else {
        float pos = 0.0 - x
        1.0 / (1.0 + (1.0 + pos + (pos * pos / 2.0)))
    }
}

func _softplus(float x) float {
    if x > 20.0 {
        x
    } else {
        if x < -20.0 {
            0.0
        } else {
            float e = 1.0 + x + (x * x / 2.0) + (x * x * x / 6.0)
            if e < 0.0 {
                e = 0.0
            }
            e
        }
    }
}

func new_loss() loss {
    loss { name: "generic" }
}

func cross_entropy_loss(tensor input, tensor target) tensor {
    int n = len(input.data)
    float total = 0.0
    int i = 0
    while i < n {
        float x = input.data[i]
        float t = 0.0
        if i < len(target.data) {
            t = target.data[i]
        }
        total = total - t * x
        i = i + 1
    }
    _scalar(_mean_from_sum(total, n), input.requires_grad || target.requires_grad)
}

func bce_loss(tensor input, tensor target) tensor {
    int n = len(input.data)
    float total = 0.0
    int i = 0
    while i < n {
        float p = input.data[i]
        if p < 0.000001 {
            p = 0.000001
        }
        if p > 0.999999 {
            p = 0.999999
        }
        float t = 0.0
        if i < len(target.data) {
            t = target.data[i]
        }
        total = total - (t * p + (1.0 - t) * (1.0 - p))
        i = i + 1
    }
    _scalar(_mean_from_sum(total, n), input.requires_grad || target.requires_grad)
}

func bce_with_logits_loss(tensor input, tensor target) tensor {
    int n = len(input.data)
    float total = 0.0
    int i = 0
    while i < n {
        float logit = input.data[i]
        float p = _sigmoid(logit)
        float t = 0.0
        if i < len(target.data) {
            t = target.data[i]
        }
        total = total - (t * p + (1.0 - t) * (1.0 - p))
        i = i + 1
    }
    _scalar(_mean_from_sum(total, n), input.requires_grad || target.requires_grad)
}

func l1_loss(tensor input, tensor target) tensor {
    int n = len(input.data)
    float total = 0.0
    int i = 0
    while i < n {
        float diff = input.data[i]
        if i < len(target.data) {
            diff = diff - target.data[i]
        }
        total = total + _abs(diff)
        i = i + 1
    }
    _scalar(_mean_from_sum(total, n), input.requires_grad || target.requires_grad)
}

func mse_loss(tensor input, tensor target) tensor {
    int n = len(input.data)
    float total = 0.0
    int i = 0
    while i < n {
        float diff = input.data[i]
        if i < len(target.data) {
            diff = diff - target.data[i]
        }
        total = total + diff * diff
        i = i + 1
    }
    _scalar(_mean_from_sum(total, n), input.requires_grad || target.requires_grad)
}

func smooth_l1_loss(tensor input, tensor target) tensor {
    int n = len(input.data)
    float total = 0.0
    int i = 0
    while i < n {
        float diff = input.data[i]
        if i < len(target.data) {
            diff = diff - target.data[i]
        }
        float adiff = _abs(diff)
        if adiff < 1.0 {
            total = total + 0.5 * diff * diff
        } else {
            total = total + adiff - 0.5
        }
        i = i + 1
    }
    _scalar(_mean_from_sum(total, n), input.requires_grad || target.requires_grad)
}

func kl_div_loss(tensor input, tensor target) tensor {
    int n = len(input.data)
    float total = 0.0
    int i = 0
    while i < n {
        float p = input.data[i]
        if p < 0.000001 {
            p = 0.000001
        }
        float t = 0.0
        if i < len(target.data) {
            t = target.data[i]
        }
        total = total + t * (0.0 - p)
        i = i + 1
    }
    _scalar(_mean_from_sum(total, n), input.requires_grad || target.requires_grad)
}

func nll_loss(tensor input, tensor target) tensor {
    cross_entropy_loss(input, target)
}

func huber_loss(tensor input, tensor target) tensor {
    smooth_l1_loss(input, target)
}

func poisson_nll_loss(tensor input, tensor target) tensor {
    int n = len(input.data)
    float total = 0.0
    int i = 0
    while i < n {
        float x = input.data[i]
        float t = 0.0
        if i < len(target.data) {
            t = target.data[i]
        }
        total = total + x - t * _softplus(x)
        i = i + 1
    }
    _scalar(_mean_from_sum(total, n), input.requires_grad || target.requires_grad)
}

func ctc_loss(tensor input, tensor target) tensor {
    cross_entropy_loss(input, target)
}

func margin_ranking_loss(tensor input1, tensor input2, tensor target) tensor {
    int n = len(input1.data)
    float total = 0.0
    int i = 0
    while i < n {
        float diff = input1.data[i] - input2.data[i]
        float t = 1.0
        if i < len(target.data) {
            t = target.data[i]
        }
        float margin = 1.0 - t * diff
        if margin < 0.0 {
            margin = 0.0
        }
        total = total + margin
        i = i + 1
    }
    _scalar(_mean_from_sum(total, n), input1.requires_grad || input2.requires_grad || target.requires_grad)
}

func triplet_margin_loss(tensor anchor, tensor positive, tensor negative) tensor {
    int n = len(anchor.data)
    float total = 0.0
    int i = 0
    while i < n {
        float pos = anchor.data[i] - positive.data[i]
        float neg = anchor.data[i] - negative.data[i]
        float margin = 1.0 + _abs(pos) - _abs(neg)
        if margin < 0.0 {
            margin = 0.0
        }
        total = total + margin
        i = i + 1
    }
    _scalar(_mean_from_sum(total, n), anchor.requires_grad || positive.requires_grad || negative.requires_grad)
}
