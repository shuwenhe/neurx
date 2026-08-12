package neurx.nn.loss
struct cross_entropy_loss {
    reduction string
    label_smoothing f64
}


func cross_entropy_new(reduction string, label_smoothing f64) cross_entropy_loss {
    return cross_entropy_loss{
        reduction: reduction,
        label_smoothing: label_smoothing,
    }
}


func cross_entropy_forward(loss_fn cross_entropy_loss, logits [][]f64, targets []i64) f64 {
    batch_size := len(logits)
    num_classes := len(logits[0])
    total_loss := 0.0
    for i := 0; i < batch_size; i++ {
        target := int(targets[i])
        max_logit := logits[i][0]
        for j := 1; j < num_classes; j++ {
            if logits[i][j] > max_logit {
                max_logit = logits[i][j]
            }
        }
        exp_sum := 0.0
        exp_logits := make([]f64, num_classes)
        for j := 0; j < num_classes; j++ {
            exp_logits[j] = exp_approx(logits[i][j] - max_logit)
            exp_sum = exp_sum + exp_logits[j]
        }
        if target >= 0 && target < num_classes {
            prob := exp_logits[target] / exp_sum
            if prob <= 0.0 {
                prob = 1e-10
            }
            loss_val := -ln_approx(prob)
            if loss_fn.label_smoothing > 0.0 {
                smooth := loss_fn.label_smoothing / f64(num_classes)
                for j := 0; j < num_classes; j++ {
                    label := 0.0
                    if j == target {
                        label = 1.0 - loss_fn.label_smoothing + smooth
                    } else {
                        label = smooth
                    }
                    prob_j := exp_logits[j] / exp_sum
                    if prob_j <= 0.0 {
                        prob_j = 1e-10
                    }
                    loss_val = loss_val - label * ln_approx(prob_j) + label * ln_approx(label + 1e-10)
                }
            }
            total_loss = total_loss + loss_val
        }
    }
    if loss_fn.reduction == "mean" {
        return total_loss / f64(batch_size)
    } else if loss_fn.reduction == "sum" {
        return total_loss
    }
    return total_loss
}


struct mse_loss {
    reduction string
}


func mse_new(reduction string) mse_loss {
    return mse_loss{reduction: reduction}
}


func mse_forward(loss_fn mse_loss, pred []f64, target []f64) f64 {
    if len(pred) != len(target) {
        return 0.0
    }
    total_loss := 0.0
    for i := 0; i < len(pred); i++ {
        diff := pred[i] - target[i]
        total_loss = total_loss + diff*diff
    }
    if loss_fn.reduction == "mean" {
        return total_loss / f64(len(pred))
    } else if loss_fn.reduction == "sum" {
        return total_loss
    }
    return total_loss
}


struct bce_loss {
    reduction string
}


func bce_new(reduction string) bce_loss {
    return bce_loss{reduction: reduction}
}


func bce_forward(loss_fn bce_loss, pred []f64, target []f64) f64 {
    if len(pred) != len(target) {
        return 0.0
    }
    total_loss := 0.0
    for i := 0; i < len(pred); i++ {
        p := pred[i]
        if p <= 0.0 {
            p = 1e-10
        }
        if p >= 1.0 {
            p = 1.0 - 1e-10
        }
        loss_val := -target[i]*ln_approx(p) - (1.0-target[i])*ln_approx(1.0-p)
        total_loss = total_loss + loss_val
    }
    if loss_fn.reduction == "mean" {
        return total_loss / f64(len(pred))
    }
    return total_loss
}


struct kldiv_loss {
    reduction string
}


func kldiv_new(reduction string) kldiv_loss {
    return kldiv_loss{reduction: reduction}
}


func kldiv_forward(loss_fn kldiv_loss, log_pred []f64, target []f64) f64 {
    if len(log_pred) != len(target) {
        return 0.0
    }
    total_loss := 0.0
    for i := 0; i < len(log_pred); i++ {
        if target[i] > 0.0 {
            total_loss = total_loss + target[i] * (ln_approx(target[i] + 1e-10) - log_pred[i])
        }
    }
    if loss_fn.reduction == "mean" {
        return total_loss / f64(len(log_pred))
    }
    return total_loss
}


struct l1_loss {
    reduction string
}


func l1_new(reduction string) l1_loss {
    return l1_loss{reduction: reduction}
}


func l1_forward(loss_fn l1_loss, pred []f64, target []f64) f64 {
    if len(pred) != len(target) {
        return 0.0
    }
    total_loss := 0.0
    for i := 0; i < len(pred); i++ {
        diff := pred[i] - target[i]
        if diff < 0.0 {
            diff = -diff
        }
        total_loss = total_loss + diff
    }
    if loss_fn.reduction == "mean" {
        return total_loss / f64(len(pred))
    }
    return total_loss
}


func exp_approx(x f64) f64 {
    if x > 100.0 {
        return 1e10
    }
    if x < -100.0 {
        return 1e-10
    }
    result := 1.0
    term := 1.0
    for i := 1; i <= 20; i++ {
        term = term * x / f64(i)
        result = result + term
        if term < 1e-10 && term > -1e-10 {
            break
        }
    }
    return result
}


func ln_approx(x f64) f64 {
    if x <= 0.0 {
        return -100.0
    }
    if x == 1.0 {
        return 0.0
    }
    if x > 0.0 && x <= 2.0 {
        z := (x - 1.0) / (x + 1.0)
        result := 0.0
        term := z
        z_squared := z * z
        for i := 0; i < 20; i++ {
            result = result + term / f64(2*i + 1)
            term = term * z_squared
            if term < 1e-10 && term > -1e-10 {
                break
            }
        }
        return 2.0 * result
    } else {
        exp := 0.0
        y := x
        for y > 2.0 {
            y = y / 2.0
            exp = exp + 1.0
        }
        for y < 1.0 {
            y = y * 2.0
            exp = exp - 1.0
        }
        return ln_approx(y) + exp*0.693147180559945
    }
}

