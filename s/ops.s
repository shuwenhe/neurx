package neurx.ops

use neurx.tensor.Tensor

// 基础算子接口
func add(a: Tensor, b: Tensor) Tensor {
    // 直接调用 tensor.s 中的 add
    neurx.tensor.add(a, b)
}

// TODO: 实现更多算子接口
