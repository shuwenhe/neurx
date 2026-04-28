package neurx.test_autograd

use neurx.tensor.{tensor, new, add}
use neurx.autograd.backward

func main() int32 {
    let a = new([1.0, 2.0], [2], true)
    let b = new([3.0, 4.0], [2], true)
    let c = add(a, b)
    backward(c)
    println("a.grad = ", a.grad)
    println("b.grad = ", b.grad)
    0
}
