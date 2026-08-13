package posttrain.scalar_bce_test

func sigmoid_fn(float x) float {
    if x > 100.0 {
        return 1.0
    }
    if x < -100.0 {
        return 0.0
    }
    return 1.0 / (1.0 + exp_fn(-x))
}

func exp_fn(float x) float {
    if x > 50.0 {
        return 1e10
    }
    if x < -50.0 {
        return 0.0
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    while i <= 15 {
        term = term * x / float(i)
        result = result + term
        i = i + 1
    }
    return result
}

func ln_fn(float x) float {
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
        return -ln_fn(inv)
    }
}

func forward_simple(float w1, float w2, float b1, float x) float {
    float z = w1 * x + w2 * 0.1 + b1
    return sigmoid_fn(z)
}

func bce_loss_fn(float pred, float target) float {
    float p = pred
    if p <= 1e-8 {
        p = 1e-8
    }
    if p >= 1.0 - 1e-8 {
        p = 1.0 - 1e-8
    }
    if target > 0.5 {
        return -ln_fn(p)
    } else {
        return -ln_fn(1.0 - p)
    }
}

func float_to_str(float f) string {
    int i_part = int(f)
    float frac = f - float(i_part)
    if frac < 0.0 {
        frac = -frac
    }
    int frac_int = int(frac * 10000.0)
    return int_to_string(i_part) + "." + int_to_string(frac_int)
}

func train_20_steps() float {
    float w1 = 0.5
    float w2 = 0.3
    float b1 = 0.0
    float x = 2.0
    float target = 1.0
    float lr = 0.1
    float first_loss = 0.0
    float last_loss = 0.0
    println("[Scalar BCE Training Test]")
    println("Initial: w1=0.5, w2=0.3, b1=0.0, x=2.0, target=1.0, lr=0.1")
    println("")
    int step = 0
    while step < 20 {
        float pred = forward_simple(w1, w2, b1, x)
        float loss = bce_loss_fn(pred, target)
        float z = w1 * x + w2 * 0.1 + b1
        float dz = pred - target
        float dw1 = dz * x
        float dw2 = dz * 0.1
        float db1 = dz
        if step == 0 {
            first_loss = loss
            println("Step 0: pred=" + float_to_str(pred) + " loss=" + float_to_str(loss))
            println("        z=" + float_to_str(z) + " dz=" + float_to_str(dz))
            println("        dw1=" + float_to_str(dw1) + " dw2=" + float_to_str(dw2) + " db1=" + float_to_str(db1))
        }
        w1 = w1 - lr * dw1
        w2 = w2 - lr * dw2
        b1 = b1 - lr * db1
        if step == 19 {
            float final_pred = forward_simple(w1, w2, b1, x)
            last_loss = bce_loss_fn(final_pred, target)
            float final_z = w1 * x + w2 * 0.1 + b1
            println("")
            println("Step 19: pred=" + float_to_str(final_pred) + " loss=" + float_to_str(last_loss))
            println("         z=" + float_to_str(final_z))
            println("         w1=" + float_to_str(w1) + " w2=" + float_to_str(w2) + " b1=" + float_to_str(b1))
        }
        step = step + 1
    }
    println("")
    if last_loss < first_loss {
        println("RESULT: loss decreased from " + float_to_str(first_loss) + " to " + float_to_str(last_loss))
        return 1.0
    } else {
        println("RESULT: loss INCREASED from " + float_to_str(first_loss) + " to " + float_to_str(last_loss))
        return 0.0
    }
}

func main() {
    float result = train_20_steps()
}
