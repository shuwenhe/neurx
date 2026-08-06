package examples.train_simple
func rand_float() float {
    int seed = 42
    seed = (seed * 1103515245 + 12345) % 2147483648
    return float(seed % 10000) / 10000.0
}
func exp_approx(float x) float {
    if x > 50.0 {
        return 1e10
    }
    if x < -50.0 {
        return 0.0
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    while i < 15 {
        term = term * x / float(i)
        result = result + term
        i = i + 1
    }
    return result
}
func sigmoid(float x) float {
    if x > 100.0 {
        return 1.0
    }
    if x < -100.0 {
        return 0.0
    }
    return 1.0 / (1.0 + exp_approx(-x))
}
func train_steps() float {
    float w = rand_float() - 0.5
    float b = 0.0
    float lr = 0.1
    float total_loss = 0.0
    int step = 0
    while step < 100 {
        int i = 0
        float loss_sum = 0.0
        while i < 10 {
            float x = float(i) * 0.1
            float y = 1.0
            if i < 5 {
                y = 0.0
            }
            float logit = w * x + b
            float pred = sigmoid(logit)
            float loss = 0.0
            if y > 0.5 {
                if pred < 1e-7 {
                    pred = 1e-7
                }
                loss = -ln_approx(pred)
            } else {
                if pred > 1.0 - 1e-7 {
                    pred = 1.0 - 1e-7
                }
                loss = -ln_approx(1.0 - pred)
            }
            loss_sum = loss_sum + loss
            float dloss_dpred = 0.0
            if y > 0.5 {
                dloss_dpred = -1.0 / pred
            } else {
                dloss_dpred = 1.0 / (1.0 - pred)
            }
            float dpred_dlogit = pred * (1.0 - pred)
            float dloss_dlogit = dloss_dpred * dpred_dlogit
            float dw = dloss_dlogit * x
            float db = dloss_dlogit
            w = w - lr * dw * 0.1
            b = b - lr * db * 0.1
            i = i + 1
        }
        total_loss = total_loss + loss_sum / 10.0
        step = step + 1
    }
    return total_loss
}
func ln_approx(float x) float {
    if x <= 0.0 {
        return -100.0
    }
    if x >= 1.0 {
        float result = 0.0
        float y = (x - 1.0) / (x + 1.0)
        float y2 = y * y
        float term = y
        int i = 0
        while i < 20 {
            result = result + term / float(2 * i + 1)
            term = term * y2
            i = i + 1
        }
        return 2.0 * result
    } else {
        float inv = 1.0 / x
        return -ln_approx(inv)
    }
}
func main() {
    float loss = train_steps()
    if loss > 0.0 {
        println("Training completed. Loss sum: " + float_to_string(loss))
    } else {
        println("Training failed")
    }
}
func float_to_string(float f) string {
    int i_part = int(f)
    float frac_part = f - float(i_part)
    if frac_part < 0.0 {
        frac_part = -frac_part
    }
    int frac_int = int(frac_part * 10000.0)
    return int_to_string(i_part) + "." + int_to_string(frac_int)
}
