# 实现计划：从 train 框架移植功能到 NeurX
## Phase-by-Phase Implementation Roadmap

---

## 📋 总览

基于 `/home/shuwen/shuwen/train` 框架分析，我们识别出 **21 个高价值功能**可以移植到 NeurX 中。

**优先级分级**:
- 🔴 P0: 关键功能，立即实施 (1-2周)
- 🟡 P1: 重要功能，短期实施 (3-4周)
- 🟢 P2: 增强功能，中期实施 (1-2月)
- ⚪ P3: 可选功能，长期考虑 (3月+)

---

## 🎯 Phase 1: 推理优化 (2 weeks)

### 1.1 Continuous Batching v2 🔴 P0
**来源**: vLLM `v1/engine/core_client.py`
**文件**: `neurx/inference/continuous_batching_v2.s` (已创建 ✅)

**功能点**:
- ✅ FCFS/SJF/Priority 调度算法
- ✅ Request preemption (抢占调度)
- ✅ Dynamic batch resizing
- ❌ Request migration (待实现)

**工作量**: 5天
**性能提升**: 吞吐量 +2-3x

**验证方法**:
```bash
cd /home/shuwen/shuwen/neurx
s/bin/s_seed inference/continuous_batching_v2.s output/cb_v2.ir
# 测试: 模拟1000并发请求，测量吞吐量
```

---

### 1.2 PagedAttention Copy-on-Write 🔴 P0
**来源**: vLLM `model_executor/layers/attention.py`
**文件**: `neurx/attention/paged_attention_cow.s` (待创建)

**功能点**:
- Block-level reference counting
- Lazy copy on write
- Prefix sharing (多轮对话优化)
- LRU eviction

**实现骨架**:
```s
// neurx/attention/paged_attention_cow.s
struct cow_block {
    int block_id
    int ref_count
    []int owner_sequences
    bool is_copy_on_write
    []float data
}

func cow_allocate(parent_block: cow_block) cow_block {
    parent_block.ref_count += 1
    return cow_block {
        block_id: parent_block.block_id,
        ref_count: 1,
        is_copy_on_write: true,
        data: parent_block.data,  // Shared reference
    }
}

func cow_write(block: cow_block, data: []float) cow_block {
    if block.ref_count > 1 {
        // Trigger copy
        block.data = copy_array(block.data)
        block.ref_count = 1
        block.is_copy_on_write = false
    }
    block.data = data
    return block
}
```

**工作量**: 3天
**性能提升**: 内存节省 40% (多轮对话)

---

### 1.3 Speculative Decoding 🟡 P1
**来源**: vLLM `model_executor/layers/speculative.py`
**文件**: `neurx/inference/speculative_v2.s` (已创建 ✅)

**功能点**:
- ✅ Draft model forward pass
- ✅ Target model verification
- ✅ Token acceptance/rejection
- ❌ Tree-based speculation (待实现)

**工作量**: 4天
**性能提升**: Latency -2-3x

---

## 🎯 Phase 2: 训练优化 (3 weeks)

### 2.1 ZeRO-Infinity (CPU/NVMe Offload) 🔴 P0
**来源**: DeepSpeed `runtime/zero/parameter_offload.py`
**文件**: `neurx/optimizer/zero_infinity.s` (已创建 ✅)

**功能点**:
- ✅ CPU buffer management
- ✅ NVMe async I/O
- ✅ LRU eviction policy
- ❌ Prefetch pipeline (待实现)

**关键优化**:
```s
// neurx/optimizer/zero_infinity_prefetch.s
struct prefetch_pipeline {
    []int pending_params
    []int in_flight_params
    int pipeline_depth
}

func async_prefetch(
    zero_infinity_state state,
    []int next_layer_params) zero_infinity_state {
    // 1. 预测下一层需要的参数
    // 2. 启动 NVMe → CPU → GPU 异步传输
    // 3. 与计算重叠
}
```

**工作量**: 7天
**性能提升**: 
- 模型规模: +10-100x (单卡训练175B)
- 训练速度: -20% (I/O开销)

**硬件要求**:
- NVMe SSD (推荐 PCIe 4.0, 7GB/s)
- 64GB+ RAM

---

### 2.2 Pipeline Parallelism 1F1B 🟡 P1
**来源**: DeepSpeed `runtime/pipe/schedule.py`
**文件**: `neurx/distributed/pipeline_1f1b.s` (待创建)

**功能点**:
- 1F1B scheduling (one-forward-one-backward)
- Interleaved scheduling
- Bubble optimization

**实现**:
```s
// neurx/distributed/pipeline_1f1b.s
struct pipeline_schedule {
    string strategy  // "gpipe", "1f1b", "interleaved"
    int num_stages
    int num_microbatches
    int num_chunks  // For interleaved
}

func generate_1f1b_schedule(
    int stage_id,
    int num_stages,
    int num_microbatches) []string {
    
    []string schedule = []string{cap: num_microbatches * 2}
    
    // Warmup phase: Fill pipeline
    int warmup_steps = stage_id
    int i = 0
    while i < warmup_steps {
        schedule.push("forward")
        i += 1
    }
    
    // Steady state: 1F1B
    int steady_steps = num_microbatches - num_stages
    i = 0
    while i < steady_steps {
        schedule.push("forward")
        schedule.push("backward")
        i += 1
    }
    
    // Cooldown phase: Drain pipeline
    int cooldown_steps = num_stages - stage_id - 1
    i = 0
    while i < cooldown_steps {
        schedule.push("backward")
        i += 1
    }
    
    return schedule
}
```

**工作量**: 5天
**性能提升**: GPU 利用率 +30% (Bubble从50%降至10%)

---

### 2.3 Smart Activation Checkpointing 🟡 P1
**来源**: Megatron-LM `core/transformer/custom_layers/`
**文件**: `neurx/checkpoint/smart_checkpoint.s` (待创建)

**功能点**:
- 自动分析层的 memory/compute trade-off
- 选择最优 checkpoint 层
- 细粒度 checkpoint (部分算子)

**实现**:
```s
// neurx/checkpoint/smart_checkpoint.s
struct layer_profile {
    int layer_id
    int activation_memory_mb
    int recompute_time_ms
    float benefit_score  // memory_saved / compute_cost
}

func select_checkpoint_layers(
    []layer_profile profiles,
    float memory_budget_gb) []int {
    
    // 按 benefit_score 排序
    profiles = sort_by_benefit(profiles)
    
    []int selected_layers = []int{}
    float memory_saved = 0.0
    
    for layer in profiles {
        if memory_saved >= memory_budget_gb {
            break
        }
        selected_layers.push(layer.layer_id)
        memory_saved += layer.activation_memory_mb / 1024.0
    }
    
    return selected_layers
}
```

**工作量**: 3天
**性能提升**: 内存 -20%, 计算开销 +5%

---

## 🎯 Phase 3: 互操作性 (2 weeks)

### 3.1 ONNX Export/Import 🟡 P1
**来源**: ONNXRuntime `core/session/`
**文件**: `neurx/export/onnx_bridge.s` (待创建)

**功能点**:
- NeurX → ONNX 导出
- ONNX → NeurX 导入
- 算子映射表

**实现骨架**:
```s
// neurx/export/onnx_bridge.s
struct onnx_node {
    string op_type
    []string inputs
    []string outputs
    map[string]float attributes
}

struct onnx_graph {
    []onnx_node nodes
    []onnx_tensor initializers
}

func export_neurx_to_onnx(
    model neurx_model,
    string output_path) {
    
    onnx_graph graph
    
    // 1. 遍历 NeurX 模型图
    for layer in model.layers {
        onnx_node node = convert_layer_to_onnx(layer)
        graph.nodes.push(node)
    }
    
    // 2. 保存权重
    for param in model.parameters {
        onnx_tensor tensor = convert_param_to_tensor(param)
        graph.initializers.push(tensor)
    }
    
    // 3. 序列化为 .onnx 文件
    save_onnx_graph(graph, output_path)
}

func convert_layer_to_onnx(layer: Layer) onnx_node {
    if layer.type == "Linear" {
        return onnx_node {
            op_type: "Gemm",
            inputs: ["input", "weight", "bias"],
            outputs: ["output"],
            attributes: {"alpha": 1.0, "beta": 1.0},
        }
    } else if layer.type == "LayerNorm" {
        return onnx_node {
            op_type: "LayerNormalization",
            // ...
        }
    }
    // More mappings...
}
```

**工作量**: 6天
**价值**: 与 PyTorch/TensorFlow 互操作

---

### 3.2 XLA Backend (Optional) 🟢 P2
**来源**: JAX `_src/interpreters/xla.py`
**文件**: `neurx/compile/xla_backend.s` (待创建)

**功能点**:
- MLIR → XLA 转换
- XLA 自动融合
- TPU 支持

**工作量**: 10天 (高难度)
**价值**: Google TPU 支持，算子自动优化

---

## 📊 实现总览

| Phase | 功能 | 优先级 | 工作量 | 累计工作量 | 性能提升 |
|-------|------|--------|--------|-----------|---------|
| **Phase 1** | Continuous Batching v2 | 🔴 P0 | 5天 | 5天 | 吞吐 +2-3x |
| | PagedAttention CoW | 🔴 P0 | 3天 | 8天 | 内存 -40% |
| | Speculative Decoding | 🟡 P1 | 4天 | 12天 | 延迟 -2-3x |
| **Phase 2** | ZeRO-Infinity | 🔴 P0 | 7天 | 19天 | 模型 +10-100x |
| | Pipeline 1F1B | 🟡 P1 | 5天 | 24天 | GPU利用率 +30% |
| | Smart Checkpoint | 🟡 P1 | 3天 | 27天 | 内存 -20% |
| **Phase 3** | ONNX Export/Import | 🟡 P1 | 6天 | 33天 | 互操作性 |
| | XLA Backend | 🟢 P2 | 10天 | 43天 | TPU支持 |
| **总计** | **8 个功能** | - | **43天** | - | **综合提升 3-5x** |

---

## 🔬 技术依赖与风险

### S 语言限制
1. **异步 I/O**: ZeRO-Infinity 需要 NVMe 异步读写
   - **解决方案**: 通过 C 扩展实现 `libaio` binding
   
2. **CUDA Kernel**: PagedAttention CoW 需要自定义 kernel
   - **解决方案**: 使用 CUDA C++ + FFI

3. **ONNX Protobuf**: ONNX 导出需要序列化
   - **解决方案**: 使用 `protobuf-c` library

### 硬件依赖
| 功能 | 硬件要求 | 可选? |
|------|---------|------|
| ZeRO-Infinity | NVMe SSD (PCIe 4.0) | 否 |
| Speculative Decoding | 2x GPU (draft + target) | 是 |
| XLA Backend | Google TPU | 是 |

---

## 🧪 测试策略

### 单元测试
```bash
# neurx/tests/test_zero_infinity.s
func test_zero_infinity_offload() {
    state = new_zero_infinity_state(config, 1000, 100)
    gpu_param = random_array(256)
    
    state = zero_infinity_offload_param_to_cpu(state, gpu_param, 0)
    assert(state.param_metadata[0].on_cpu == true)
    
    state, prefetched = zero_infinity_prefetch_param(state, 0)
    assert(arrays_equal(gpu_param, prefetched))
}
```

### 集成测试
```bash
# neurx/tests/integration/test_inference_pipeline.s
func test_continuous_batching_with_paged_attention() {
    scheduler = new_scheduler_state(policy, 1024)
    
    # 模拟 100 并发请求
    for i in range(100) {
        req = create_request(id=i, tokens=random_length())
        scheduler = scheduler_enqueue_request(scheduler, req)
    }
    
    # 调度 10 轮
    for step in range(10) {
        scheduler = scheduler_schedule_batch(scheduler)
        scheduler = scheduler_step(scheduler)
    }
    
    stats = scheduler_get_stats(scheduler)
    assert(stats.kv_cache_utilization > 0.8)
}
```

### 性能基准
```bash
# neurx/benchmarks/bench_continuous_batching.s
func benchmark_throughput() {
    # 对比: 静态批处理 vs Continuous Batching v2
    static_tps = run_static_batching(1000_requests)
    cb_v2_tps = run_continuous_batching_v2(1000_requests)
    
    speedup = cb_v2_tps / static_tps
    assert(speedup >= 2.0)  # 至少 2x 提升
}
```

---

## 📚 参考资料

### 推荐阅读顺序
1. **vLLM Paper**: "Efficient Memory Management for Large Language Model Serving with PagedAttention"
2. **DeepSpeed ZeRO**: "ZeRO: Memory Optimizations Toward Training Trillion Parameter Models"
3. **Megatron-LM**: "Megatron-LM: Training Multi-Billion Parameter Language Models Using Model Parallelism"
4. **Speculative Decoding**: "Fast Inference from Transformers via Speculative Decoding"

### 代码参考
```bash
# vLLM 源码
/home/shuwen/shuwen/train/vllm/vllm/v1/engine/

# DeepSpeed 源码
/home/shuwen/shuwen/train/DeepSpeed/deepspeed/runtime/zero/

# Megatron-LM 源码
/home/shuwen/shuwen/train/Megatron-LM/megatron/core/
```

---

## ✅ 里程碑检查点

### Week 2: Phase 1 完成
- ✅ Continuous Batching v2 集成测试通过
- ✅ PagedAttention CoW 内存节省 >35%
- ✅ Speculative Decoding 延迟降低 >2x

### Week 5: Phase 2 完成
- ✅ ZeRO-Infinity 单卡训练 175B 模型
- ✅ Pipeline 1F1B GPU 利用率 >85%
- ✅ Smart Checkpoint 内存节省 >18%

### Week 7: Phase 3 完成
- ✅ ONNX 导出/导入验证通过
- ✅ 与 PyTorch 模型互操作成功

---

## 🎯 成功标准

### 推理性能
- 吞吐量: ≥ 2000 tokens/sec (vs 基线 800 tokens/sec)
- P99 延迟: ≤ 50ms (vs 基线 150ms)
- 内存利用率: ≥ 85%

### 训练性能
- 模型规模: 支持 175B+ 参数 (单卡)
- GPU 利用率: ≥ 85% (vs 基线 60%)
- 内存开销: ≤ 基线的 60%

### 代码质量
- 测试覆盖率: ≥ 80%
- 纯 S 语言实现: ≥ 95%
- 文档完整度: 100%

---

生成于 NeurX Phase 2A
文档版本: 1.0
下一步: 开始 Phase 1 实施
