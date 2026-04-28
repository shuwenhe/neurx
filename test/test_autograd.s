package neurx.test_autograd

use neurx.tensor.{Tensor, new, add}
use neurx.autograd.backward

func main() int32 {
    let a = new([1.0, 2.0], [2], true)
    let b = new([3.0, 4.0], [2], true)
    let c = add(a, b)
    // 假设 c 作为 loss，调用反向传播
    backward(c)
    println("a.grad = ", a.grad)
    println("b.grad = ", b.grad)
    0
}
