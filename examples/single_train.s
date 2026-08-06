package examples.single_train

func train_single_step() int {
    float w = 1.0
    float b = 0.0
    float x = 2.0
    float target = 5.0
    float lr = 0.01
    float pred_before = w * x + b
    float loss_before = (pred_before - target) * (pred_before - target)
    float error = pred_before - target
    float grad_w = 2.0 * error * x
    float grad_b = 2.0 * error
    w = w - lr * grad_w
    b = b - lr * grad_b
    float pred_after = w * x + b
    float loss_after = (pred_after - target) * (pred_after - target)
    if loss_after < loss_before {
        return 1
    } else {
        return 0
    }
}

func main() {
    int result = train_single_step()
    if result == 1 {
        println("SUCCESS: Single step training works")
    } else {
        println("FAILURE: Loss increased")
    }
}

