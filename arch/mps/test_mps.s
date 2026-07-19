package neurx.mps_test

use neurx.tensor.{tensor, new}
use neurx.nn.{linear, new_linear, linear_forward}
use neurx.optimizer.optim_mvp.{sgd_optimizer, new_sgd, step_tensor}
use neurx.train.amp.{autocast_state, new_autocast_state, autocast_enter, autocast_exit, is_autocast_enabled, grad_scaler_state, new_grad_scaler, grad_scaler_step, grad_scaler_get_scale, grad_scaler_found_inf}
use neurx.train.logging.{training_logger_state, new_training_logger, training_logger_log, training_logger_flush, training_logger_is_enabled, training_logger_message_count, training_logger_last_flush_step}
use neurx.checkpoint.{checkpoint, new_checkpoint, checkpoint_step, checkpoint_loss, checkpoint_param_count}

func fail(string message) int {
    println("FAIL: ", message)
    1
}

func assert(bool condition, string message) int {
    if !condition {
        return fail(message)
    }
    0
}

func assert_eq_int(int actual, int expected, string message) int {
    if actual != expected {
        return fail(message)
    }
    0
}

func assert_eq_float(float actual, float expected, string message) int {
    if actual != expected {
        return fail(message)
    }
    0
}

func assert_eq_bool(bool actual, bool expected, string message) int {
    if actual != expected {
        return fail(message)
    }
    0
}

func linear_smoke() int {
    linear layer = new_linear(2, 2)
    tensor input = new([1.0, 2.0], [1, 2], false)
    tensor output = linear_forward(layer, input)

    int status = 0
    status = status + assert_eq_float(output.data[0], 0.0, "linear output[0] should be 0.0")
    status = status + assert_eq_float(output.data[1], 0.0, "linear output[1] should be 0.0")
    status
}

func optimizer_smoke() int {
    sgd_optimizer optimizer = new_sgd(0.1)
    tensor params = new([1.0, 2.0], [2], true)
    tensor grads = new([0.5, -1.0], [2], false)
    tensor updated = step_tensor(optimizer, params, grads)

    int status = 0
    status = status + assert_eq_float(updated.data[0], 0.95, "sgd update[0] should be 0.95")
    status = status + assert_eq_float(updated.data[1], 2.1, "sgd update[1] should be 2.1")
    status
}

func amp_smoke() int {
    autocast_state autocast = new_autocast_state(true, 7)
    autocast = autocast_enter(autocast)
    int status = 0
    status = status + assert_eq_bool(is_autocast_enabled(autocast), true, "autocast should be enabled after enter")
    autocast = autocast_exit(autocast)
    status = status + assert_eq_bool(is_autocast_enabled(autocast), false, "autocast should be disabled after exit")

    grad_scaler_state scaler = new_grad_scaler(1024.0, 2.0, 0.5, 2000, true)
    scaler = grad_scaler_step(scaler, 10000000000000000000000000000000000000000.0)
    status = status + assert_eq_float(grad_scaler_get_scale(scaler), 512.0, "grad scaler should back off to 512.0")
    status = status + assert_eq_bool(grad_scaler_found_inf(scaler), true, "grad scaler should mark found_inf")
    status
}

func checkpoint_smoke() int {
    int status = 0
    []tensor params = []tensor{cap: 0}
    checkpoint ckpt = new_checkpoint(3, 0.5, params)
    status = status + assert_eq_int(checkpoint_step(ckpt), 3, "checkpoint step should be 3")
    status = status + assert_eq_float(checkpoint_loss(ckpt), 0.5, "checkpoint loss should be 0.5")
    status = status + assert_eq_int(checkpoint_param_count(ckpt), 0, "checkpoint should have no params")
    status
}

func logging_smoke() int {
    training_logger_state logger = new_training_logger(true)
    logger = training_logger_log(logger, 2, 1)
    logger = training_logger_flush(logger, 2, 1)

    int status = 0
    status = status + assert_eq_bool(training_logger_is_enabled(logger), true, "logger should be enabled")
    status = status + assert_eq_int(training_logger_message_count(logger), 1, "logger should count one message")
    status = status + assert_eq_int(training_logger_last_flush_step(logger), 2, "logger flush step should be 2")
    status
}

func main() int {
    int status = 0
    status = status + linear_smoke()
    status = status + optimizer_smoke()
    status = status + amp_smoke()
    status = status + checkpoint_smoke()
    status = status + logging_smoke()

    if status == 0 {
        println("PASS: neurx MPS S smoke test")
    }
    status
}
