#!/bin/bash
# NeurX 训练Claude级大模型 - 快速开始指南

## 📋 新增模块概览

### 编译优化层 (6个新文件)
- compile/passes/fusion.s - kernel融合
- compile/passes/elimination.s - 死代码消除
- compile/passes/memory.s - 内存优化
- compile/executor/execution_engine.s - 执行调度
- compile/cache/cache_manager.s - 编译缓存
- compile/optimization_pipeline.s - 完整管道

### 分布式训练层 (4个新文件)
- distributed/synchronization.s - 同步和死锁检测
- distributed/fault_tolerance.s - 故障恢复
- distributed/performance_monitor.s - 性能监控
- distributed/training_coordinator.s - 训练协调

### 数据管道层 (4个新文件)
- data/distributed_dataloader.s - 分布式加载
- data/preprocessing.s - 数据预处理
- data/batch_optimization.s - 批处理优化
- data/data_pipeline.s - 完整管道

### 生产推理层 (3个新文件)
- infer/kv_cache_manager.s - KV缓存管理
- infer/sampling_strategies.s - 采样策略
- infer/inference_server.s - 服务器
- infer/production_inference.s - 生产推理

### 对齐训练层 (3个新文件)
- alignment/supervised_finetuning.s - SFT训练
- alignment/rlhf_training.s - RLHF/DPO/PPO
- alignment/alignment_coordinator.s - 多阶段协调

---

## 🚀 使用示例

### 1. 预训练一个3B参数模型
```
预训练配置
├─ 模型: GPT-3B
├─ 数据: 3T tokens
├─ 批大小: 1024 * 4 (4机)
└─ 学习率: 2e-4

使用组件:
├─ data/data_pipeline → 分布式数据加载
├─ distributed/training_coordinator → 多卡同步
├─ compile/optimization_pipeline → 图优化
└─ distributed/fault_tolerance → 自动恢复
```

### 2. SFT对齐
```
SFT阶段
├─ 指令数据集: 100K条
├─ 训练轮数: 3
├─ 学习率: 2e-4 (预热10%)
└─ 评估指标: 指令跟随准确率

使用组件:
└─ alignment/supervised_finetuning
```

### 3. RLHF对齐
```
RLHF训练
├─ 偏好数据: 50K条
├─ 使用方法: PPO / DPO
├─ Reward模型: 训练或固定
└─ KL约束: beta=0.01

使用组件:
├─ alignment/rlhf_training
└─ alignment/alignment_coordinator
```

### 4. 部署推理服务
```
推理配置
├─ 模型量化: FP8
├─ 最大并发: 100
├─ 批大小: 自适应
├─ KV缓存大小: 100K tokens
└─ 采样策略: top-k=40, top-p=0.9

使用组件:
├─ infer/kv_cache_manager → 高效缓存
├─ infer/inference_server → Continuous batching
├─ infer/sampling_strategies → 多种采样
└─ infer/production_inference → 优化推理
```

---

## 📊 性能指标预期

### 训练阶段
| 指标 | 预期值 | 改进 |
|------|-------|------|
| 编译优化 | +15-20% 吞吐 | 图融合+内存优化 |
| 分布式同步 | <1% 通信开销 | 重叠计算通信 |
| 数据加载 | 零阻塞 | prefetch+去重 |
| **总体** | **20-30%** | **多项优化叠加** |

### 推理阶段
| 指标 | 预期值 | 改进 |
|------|-------|------|
| TTFT | <100ms | KV缓存+packing |
| 吞吐 | +40-50% | continuous batching |
| 内存 | -60% | KV缓存分页 |
| **总体** | **3-5x** | **综合优化** |

---

## 🔧 关键功能速查

### 图优化
```python
# 使用compile/optimization_pipeline
pipeline = new_optimization_pipeline()
optimized_graph = optimize_graph(pipeline, input_graph)
stats = get_optimization_stats(input_graph, optimized_graph)
```

### 分布式训练
```python
# 使用distributed/training_coordinator
state = new_distributed_training_state(rank_id, world_size, strategy)
state = execute_distributed_step(state, compute_t, comm_t, gpu_util, mem)
state = handle_checkpoint_step(state)
```

### 数据加载
```python
# 使用data/data_pipeline
pipeline = new_data_pipeline(config)
batch = get_next_batch(pipeline)
stats = get_pipeline_stats(pipeline)
```

### 推理服务
```python
# 使用infer/inference_server
server = new_inference_server(num_workers)
request = inference_request{request_id, prompt, max_tokens, sampling}
response = submit_request(server, request)
```

### 对齐训练
```python
# 使用alignment/alignment_coordinator
trainer = new_alignment_trainer(config)
trainer = run_full_alignment_pipeline(trainer)
report = generate_alignment_report(trainer)
```

---

## 📈 集成检查清单

- [ ] 编译优化通过单元测试
- [ ] 分布式同步在多GPU验证
- [ ] 数据管道预取性能达标
- [ ] 推理服务端到端测试
- [ ] 对齐训练评估完成

---

## 🎓 相关文档

- [IMPLEMENTATION_SUMMARY.md](./IMPLEMENTATION_SUMMARY.md) - 详细实现说明
- [README.md](./README.md) - 项目总体介绍
- [compile/README.md](./compile/README.md) - 编译层设计
- [distributed/README.md](./distributed/README.md) - 分布式层设计
- [pretrain/README.md](./pretrain/README.md) - 预训练流程

---

## 💡 工程建议

1. **分阶段集成**: 先integrate编译+数据，再加分布式，最后推理
2. **性能基准**: 每个模块部署前做性能测试
3. **压力测试**: 用极限配置（超大模型）测试稳定性
4. **可观测性**: 完整的监控和日志记录
5. **文档**: 为生产部署编写详细操作指南

---

## ❓ 常见问题

**Q: 如何启用KV缓存量化?**  
A: 在kv_cache_manager中调用compress_kv_cache()

**Q: 如何处理训练中的rank失败?**  
A: distributed/fault_tolerance自动处理，启用异步checkpoint

**Q: 如何优化推理延迟?**  
A: 使用sampling_strategies的贪心采样，启用CUDA图捕获

**Q: 如何检测通信瓶颈?**  
A: 使用performance_monitor分析communicate_bottleneck

---

## 🆘 快速诊断

```bash
# 检查编译优化是否生效
neurx_check_graph_optimization

# 验证分布式同步
neurx_test_ddp_sync

# 性能基准测试
neurx_benchmark_data_pipeline
neurx_benchmark_inference

# 对齐训练验证
neurx_test_sft_pipeline
neurx_test_rlhf_convergence
```

---

构建完整的Claude级大模型训练、对齐、部署系统! 🚀
