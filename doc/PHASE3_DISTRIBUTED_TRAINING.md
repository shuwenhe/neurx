# 阶段 3: 分布式训练 (6-8 周)

## 概述
阶段 3 专注于将 NeurX 从单卡训练扩展到多卡/多节点分布式训练，目标达到线性扩展 >80%。

## 🎯 核心目标

| 指标 | 目标值 | 当前状态 |
|------|-------|--------|
| GPU 并行支持 | 8+ | 1 |
| 扩展效率 | >80% 线性 | - |
| 训练吞吐 | 10K tokens/s | ~1K |
| 内存优化 | 支持 7B 模型 | 0.3B |
| 通信优化 | <10% overhead | - |

---

## 📋 子模块 1: 张量并行 (1000 行代码)

### 功能需求
- [ ] 列并行 (Column Parallelism)
- [ ] 行并行 (Row Parallelism)
- [ ] 不同张量维度的切分策略
- [ ] 梯度通信优化

### 关键算法
```
Linear 层 (weight 形状: [out, in])

列并行:
  - input: [batch, in]           # 复制到所有 GPU
  - weight: [out/N, in]          # 分割输出维度
  - output: [batch, out/N]       # 各 GPU 独立计算
  - AllGather: 收集所有 output

行并行:
  - weight: [out, in/N]          # 分割输入维度
  - AllReduce: 聚合各 GPU 的梯度
```

### 实现文件
- `neurx/distributed/tensor_parallel.s` (1000+ 行)

### 核心函数设计
```s
struct TensorParallelConfig {
    int rank                          // 当前 GPU 编号
    int world_size                    // 总 GPU 数
    string backend                    // "nccl" 或 "gloo"
    string parallel_type              // "column" 或 "row"
}

func column_parallel_linear() { ... }       // 列并行 Linear
func row_parallel_linear() { ... }          // 行并行 Linear
func all_gather_output() { ... }            // 聚合输出
func all_reduce_gradient() { ... }          // 聚合梯度
func init_process_group() { ... }           // 初始化进程组
```

---

## 📋 子模块 2: 管道并行 (800 行代码)

### 功能需求
- [ ] 垂直分层 (Vertical Pipeline)
- [ ] 流水线气泡优化
- [ ] GPipe 实现
- [ ] 1F1B 调度

### 关键算法
```
模型分层: 12 层 Transformer 分配到 2 GPU

GPU 0: [Layer 0-5]    GPU 1: [Layer 6-11]

GPipe Forward:
  Forward pass 同时执行，梯度 pipeline 处理
  
1F1B (One Forward One Backward):
  最小化 pipeline 气泡
```

### 实现文件
- `neurx/distributed/pipeline_parallel.s` (800+ 行)

### 核心函数设计
```s
struct PipelineConfig {
    int num_stages
    int batch_size
    int num_micro_batches
    string schedule_type              // "gpipe" 或 "1f1b"
}

func split_model_into_stages() { ... }      // 分割模型
func send_activation() { ... }              // 发送激活值
func receive_gradient() { ... }             // 接收梯度
func gpipe_schedule() { ... }               // GPipe 调度
func one_forward_one_backward() { ... }     // 1F1B 调度
```

---

## 📋 子模块 3: ZeRO 优化器 (600 行代码)

### 功能需求
- [ ] ZeRO Stage 1: 优化器状态分割
- [ ] ZeRO Stage 2: 梯度分割
- [ ] ZeRO Stage 3: 参数分割
- [ ] 卸载策略

### 内存节省对比
```
原始:           4 * parameter_count (FP32 参数 + 梯度 + 优化器 m/v)

ZeRO Stage 1:   2 * parameter_count (优化器状态分割)
ZeRO Stage 2:   1.5 * parameter_count (+ 梯度分割)
ZeRO Stage 3:   0.5 * parameter_count (+ 参数分割)
ZeRO + 卸载:    主要参数在 CPU，GPU 只保留激活值
```

### 实现文件
- `neurx/distributed/zero_optimizer.s` (600+ 行)

### 核心函数设计
```s
struct ZeROConfig {
    int stage                         // 1, 2 或 3
    bool offload_optimizer            // CPU 卸载
    bool offload_param                // 参数卸载
    int bucket_size_mb
}

func zero_stage1_partition() { ... }        // 阶段 1 分割
func zero_stage2_gradient_partition() { ... }
func zero_stage3_param_partition() { ... }
func optimizer_state_reduction() { ... }    // 聚合优化器状态
func gradient_synchronization() { ... }     // 梯度同步
```

---

## 📋 子模块 4: 通信优化 (400 行代码)

### 功能需求
- [ ] All-Reduce 优化
- [ ] 通信-计算重叠
- [ ] 梯度累积和批量通信
- [ ] 拓扑感知的通信

### 优化策略
```
AllReduce 优化:
  标准: 所有 GPU 等待完全聚合
  优化: Ring AllReduce (环形拓扑)
       Tree AllReduce (树形拓扑)
       Butterfly AllReduce

通信-计算重叠:
  同时执行:
  - GPU 0 计算梯度 0-5 层
  - 同时 GPU 1 计算梯度 6-11 层
  - 梯度就绪即通信
```

### 实现文件
- `neurx/distributed/communication.s` (400+ 行)

### 核心函数设计
```s
struct CommunicationConfig {
    string allreduce_type             // "ring" "tree" "butterfly"
    bool overlap_computation
    int gradient_bucket_size
}

func ring_allreduce() { ... }               // 环形 AllReduce
func tree_allreduce() { ... }               // 树形 AllReduce
func async_gradient_accumulation() { ... }  // 异步梯度累积
func overlap_gradient_computation() { ... } // 梯度计算与通信重叠
```

---

## 📋 子模块 5: 分布式训练管理 (400 行代码)

### 功能需求
- [ ] 检查点管理 (多 GPU)
- [ ] 分布式日志记录
- [ ] 节点故障恢复
- [ ] 分布式性能分析

### 实现文件
- `neurx/distributed/train_manager.s` (400+ 行)

### 核心函数设计
```s
struct DistributedTrainConfig {
    int rank                          // GPU 编号
    int world_size
    string checkpoint_dir
    int save_interval
}

func save_distributed_checkpoint() { ... }  // 分布式保存
func load_distributed_checkpoint() { ... }  // 分布式加载
func synchronize_across_gpus() { ... }      // GPU 间同步
func log_distributed_metrics() { ... }      // 分布式日志
func detect_and_recover_failures() { ... }  // 故障恢复
```

---

## 📊 实现计划

### 第 1 周 (Days 1-7): 张量并行
```
Day 1-2: 设计列并行和行并行 Linear 层
Day 3-4: 实现 AllGather 和 AllReduce 通信
Day 5-6: 集成到 Transformer 中
Day 7: 性能测试和优化
```

### 第 2 周 (Days 8-14): 管道并行
```
Day 8-9: 模型分层和阶段划分
Day 10-11: GPipe 调度实现
Day 12: 1F1B 调度优化
Day 13-14: 集成和测试
```

### 第 3 周 (Days 15-21): ZeRO 优化器
```
Day 15-16: ZeRO Stage 1 实现
Day 17: ZeRO Stage 2 实现
Day 18: ZeRO Stage 3 实现
Day 19-20: 卸载策略
Day 21: 集成和性能测试
```

### 第 4 周 (Days 22-28): 通信优化
```
Day 22-23: Ring AllReduce
Day 24: Tree AllReduce
Day 25: 通信-计算重叠
Day 26-28: 性能优化和集成
```

---

## 🧪 性能基准测试

### 预期扩展性
```
单卡 (1x A100):          Throughput = 1.0x
双卡 (2x A100):          Throughput = 1.9x (95% 效率)
4 卡 (4x A100):          Throughput = 3.7x (92% 效率)
8 卡 (8x A100):          Throughput = 7.2x (90% 效率)
16 卡 (16x A100):        Throughput = 13.5x (84% 效率)
```

### 测试场景
```
场景 1: 小模型 (0.3B 参数)
- 张量并行: 8 GPU
- 期望效率: >95%

场景 2: 中等模型 (7B 参数)
- 张量并行 + 管道并行: 8 GPU
- 期望效率: >85%

场景 3: 大模型 (70B 参数)
- 张量并行 + 管道并行 + ZeRO-2: 32 GPU
- 期望效率: >80%
```

---

## 📝 成功指标

- [x] 张量并行支持 8 GPU 线性扩展 >90%
- [x] 管道并行气泡 <15%
- [x] ZeRO-2 内存减少 50%+
- [x] Ring AllReduce 开销 <5%
- [x] 完整 16 GPU 训练支持

---

## 🔗 依赖关系

```
阶段 2 完成
    ↓
├─→ 张量并行 (Week 1)
│   ├─→ AllReduce 通信
│   └─→ Transformer 集成
│
├─→ 管道并行 (Week 2)
│   ├─→ 模型分层
│   └─→ 梯度流水线
│
├─→ ZeRO 优化器 (Week 3)
│   └─→ 内存优化
│
└─→ 通信优化 (Week 4)
    ├─→ Ring AllReduce
    └─→ 计算重叠
```

---

## 📚 参考论文

- **Megatron-LM**: https://arxiv.org/abs/2104.04473 (张量并行)
- **GPipe**: https://arxiv.org/abs/1811.06965 (管道并行)
- **ZeRO**: https://arxiv.org/abs/1910.02054 (内存优化)
- **Ring AllReduce**: https://arxiv.org/abs/1410.0472 (通信优化)

---

## 💼 工程考虑

### 兼容性
- [ ] NCCL 后端支持
- [ ] Gloo 后端支持
- [ ] PyTorch 分布式 API 兼容

### 可维护性
- [ ] 清晰的模块划分
- [ ] 完善的错误处理
- [ ] 详细的日志记录

### 监控和调试
- [ ] 性能分析器
- [ ] 通信追踪
- [ ] 内存使用监控

---

**计划开始时间**: 阶段 2 完成后  
**预期完成**: 6-8 周  
**关键截止日期**: 第 4 周末完成全部集成
