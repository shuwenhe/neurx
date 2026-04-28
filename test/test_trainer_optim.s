package neurx.test_trainer_optim

use neurx.trainer.{new_config, init_state, apply_sgd}
use neurx.tensor.new

func main() int {
    let config = new_config(1, 1, 0.1, 1.0)
    let state = init_state(config)

    let params = new([1.0, 2.0], [2], true)
    let grads = new([0.5, -1.0], [2], false)

    let output = apply_sgd(state, params, grads)
    println("sgd updated params: ", output.params.data)
    0
}
