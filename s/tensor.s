package neurx.tensor

// Tensor 结构体定义
struct Tensor {
    data: []f32
    shape: []int32
    requires_grad: bool
    grad: option[Tensor]
}

// 创建新 Tensor
func new(data: []f32, shape: []int32, requires_grad: bool) Tensor {
    Tensor {
        data: data,
        shape: shape,
        requires_grad: requires_grad,
        grad: none,
    }
}

// 基础加法算子
func add(a: Tensor, b: Tensor) Tensor {
    // TODO: shape 检查与广播
    let n = len(a.data)
    let mut out = []f32{cap: n}
    for i in 0..n {
        out.push(a.data[i] + b.data[i])
    }
    new(out, a.shape, a.requires_grad || b.requires_grad)
}

// TODO: 实现 sub、mul、div、matmul 等基础算子
