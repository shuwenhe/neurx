package examples.train_end_to_end

func simple_forward(float w, float b, float x) float {
    return w * x + b
}

func compute_loss_mse(float pred, float target) float {
    float diff = pred - target
    return diff * diff
}

func train_demo() float {
    float w = 0.5
    float b = 0.1
    float lr = 0.01
    float first_loss = 0.0
    float last_loss = 0.0
    int step = 0
    while step < 100 {
        float x = 1.0
        float target = 5.0
        float pred = simple_forward(w, b, x)
        float loss = compute_loss_mse(pred, target)
        if step == 0 {
            first_loss = loss
        }
        float dpred = 2.0 * (pred - target)
        float dw = dpred * x
        float db = dpred
        w = w - lr * dw
        b = b - lr * db
        if step == 99 {
            last_loss = loss
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
    float result = train_demo()
    if result > 0.5 {
        println("SUCCESS: Loss decreased during training")
    } else {
        println("FAILURE: Loss did not decrease")
    }
}
