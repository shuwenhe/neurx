package neurx.test_autograd

use neurx.tensor.{tensor, new, add}
use neurx.autograd.{autograd_state, new_state, register_tensor, backward_seed, grad_of}

func main() int {
    tensor a = new([1.0, 2.0], [2], true)
    tensor b = new([3.0, 4.0], [2], true)
    tensor c = add(a, b)

    autograd_state state0 = new_state()
    autograd_state state1 = register_tensor(state0, 1, c)
    autograd_state state2 = backward_seed(state1, 1, c)
    []float grad = grad_of(state2, 1)

    println("loss.grad = ", grad)
    0
}
