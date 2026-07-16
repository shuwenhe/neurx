# NeurX 工业级 1T GPT 缺口地图

**目的**: 识别 `train/neurx` 在 1T 级工业训练场景下还缺什么，以及补齐顺序。

## 结论

现在的仓库已经具备了大量模块和文档，但离“可稳定训练、可恢复、可评测、可部署”的工业级 1T GPT 仍有明显差距。

真正的缺口不在“有没有目录”，而在下面五个闭环：

1. 真实训练主循环
2. 真实数据管道
3. 真实分布式执行
4. 可恢复 checkpoint
5. 训练门禁与后训练链路

## P0: 不补就不能算能训练

### 1. 训练主循环没有闭合

需要补齐:
- `forward -> loss -> backward -> optimizer.step`
- 梯度累积
- 梯度裁剪
- 学习率调度
- 训练日志与指标记录

证据:
- `scripts/legacy/LAUNCH_1T_TRAINING.sh` 里的 Python 训练脚本仍是 `TODO`
- `training/moe_1t_orchestrator.s` 里数据加载还是占位实现
- `optimization/mixed_precision.s` 里有 placeholder backward

相关文件:
- [LAUNCH_1T_TRAINING.sh](/Users/shuwen/shuwen/train/neurx/scripts/legacy/LAUNCH_1T_TRAINING.sh#L178-L181)
- [moe_1t_orchestrator.s](/Users/shuwen/shuwen/train/neurx/training/moe_1t_orchestrator.s#L231-L257)
- [mixed_precision.s](/Users/shuwen/shuwen/train/neurx/optimization/mixed_precision.s#L512-L515)

### 2. 数据管道还不是工业级

需要补齐:
- 真实语料读取
- 清洗、去重、过滤
- 版本化分片
- tokenization 的稳定实现
- train/val/test 可重复切分

证据:
- `dataset/real_data_loader.s` 目前是 mock dataset
- `training/moe_1t_orchestrator.s` 里 `moe_1t_load_data_manifest()` 只是打印
- `scripts/legacy/LAUNCH_1T_TRAINING.sh` 要求 1T token，但仓库里没有对应的真实大规模数据流闭环

相关文件:
- [real_data_loader.s](/Users/shuwen/shuwen/train/neurx/dataset/real_data_loader.s#L25-L41)
- [moe_1t_orchestrator.s](/Users/shuwen/shuwen/train/neurx/training/moe_1t_orchestrator.s#L231-L257)
- [LAUNCH_1T_TRAINING.sh](/Users/shuwen/shuwen/train/neurx/scripts/legacy/LAUNCH_1T_TRAINING.sh#L224-L242)

### 3. 分布式编排还缺“可落地执行”

需要补齐:
- 真实进程组初始化
- TP / PP / DP / EP 的拓扑发现
- NCCL 健康检查
- 节点故障自动重启
- 多机启动器与环境注入

证据:
- `moe_1t_orchestrator.s` 读取了 rank/world size，但调度和实际通信逻辑仍偏框架化
- `LAUNCH_1T_TRAINING.sh` 假设 1024 GPU，但并未提供真正可执行的集群 launcher

相关文件:
- [moe_1t_orchestrator.s](/Users/shuwen/shuwen/train/neurx/training/moe_1t_orchestrator.s#L131-L224)
- [LAUNCH_1T_TRAINING.sh](/Users/shuwen/shuwen/train/neurx/scripts/legacy/LAUNCH_1T_TRAINING.sh#L110-L129)

### 4. Checkpoint 需要可验证恢复

需要补齐:
- 分片参数保存和恢复
- 优化器状态恢复
- 断点续训
- checksum / corruption 检测
- 恢复演练脚本

证据:
- `checkpoint/moe_1t_distributed_checkpoint.s` 有管理器结构，但仍需要端到端恢复验证

相关文件:
- [moe_1t_distributed_checkpoint.s](/Users/shuwen/shuwen/train/neurx/checkpoint/moe_1t_distributed_checkpoint.s#L1-L40)

## P1: 不补会严重影响收敛与成本

### 5. 优化器与混精稳定性不足

需要补齐:
- 完整 AdamW
- BF16 / FP16 训练主路径
- loss scaling
- overflow 检测
- 梯度裁剪策略

证据:
- `optimization/mixed_precision.s` 仍有 placeholder backward
- `distributed/zero_gradient_reduce.s` 里 AdamW 更新是简化实现

相关文件:
- [mixed_precision.s](/Users/shuwen/shuwen/train/neurx/optimization/mixed_precision.s#L512-L515)
- [zero_gradient_reduce.s](/Users/shuwen/shuwen/train/neurx/distributed/zero_gradient_reduce.s#L472-L484)

### 6. 评测门禁不足

需要补齐:
- perplexity
- validation loss
- throughput
- memory footprint
- checkpoint restore test
- regression benchmark

证据:
- 仓库里有大量测试文件，但缺少一条“训练前/训练中/训练后”统一评测门禁链路

相关文件:
- [TRAINING_COMPLETENESS_ANALYSIS.md](/Users/shuwen/shuwen/train/neurx/docs/TRAINING_COMPLETENESS_ANALYSIS.md#L10-L77)
- [MISSING_COMPONENTS_ANALYSIS.md](/Users/shuwen/shuwen/train/neurx/docs/MISSING_COMPONENTS_ANALYSIS.md#L29-L50)

### 7. 模型能力与结构还偏演示态

需要补齐:
- 更完整的 Transformer 层实现
- 更强的 long context 训练策略
- 更稳定的 attention / FFN / norm 路径

相关文件:
- [TRAINING_COMPLETENESS_ANALYSIS.md](/Users/shuwen/shuwen/train/neurx/docs/TRAINING_COMPLETENESS_ANALYSIS.md#L28-L40)

## P2: 上线前必须有，但不阻塞“能训”

### 8. 后训练链路

需要补齐:
- SFT
- 蒸馏
- 量化
- 导出
- 推理服务
- KV cache / batching / speculative decoding

### 9. 生产部署

需要补齐:
- 容器化
- 集群编排
- 发布策略
- 安全与隔离

### 10. 监控和运维

需要补齐:
- GPU 利用率
- 通信耗时
- step ETA
- 训练告警
- 历史趋势面板

## 建议补齐顺序

1. 训练主循环
2. 真实数据管道
3. 分布式 launcher
4. checkpoint 恢复
5. AdamW + mixed precision
6. 评测门禁
7. 后训练与部署

## 一句话判断

如果目标是“工业级 GPT 1T 训练”，当前仓库已经有很多模块名和框架壳，但还没把**训练、数据、分布式、恢复、评测**这五个闭环真正打通。
