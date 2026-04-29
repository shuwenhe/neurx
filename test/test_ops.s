package neurx.test_ops

use neurx.tensor.{tensor, new}
use neurx.ops.add

func main() int {
    var a = new([10.0, 20.0], [2], false)
    var b = new([1.0, 2.0], [2], false)
    var c = add(a, b)
    println("ops.add result: ", c.data)
    0
}
