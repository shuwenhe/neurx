package neurx.autograd

use neurx.tensor.Tensor

// 自动微分节点定义（雏形）
struct GradFn {
    // TODO: 记录操作类型、输入、输出等
}

// 反向传播入口
func backward(t: Tensor) () {
    // TODO: 遍历计算图，递归计算梯度
}
