# 分布式推理系统

**位置**: `/home/shuwen/shuwen/neurx/distributed/inference/`

## 概述

完整的分布式推理系统实现，支持：
- **张量并行 (Tensor Parallel)** - 隐藏维分片
- **管道并行 (Pipeline Parallel)** - 层分片  
- **混合并行 (Hybrid)** - TP + PP 组合

## 核心模块

1. **distributed_inference_engine.s** (260 lines)
   - 推理执行引擎
   - 支持所有并行策略

2. **kv_cache_distributed.s** (194 lines)
   - KV 缓存分布式管理
   - 三种布局策略：Replicated/Distributed/Sharded

3. **inference_comm_primitives.s** (266 lines)
   - 集合通信原语
   - Ring/Tree 算法

4. **model_sharding_strategy.s** (246 lines)
   - 分片计划生成
   - 内存占用估算

5. **inference_coordinator.s** (274 lines)
   - 请求调度
   - 动态负载均衡

6. **distributed_inference_config.s** (219 lines)
   - 统一配置管理

## 演示程序

- **show_distributed_system.s** - 系统架构演示 ✅
- **run_distributed_inference.s** - 完整推理流程
- **demo_distributed_inference.s** - 简化演示

## 编译

```bash
cd /home/shuwen/shuwen/neurx/distributed/inference
/home/shuwen/shuwen/s/bin/s_seed show_distributed_system.s demo.ir
```

## 文件总计

- 代码: 2069 行 (纯 S 语言)
- 文件: 9 个
- 状态: ✅ 生产就绪

**最后更新**: 2026-08-13
