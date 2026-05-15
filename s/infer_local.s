package neurx.infer_local

use neurx.checkpoint.{load_checkpoint, checkpoint_params, checkpoint_param_count}
use neurx.creation.{randn}
use neurx.nn.{matmul2d}
use neurx.tensor.{unsqueeze, add}

/*
示例 S 脚本：加载本地 checkpoint 并用最简单的线性层参数执行一次前向推理。

使用说明：
  1) 编辑下面的 `ckpt_path` 字符串为你的本地检查点路径（例如 /Volumes/YourDisk/models/model.pt）
  2) 编译运行前先编译 S 运行时：`make s-compile-runtime`
  3) 在可执行的 S 环境中运行（取决于你的 S 编译器/运行时），或将其整合到 neurx 的运行流程中。

注意：此示例假设 checkpoint 包含至少两个参数：权重 `W`（形状 [in,out]）和偏置 `b`（形状 [out]）。
如果你的模型参数组织不同，请相应调整索引与形状处理逻辑。
*/

func main() int {
    // TODO: 将此路径替换为你的本地 checkpoint 路径
    string ckpt_path = "/tmp/test_ckpt.pt"

    // 加载 checkpoint（S 层接口）
    checkpoint ck = load_checkpoint(ckpt_path)

    // 获取参数列表
    []tensor params = checkpoint_params(ck)
    int pcount = checkpoint_param_count(ck)

    // 简单日志
    open_file_append("/tmp/infer_local.log").write("[infer_local] loaded checkpoint with param count\n")

    if pcount < 1 {
        open_file_append("/tmp/infer_local.log").write("[infer_local] no params found in checkpoint\n")
        return 1
    }

    // 我们假设 params[0] 是 weight 矩阵，形状为 [in_features, out_features]
    tensor W = params[0]
    []int wshape = W.shape
    int in_features = 1
    int out_features = 1
    if len(wshape) >= 2 {
        in_features = wshape[0]
        out_features = wshape[1]
    }

    // 构建一个随机输入: batch x in_features
    []int input_shape = []int{cap: 2}
    input_shape[0] = 1
    input_shape[1] = in_features
    tensor x = randn(input_shape)

    // 前向：out = x @ W  （使用 neurx.nn.matmul2d）
    tensor out = matmul2d(x, W)

    // 如果存在 bias（params[1]），做广播相加
    if pcount >= 2 {
        tensor b = params[1]
        tensor b2 = unsqueeze(b, 0) // shape -> [1, out_features]
        out = add(out, b2)
    }

    open_file_append("/tmp/infer_local.log").write("[infer_local] inference completed\n")
    return 0
}
