# NeurX 1T GPT 文件级待办

**目标**: 把工业级 1T GPT 训练链路拆到具体文件，方便逐个补齐。

**新增实现**:
- [training/industrial_1t_training.s](/Users/shuwen/shuwen/train/neurx/training/industrial_1t_training.s)
- 该文件把训练主循环、数据管道、checkpoint、分布式执行、混精和优化器串成一条可运行的 S 管线。

## P0 - 先补这些，否则无法形成可跑训练闭环

### 1. 训练主循环

优先文件:
- [script/LAUNCH_1T_TRAINING.sh](/Users/shuwen/shuwen/train/neurx/script/LAUNCH_1T_TRAINING.sh)
- [training/moe_1t_orchestrator.s](/Users/shuwen/shuwen/train/neurx/training/moe_1t_orchestrator.s)
- [training/end_to_end_training.s](/Users/shuwen/shuwen/train/neurx/training/end_to_end_training.s)

要补的内容:
- 数据加载 -> forward -> loss -> backward -> optimizer.step
- 梯度累积
- 梯度裁剪
- 学习率调度
- 训练日志

### 2. 真实数据管道

优先文件:
- [dataset/real_data_loader.s](/Users/shuwen/shuwen/train/neurx/dataset/real_data_loader.s)
- [dataset/generate_training_data.s](/Users/shuwen/shuwen/train/neurx/dataset/generate_training_data.s)
- [tokenizer/bpe_tokenizer.s](/Users/shuwen/shuwen/train/neurx/tokenizer/bpe_tokenizer.s)
- [tokenizer/vocab_builder.s](/Users/shuwen/shuwen/train/neurx/tokenizer/vocab_builder.s)

要补的内容:
- BPE tokenizer 的真实实现
- 语料清洗和去重
- JSONL / shard / manifest 的稳定加载
- train/val/test 可复现切分
- 长序列 packing

### 3. 检查点恢复

优先文件:
- [checkpoint/moe_1t_distributed_checkpoint.s](/Users/shuwen/shuwen/train/neurx/checkpoint/moe_1t_distributed_checkpoint.s)
- [training/moe_1t_orchestrator.s](/Users/shuwen/shuwen/train/neurx/training/moe_1t_orchestrator.s)

要补的内容:
- 参数 shard 保存
- optimizer shard 保存
- checksum 校验
- 恢复后 step / tokens / epoch 对齐
- 断点恢复测试脚本

### 4. 分布式执行

优先文件:
- [distributed/gpt_distributed.s](/Users/shuwen/shuwen/train/neurx/distributed/gpt_distributed.s)
- [distributed/ddp_distributed_training.s](/Users/shuwen/shuwen/train/neurx/distributed/ddp_distributed_training.s)
- [distributed/pipeline_parallel.s](/Users/shuwen/shuwen/train/neurx/distributed/pipeline_parallel.s)
- [distributed/tensor_parallel.s](/Users/shuwen/shuwen/train/neurx/distributed/tensor_parallel.s)
- [distributed/zero_gradient_reduce.s](/Users/shuwen/shuwen/train/neurx/distributed/zero_gradient_reduce.s)
- [distributed/nccl_backend.s](/Users/shuwen/shuwen/train/neurx/distributed/nccl_backend.s)

要补的内容:
- 真正的进程组初始化
- TP / PP / DP / EP 的切分
- NCCL 健康检查
- 集群启动器
- 故障恢复重试

## P1 - 会显著影响训练质量和成本

### 5. 优化器与混合精度

优先文件:
- [optimization/mixed_precision.s](/Users/shuwen/shuwen/train/neurx/optimization/mixed_precision.s)
- [distributed/mixed_precision/mixed_precision.s](/Users/shuwen/shuwen/train/neurx/distributed/mixed_precision/mixed_precision.s)
- [distributed/zero_gradient_reduce.s](/Users/shuwen/shuwen/train/neurx/distributed/zero_gradient_reduce.s)

要补的内容:
- 完整 AdamW
- BF16 / FP16 主路径
- dynamic loss scaling
- overflow detection
- grad norm clipping

### 6. 模型核心

优先文件:
- [model/llm/gpt_moe_1t_loss.s](/Users/shuwen/shuwen/train/neurx/model/llm/gpt_moe_1t_loss.s)
- [model/llm/long_context_32k.s](/Users/shuwen/shuwen/train/neurx/model/llm/long_context_32k.s)
- [distributed/moe_all_to_all.s](/Users/shuwen/shuwen/train/neurx/distributed/moe_all_to_all.s)
- [distributed/tensor_parallel.s](/Users/shuwen/shuwen/train/neurx/distributed/tensor_parallel.s)

要补的内容:
- 更稳定的 attention / FFN / norm 路径
- MoE 路由负载均衡
- 长上下文训练策略
- backward 路径完整性

### 7. 评测与门禁

优先文件:
- [tests/system_verification.s](/Users/shuwen/shuwen/train/neurx/tests/system_verification.s)
- [tests/test_suite_complete.s](/Users/shuwen/shuwen/train/neurx/tests/test_suite_complete.s)
- [test/test_training_pipeline.s](/Users/shuwen/shuwen/train/neurx/test/test_training_pipeline.s)
- [test/test_training_integration.s](/Users/shuwen/shuwen/train/neurx/test/test_training_integration.s)

要补的内容:
- perplexity
- throughput
- memory footprint
- checkpoint restore test
- regression benchmark

## P2 - 生产上线前补齐

### 8. 后训练

优先文件:
- [distillation/knowledge_distillation.s](/Users/shuwen/shuwen/train/neurx/distillation/knowledge_distillation.s)
- [quantization/quantizer.s](/Users/shuwen/shuwen/train/neurx/quantization/quantizer.s)
- [export/model_export.s](/Users/shuwen/shuwen/train/neurx/export/model_export.s)
- [deployment/model_deployment_chain.s](/Users/shuwen/shuwen/train/neurx/deployment/model_deployment_chain.s)

### 9. 推理服务

优先文件:
- [serving/serve/serve.s](/Users/shuwen/shuwen/train/neurx/serving/serve/serve.s)
- [serving/serve/continuous_batch.s](/Users/shuwen/shuwen/train/neurx/serving/serve/continuous_batch.s)
- [serving/serve/admission_control.s](/Users/shuwen/shuwen/train/neurx/serving/serve/admission_control.s)
- [serving/speculative_decoding.s](/Users/shuwen/shuwen/train/neurx/serving/speculative_decoding.s)

### 10. 监控与运维

优先文件:
- [logging/logger_core.s](/Users/shuwen/shuwen/train/neurx/logging/logger_core.s)
- [logging/wandb_integration.s](/Users/shuwen/shuwen/train/neurx/logging/wandb_integration.s)
- [logging/tensorboard_writer.s](/Users/shuwen/shuwen/train/neurx/logging/tensorboard_writer.s)
- [distributed/performance_monitor.s](/Users/shuwen/shuwen/train/neurx/distributed/performance_monitor.s)

## 推荐执行顺序

1. 训练主循环
2. 数据管道
3. Checkpoint 恢复
4. 分布式执行
5. 优化器和混精
6. 评测门禁
7. 后训练和部署

## 直接判断

如果目标是“工业级 1T GPT 训练”，现在最需要补的是：

- 能不能真正喂数据
- 能不能真正反向更新
- 能不能跨节点跑起来
- 能不能中断后恢复
- 能不能用指标证明训练没坏
