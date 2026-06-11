package neurx.test_tensor

use neurx.tensor.{tensor, new, add}

func main() int {
    tensor a = new([1.0, 2.0, 3.0], [3], false)
    tensor b = new([4.0, 5.0, 6.0], [3], false)
    tensor c = add(a, b)
    println("a = ", a.data)
    println("b = ", b.data)
    println("c = a + b = ", c.data)
    0
}
