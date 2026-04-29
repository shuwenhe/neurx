package neurx.test_autograd

use neurx.tensor.{tensor, new, add}
use neurx.autograd.{new_state, register_tensor, backward_seed, grad_of}

func main() int {
    var a = new([1.0, 2.0], [2], true)
    var b = new([3.0, 4.0], [2], true)
    var c = add(a, b)

    var state0 = new_state()
    var state1 = register_tensor(state0, 1, c)
    var state2 = backward_seed(state1, 1, c)
    var grad = grad_of(state2, 1)

    println("loss.grad = ", grad)
    0
}
