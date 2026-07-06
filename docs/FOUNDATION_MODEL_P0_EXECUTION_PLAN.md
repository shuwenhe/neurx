# NeurX Foundation Model P0 执行清单

这个清单只覆盖“工业级 GPT 训练的最小闭环”：

1. 数据能真实读写
2. 训练能真实跑起来
3. checkpoint 能真实保存和恢复
4. 分布式接口不再停留在注释/占位

不解决这些，`train/neurx` 只能算“训练框架原型”，不能算工业训练系统。

## P0 目标

### 必须达成

- 用真实数据文件跑一次完整训练
- 至少支持单机单卡和单机多卡的统一入口
- 能保存 checkpoint 并从 checkpoint 恢复
- 能记录 step / loss / lr / grad_norm / tokens
- 训练失败后可以重启继续

### 非目标

- 不要求先把 70B / 175B 真正训练起来
- 不要求先完成所有 RLHF / reasoning 阶段
- 不要求先完成全部 GPU kernel 优化

## 当前缺口

### 1. 数据工程还没有闭环

涉及文件：

- `train/neurx/data/shard_manager.s`
- `train/neurx/data/dataloader.s`
- `train/neurx/pretrain/data/pretrain_data.s`
- `train/neurx/data/data_pipeline.s`

主要问题：

- 文件系统 helper 仍是占位实现
- checksum、压缩、manifest 落盘还没接通
- shard 发现、扫描、校验、恢复都不是实做

最小修复顺序：

1. 先实现文件 I/O helper
2. 再实现 manifest 读写
3. 再实现 shard 校验与恢复
4. 最后接到 dataloader / pretrain data state

### 2. checkpoint 还不够工业化

涉及文件：

- `train/neurx/train/sharded_checkpoint.s`
- `train/neurx/train/checkpoint.s`
- `train/neurx/train/checkpoint_manager.s`
- `train/neurx/storage/checkpoint_restore.s`

主要问题：

- checkpoint 序列化函数还是 placeholder
- checksum 没有真实实现
- optimizer state、scaler state、data cursor 的恢复不完整
- 没有明确的原子写入策略

最小修复顺序：

1. 完成参数 / optimizer / state 的序列化格式
2. 完成 checksum
3. 完成 checkpoint 落盘与恢复
4. 完成 latest / best / step checkpoint 约定

### 3. 分布式运行时还在骨架阶段

涉及文件：

- `train/neurx/distributed/distributed_training_coordinator.s`
- `train/neurx/distributed/ddp/ddp.s`
- `train/neurx/distributed/fsdp/fsdp_optimizer.s`
- `train/neurx/distributed/tensor_parallel.s`
- `train/neurx/distributed/pipeline_parallel.s`
- `train/neurx/distributed/sequence_parallel.s`
- `train/neurx/distributed/zero_optimizer.s`

主要问题：

- parallel group 构造没有变成可执行运行时
- forward / backward 的通信是注释或简化版
- 没有稳定的 rank 初始化 / world size 协议

最小修复顺序：

1. 先把 world size / rank / group 初始化做成真实状态机
2. 再把 DP all-reduce 路径打通
3. 再接 TP / PP
4. 最后再做 FSDP / ZeRO 优化

### 4. 训练主循环还没有统一成一个真实入口

涉及文件：

- `train/neurx/train/neurx_foundation_model.s`
- `train/neurx/train/training_pipeline.s`
- `train/neurx/train/train_llm.s`
- `train/neurx/model/llm/model_large_train.s`
- `train/neurx/train/train_foundation_model.sh`

主要问题：

- 配置层、执行层、演示层分散
- 有的文件是规划，有的文件是 toy demo，有的文件是半成品训练
- 入口脚本在没有运行时的时候会退回占位模式

最小修复顺序：

1. 统一一个主入口
2. 主入口只接受配置，不再承载演示逻辑
3. 训练循环必须串起 data -> forward -> loss -> backward -> update -> checkpoint -> eval

## 推荐实施顺序

### Phase 0.1

- 文件：`train/neurx/data/shard_manager.s`
- 目标：真实 I/O、manifest、checksum、路径检测

### Phase 0.2

- 文件：`train/neurx/train/sharded_checkpoint.s`
- 目标：真实序列化、保存、恢复

### Phase 0.3

- 文件：`train/neurx/train/training_pipeline.s`
- 目标：统一训练循环和恢复逻辑

### Phase 0.4

- 文件：`train/neurx/distributed/distributed_training_coordinator.s`
- 目标：把分布式接口从注释升级成可执行状态机

## 验收标准

P0 完成时，至少满足以下条件：

1. 单机单卡可以从真实数据启动训练
2. 训练中断后可以从 checkpoint 恢复
3. 至少一个评估指标可以在训练中周期性输出
4. 日志里能看到真实 step / loss / lr / grad norm
5. 代码里不再依赖 “placeholder” 才能解释训练流程

## 直接下一步建议

如果继续往下做，优先顺序是：

1. `train/neurx/data/shard_manager.s`
2. `train/neurx/train/sharded_checkpoint.s`
3. `train/neurx/train/training_pipeline.s`

