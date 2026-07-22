package neurx.loss

use neurx.tensor.tensor
use neurx.tensor.new

struct loss {
    string name
}

func shape1(int n) []int {
    []int shape = []int{cap: 1}
    shape[0] = n
    shape
}

func copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
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
    while i <= 10 {
        term = term * x / i
        result = result + term
        i = i + 1
    }
    result
}

func log_approx(float x) float {
    float v = x
    if v <= 0.0 {
        v = 0.000000000001
    }
    float y = (v - 1.0) / (v + 1.0)
    float y2 = y * y
    float y3 = y2 * y
    float y5 = y3 * y2
    float y7 = y5 * y2
    2.0 * (y + (y3 / 3.0) + (y5 / 5.0) + (y7 / 7.0))
}

func scalar(float value, bool requires_grad) tensor {
    []float out = []float{cap: 1}
    out[0] = value
    new(out, shape1(1), requires_grad)
}

func mean_from_sum(float total, int n) float {
    if n <= 0 {
        return 0.0
    }
    total / n
}

func abs(float x) float {
    if x < 0.0 {
        return 0.0 - x
    }
    x
}

func sigmoid(float x) float {
    1.0 / (1.0 + exp_approx(0.0 - x))
}

func softplus(float x) float {
    if x > 20.0 {
        x
    } else {
        if x < -20.0 {
            0.0
        } else {
            log_approx(1.0 + exp_approx(x))
        }
    }
}

func new_loss() loss {
    loss { name: "generic" }
}

func cross_entropy_loss(tensor input, tensor target) tensor {

    int n = len(input.data)
    int ndim = len(input.shape)

    if ndim >= 2 && input.shape[1] > 1 {

        int batch_size = input.shape[0]
        int num_classes = input.shape[1]
        float total_loss = 0.0
        int valid_count = 0

        int b = 0
        while b < batch_size {
            int base = b * num_classes

            float max_v = input.data[base]
            int c = 1
            while c < num_classes {
                if input.data[base + c] > max_v {
                    max_v = input.data[base + c]
                }
                c = c + 1
            }

            float log_sum_exp = 0.0
            float sum_exp = 0.0
            c = 0
            while c < num_classes {
                float e = exp_approx(input.data[base + c] - max_v)
                sum_exp = sum_exp + e
                c = c + 1
            }
            if sum_exp > 0.0 {
                log_sum_exp = log_approx(sum_exp) + max_v
            }

            int target_class = 0
            if b < len(target.data) {
                int tc = target.data[b] as int
                if tc >= 0 && tc < num_classes {
                    target_class = tc
                }
            }

            float sample_loss = log_sum_exp - input.data[base + target_class]
            total_loss = total_loss + sample_loss
            valid_count = valid_count + 1
            b = b + 1
        }

        float mean_loss = 0.0
        if valid_count > 0 {
            mean_loss = total_loss / float(valid_count)
        }
        scalar(mean_loss, input.requires_grad || target.requires_grad)
    } else {

        float total = 0.0
        int i = 0
        while i < n {
            float x = input.data[i]
            float t = 0.0
            if i < len(target.data) {
                t = target.data[i]
            }

            if x > 20.0 {
                x = 20.0
            }
            if x < -20.0 {
                x = -20.0
            }

            float loss_val = 0.0
            if t > 0.5 {

                float neg_x = 0.0 - x
                if neg_x > 20.0 {
                    loss_val = neg_x
                } else {
                    if neg_x < -20.0 {
                        loss_val = 0.0
                    } else {
                        loss_val = log_approx(1.0 + exp_approx(neg_x))
                    }
                }
            } else {

                if x > 20.0 {
                    loss_val = x
                } else {
                    if x < -20.0 {
                        loss_val = 0.0
                    } else {
                        loss_val = log_approx(1.0 + exp_approx(x))
                    }
                }
            }
            total = total + loss_val
            i = i + 1
        }
        scalar(mean_from_sum(total, n), input.requires_grad || target.requires_grad)
    }
}

func bce_loss(tensor input, tensor target) tensor {
    int n = len(input.data)
    float total = 0.0
    int i = 0
    while i < n {
        float p = input.data[i]
        if p < 0.0000001 {
            p = 0.0000001
        }
        if p > 0.9999999 {
            p = 0.9999999
        }
        float t = 0.0
        if i < len(target.data) {
            t = target.data[i]
        }
        total = total - (t * log_approx(p) + (1.0 - t) * log_approx(1.0 - p))
        i = i + 1
    }
    scalar(mean_from_sum(total, n), input.requires_grad || target.requires_grad)
}

func bce_with_logits_loss(tensor input, tensor target) tensor {
    int n = len(input.data)
    float total = 0.0
    int i = 0
    while i < n {
        float logit = input.data[i]
        float t = 0.0
        if i < len(target.data) {
            t = target.data[i]
        }
        float max_logit = logit
        if max_logit < 0.0 {
            max_logit = 0.0
        }
        float abs_logit = abs(logit)
        float stable = log_approx(1.0 + exp_approx(0.0 - abs_logit))
        total = total + (max_logit - logit * t + stable)
        i = i + 1
    }
    scalar(mean_from_sum(total, n), input.requires_grad || target.requires_grad)
}

func l1_loss(tensor input, tensor target) tensor {
    int n = len(input.data)
    float total = 0.0
    int i = 0
    while i < n {
        float t = 0.0
        if i < len(target.data) {
            t = target.data[i]
        }
        total = total + abs(input.data[i] - t)
        i = i + 1
    }
    scalar(mean_from_sum(total, n), input.requires_grad || target.requires_grad)
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
    scalar(mean_from_sum(total, n), input.requires_grad || target.requires_grad)
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
        float adiff = abs(diff)
        if adiff < 1.0 {
            total = total + 0.5 * diff * diff
        } else {
            total = total + adiff - 0.5
        }
        i = i + 1
    }
    scalar(mean_from_sum(total, n), input.requires_grad || target.requires_grad)
}

func kl_div_loss(tensor input, tensor target) tensor {
    int n = len(input.data)
    float total = 0.0
    int i = 0
    while i < n {
        float t = 0.0
        if i < len(target.data) {
            t = target.data[i]
        }
        if t > 0.0 {
            total = total + t * (log_approx(t) - input.data[i])
        }
        i = i + 1
    }
    scalar(mean_from_sum(total, n), input.requires_grad || target.requires_grad)
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
        float lambda = softplus(x)
        if lambda < 0.0000001 {
            lambda = 0.0000001
        }
        total = total + lambda - t * log_approx(lambda)
        i = i + 1
    }
    scalar(mean_from_sum(total, n), input.requires_grad || target.requires_grad)
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
    scalar(mean_from_sum(total, n), input1.requires_grad || input2.requires_grad || target.requires_grad)
}

func triplet_margin_loss(tensor anchor, tensor positive, tensor negative) tensor {
    int n = len(anchor.data)
    float total = 0.0
    int i = 0
    while i < n {
        float pos = anchor.data[i] - positive.data[i]
        float neg = anchor.data[i] - negative.data[i]
        float margin = 1.0 + abs(pos) - abs(neg)
        if margin < 0.0 {
            margin = 0.0
        }
        total = total + margin
        i = i + 1
    }
    scalar(mean_from_sum(total, n), anchor.requires_grad || positive.requires_grad || negative.requires_grad)
}
