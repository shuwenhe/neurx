package neurx.test_autograd

use neurx.tensor.{tensor, new, add}
use neurx.autograd.{new_state, register_tensor, backward_seed, grad_of}

func main() int {
    let a = new([1.0, 2.0], [2], true)
    let b = new([3.0, 4.0], [2], true)
    let c = add(a, b)

    let state0 = new_state()
    let state1 = register_tensor(state0, 1, c)
    let state2 = backward_seed(state1, 1, c)
    let grad = grad_of(state2, 1)

    println("loss.grad = ", grad)
    0
}
