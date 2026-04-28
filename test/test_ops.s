package neurx.test_ops

use neurx.tensor.{Tensor, new}
use neurx.ops.add

func main() int32 {
    let a = new([10.0, 20.0], [2], false)
    let b = new([1.0, 2.0], [2], false)
    let c = add(a, b)
    println("ops.add result: ", c.data)
    // 期望输出: [11.0, 22.0]
    0
}
