package neurx.test_ops

use neurx.tensor.{tensor, new}
use neurx.ops.add

func main() int {
    let a = new([10.0, 20.0], [2], false)
    let b = new([1.0, 2.0], [2], false)
    let c = add(a, b)
    println("ops.add result: ", c.data)
    0
}
