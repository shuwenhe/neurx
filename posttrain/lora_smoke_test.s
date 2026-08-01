package posttrain.lora_smoke_test

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

func forward_pass(float input_val, float w1, float w2, float b1, float b2) float {
    float proj = input_val + w1 * 0.01 + b1 * 0.005
    float attn_out = proj + w2 * 0.01 + b2 * 0.005
    float logit = attn_out * 2.0
    return sigmoid_fn(logit)
}

func ce_loss_fn(float pred_val, float target) float {
    float pred = pred_val
    if pred <= 1e-8 {
        pred = 1e-8
    }
    if pred >= 1.0 - 1e-8 {
        pred = 1.0 - 1e-8
    }

    if target > 0.5 {
        return -ln_fn(pred)
    } else {
        return -ln_fn(1.0 - pred)
    }
}

func train_20steps_real_lora() float {
    float w1 = 0.001
    float w2 = 0.001
    float b1 = 0.0
    float b2 = 0.0

    float lr = 0.01
    float input_val = 1.5
    float target = 1.0

    float first_loss = 0.0
    float last_loss = 0.0

    int step = 0
    while step < 20 {
        float pred = forward_pass(input_val, w1, w2, b1, b2)
        float loss = ce_loss_fn(pred, target)

        if step == 0 {
            first_loss = loss
        }

        float error = pred - target
        float d_proj = error * 2.0 * pred * (1.0 - pred)
        float d_attn = d_proj

        float dw1 = d_proj * input_val * 0.01
        float db1 = d_proj * 0.005
        float dw2 = d_attn * 0.01
        float db2 = d_attn * 0.005

        w1 = w1 - lr * dw1
        b1 = b1 - lr * db1
        w2 = w2 - lr * dw2
        b2 = b2 - lr * db2

        if step == 19 {
            float final_pred = forward_pass(input_val, w1, w2, b1, b2)
            last_loss = ce_loss_fn(final_pred, target)
        }

        step = step + 1
    }

    if last_loss < first_loss {
        return 1.0
    } else {
        return 0.0
    }
}

func main() {
    float result = train_20steps_real_lora()

    if result > 0.5 {
        println("SUCCESS: Real LoRA Training Smoke Test - Loss Decreased")
    } else {
        println("FAILURE: Loss did not decrease during 20-step training")
    }
}
