# neurx/s

本目录用于 neurx 项目 s 语言核心重写。

优先目标：
- Tensor 结构体与基础算子（加减乘除、矩阵乘法等）
- 自动微分引擎雏形
- 基础调度与模块接口

所有代码需可通过 s 语言工具链编译，并预留 Python FFI 边界。

当前模块：
- `tensor.s`: Tensor 结构与基础算子
- `ops.s`: 算子入口
- `autograd.s`: 自动微分雏形
- `schedule.s`: 调度雏形
- `nn.s`: 线性层与基础 nn 接口
- `multimodal.s`: 多模态 batch 抽象
- `trainer.s`: 训练配置与 step 状态
- `optim_mvp.s`: SGD 与学习率最小实现
- `dataloader_mvp.s`: 最小数据加载器（batch/seq 切片）
