package neurx.test_trainer_optim

use neurx.trainer.{trainer_config, trainer_state, trainer_step_output, new_config, init_state, apply_sgd, apply_adam, apply_rmsprop}
use neurx.tensor.{tensor, new}

func main() int {
    trainer_config config = new_config(1, 1, 0.1, 1.0)
    trainer_state state = init_state(config)

    tensor params = new([1.0, 2.0], [2], true)
    tensor grads = new([0.5, -1.0], [2], false)

    trainer_step_output output_sgd = apply_sgd(state, params, grads)
    println("sgd updated params: ", output_sgd.params.data)

    trainer_step_output output_adam = apply_adam(state, params, grads)
    println("adam updated params: ", output_adam.params.data)

    trainer_step_output output_rmsprop = apply_rmsprop(state, params, grads)
    println("rmsprop updated params: ", output_rmsprop.params.data)
    0
}
