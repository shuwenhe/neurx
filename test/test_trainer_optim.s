package neurx.test_trainer_optim

use neurx.trainer.{new_config, init_state, apply_sgd, apply_adam, apply_rmsprop}
use neurx.tensor.new

func main() int {
    var config = new_config(1, 1, 0.1, 1.0)
    var state = init_state(config)

    var params = new([1.0, 2.0], [2], true)
    var grads = new([0.5, -1.0], [2], false)

    var output_sgd = apply_sgd(state, params, grads)
    println("sgd updated params: ", output_sgd.params.data)

    var output_adam = apply_adam(state, params, grads)
    println("adam updated params: ", output_adam.params.data)

    var output_rmsprop = apply_rmsprop(state, params, grads)
    println("rmsprop updated params: ", output_rmsprop.params.data)
    0
}
