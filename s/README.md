# neurx/s

本目录用于 neurx 项目 s 语言核心重写。

优先目标：
- Tensor 结构体与基础算子（加减乘除、矩阵乘法等）
- 自动微分引擎雏形
- 基础调度与模块接口

所有代码需可通过 s 语言工具链编译，并预留 Python FFI 边界。

当前模块：
- `ad/ad.s`: 自动微分状态、梯度开关与 backward 雏形
- `tensor.s`: Tensor 结构、构造与视图辅助函数、逐元素算子与矩阵乘法
- `ops.s`: 算子入口
- `autograd.s`: 自动微分雏形
- `schedule.s`: 调度雏形
- `nn/nn.s`: 线性层与基础 nn 接口
- `multimodal.s`: 多模态 batch 抽象
- `trainer.s`: 训练配置与 step 状态
- `opt/optim_mvp.s`: SGD 与学习率最小实现
- `dataloader_mvp.s`: 最小数据加载器（batch/seq 切片）
- `dl/dataset.s`: 数据集抽象、切分与拼接
- `dl/dataloader.s`: 数据加载与 batch 组装
- `lf/losses.s`: 损失函数入口与占位实现
