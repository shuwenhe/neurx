# neurx 1T MoE 模块快速参考

## 模块 1: MoE All-to-All 路由

**文件**: `distributed/moe_all_to_all.s`

**用途**: Token 到专家的路由和双向通信

**核心函数**:
```s
// 初始化
moe_routing_state state = moe_routing_state { ... }

// 前向传播 (包含完整管道)
(output, aux_loss) = moe_alltoall_forward(
    state, comm,
    hidden_states,        // [batch*seq, hidden_dim]
    router_weight,        // [hidden_dim, num_experts]
    expert_weights,       // 专家参数
    ep_rank, ep_size,
    batch_size, seq_len
)
// 返回: ([batch*seq, hidden_dim], float aux_loss)
```

**关键参数**:
- `num_experts: 256`
- `top_k: 2` (选择 top-2 专家)
- `aux_loss_weight: 0.01` (负载均衡权重)

**预期性能**:
- All-to-All 通信: 2× 模型参数大小
- 计算与通信重叠率: > 80%

---

## 模块 2: 张量并行 (TP)

**文件**: `distributed/tensor_parallel.s`

**用途**: 跨 8 个 GPU 的权重分片和并行计算

**关键函数**:
```s
// 初始化
tp_state = tensor_parallel_new(tp_rank, tp_size, hidden_dim)

// QKV 列并行前向
qkv_out = tp_qkv_forward(
    hidden_states,    // [batch*seq, hidden_dim]
    w_q, w_k, w_v     // [hidden_dim, hidden_dim/8] 每个
)
// 返回: [batch*seq, hidden_dim/8]

// 注意力计算 (需要 AllGather 获取完整 KV)
qkv_full = tp_allgather_async(qkv_out)

// FFN 混合并行
ffn_out = tp_ffn_column_parallel(hidden_states)   // W_up: [H, 4H/8]
ffn_gated = gelu(ffn_out)
ffn_reduced = tp_reduce_scatter_async(ffn_gated)  // AllReduce
ffn_final = tp_ffn_row_parallel(ffn_reduced)      // W_down: [4H/8, H]
```

**关键参数**:
- `tp_size: 8`
- `hidden_dim: 12288`
- `num_heads: 96`
- `head_dim: 128`

**内部通信**:
- AllGather: 获取完整 KV (backward 时)
- ReduceScatter: 收集 FFN 梯度 (backward 时)

---

## 模块 3: ZeRO Stage 3 梯度规约

**文件**: `distributed/zero_gradient_reduce.s`

**用途**: 参数分片与分布式梯度更新

**核心函数**:
```s
// 初始化 (1024 GPU 时，每个 GPU 有参数分片)
zero = zero_stage3_new(
    rank, world_size,
    total_params: 1000000000000,  // 1T
    comm
)

// 反向传播时累积梯度
zero_stage3_accumulate_gradients(
    zero,
    layer_gradients,
    param_start_idx,
    param_end_idx
)

// 异步启动 AllReduce + ReduceScatter
handle = zero_stage3_start_async_reduce(zero, comm)

// 其他计算中...

// 等待完成
zero_stage3_wait_async_reduce(zero)

// 梯度裁剪 (全局范数)
zero_stage3_clip_gradients(zero, comm, max_grad_norm: 1.0)

// 优化器步骤 (各 GPU 独立)
zero_stage3_optimizer_step(
    zero, parameters,
    learning_rate: 0.0002,
    beta1: 0.9, beta2: 0.999,
    epsilon: 1e-8, weight_decay: 0.01
)
```

**关键参数**:
- `world_size: 1024`
- `partition_size: total_params / world_size`
- `overlap_reduce_backward: 1` (与反向重叠)

**内存优势**:
- 单 GPU 参数占用: 1TB / 1024 ≈ 1GB (BF16)
- 加优化器状态: 3GB 总
- 能用 80GB GPU: 剩余 77GB 用于 batch/cache

---

## 模块 4: 损失计算与反向传播

**文件**: `model/llm/model_moe_1t_loss.s`

**用途**: Cross-entropy + MoE 辅助损失，反向传播

**核心函数**:
```s
// 初始化
loss_state = loss_state_new(
    vocab_size: 128000,
    aux_loss_weight: 0.01
)

// 计算完整损失
total_loss = compute_total_loss(
    loss_state,
    logits,              // [batch*seq, vocab_size]
    labels,              // [batch*seq]
    expert_indices,      // [batch*seq, top_k]
    expert_weights,      // [batch*seq, top_k]
    batch_size, seq_len, top_k
)
// 返回: float (标量损失)

// CE 梯度计算
grad_logits = compute_ce_gradient(
    logits, labels,
    batch_size, seq_len, vocab_size
)
// 返回: [batch*seq, vocab_size]

// 动态损失缩放 (FP16/BF16)
update_loss_scale(loss_state, overflow_detected: 0)
apply_loss_scale(gradients, loss_state.loss_scale)
```

**损失分解**:
```
L_total = L_ce + 0.01 * L_aux + 0.05 * L_kl

其中:
  L_ce = -log(softmax(logits[label]))
  L_aux = 负载均衡项 (防止专家过载)
  L_kl = KL(target_model || base_model) (可选)
```

**关键参数**:
- `vocab_size: 128000` (BPE 词汇)
- `aux_loss_weight: 0.01`
- `kl_loss_weight: 0.05` (对齐时)
- `label_smoothing: 0.0` (可选)

---

## 模块 5: 学习率调度器

**文件**: `training/lr_scheduler_moe_1t.s`

**用途**: 学习率调度 (Cosine annealing + warmup)

**核心函数**:
```s
// 初始化
scheduler = lr_scheduler_new(
    base_lr: 0.0002,
    warmup_steps: 10000,
    total_steps: 750000
)

// 前向传播前，获取当前 LR
current_lr = compute_lr(scheduler)

// 优化器步骤后，前进一步
step(scheduler)  // 或者 new_lr = step(scheduler)
```

**调度策略** (可选):
```s
// 方法 1: Cosine annealing (默认)
lr = compute_cosine_annealing_lr(scheduler)

// 方法 2: 线性衰减
lr = compute_linear_decay_lr(scheduler)

// 方法 3: 指数衰减
lr = compute_exponential_decay_lr(scheduler)

// 方法 4: 单周期
lr = compute_one_cycle_lr(scheduler)

// 方法 5: 分步衰减
lr = compute_step_decay_lr(scheduler, step_size: 100000, gamma: 0.1)
```

**LR 曲线** (Cosine annealing):
```
预热阶段: 0 → 0.0002 (10K steps)
衰减阶段: 0.0002 → 0.00002 (740K steps, 余弦)
    LR(t) = 0.00002 + 0.00018 * 0.5 * (1 + cos(π * progress))
```

---

## 模块 6: JSONL 数据加载

**文件**: `data/moe_1t_jsonl_loader.s`

**用途**: 分布式 JSONL 文件加载和 tokenization

**核心函数**:
```s
// 初始化
loader = jsonl_data_loader_new(
    data_dir: "/data/neurx/shards",
    batch_size: 16,
    seq_len: 4096,
    dp_rank: rank / (tp_size * pp_size),  // 数据并行 rank
    dp_size: 8
)

// 获取下一个 batch
batch = get_next_batch(loader)
// 返回 jsonl_batch:
//   - token_ids: [batch_size, seq_len]
//   - attention_mask: [batch_size, seq_len]
//   - document_ids: [batch_size]
//   - metadata: [batch_size, num_fields]

// 获取统计信息
stats = get_loader_stats(loader)
```

**数据分片策略**:
```
8192 个 JSONL 分片，每个 DP rank 读取 8192/8 = 1024 个分片

分配方式 (轮转):
  rank 0: shard 0, 8, 16, ...
  rank 1: shard 1, 9, 17, ...
  ...
  rank 7: shard 7, 15, 23, ...
```

**关键参数**:
- `num_shards: 8192`
- `vocab_size: 128000` (BPE)
- `batch_size: 16`
- `seq_len: 4096`

---

## 模块 7: 分布式监控系统

**文件**: `monitoring/moe_1t_metrics.s`

**用途**: 收集和聚合分布式训练指标

**核心函数**:
```s
// 初始化
collector = metrics_collector_new(
    global_rank: rank,
    world_size: 1024,
    local_rank: rank % 8,
    local_world_size: 8,
    output_dir: "/logs/neurx_1t"
)

// 在每个 step 更新指标
update_training_metrics(
    collector,
    loss: 3.24,
    loss_ce: 3.22,
    loss_aux: 0.02,
    learning_rate: 0.00015,
    gradient_norm: 1.23
)

update_moe_metrics(
    collector,
    expert_load: [...],
    expert_utilization: [...],
    expert_dropout_count: [...]
)

update_communication_metrics(
    collector,
    allgather_bytes: 1000000,
    allreduce_bytes: 2000000,
    reduce_scatter_bytes: 1500000,
    allgather_time_ms: 5.2,
    allreduce_time_ms: 10.3,
    reduce_scatter_time_ms: 7.1
)

update_system_metrics(
    collector,
    gpu_memory_used: 18000000000,     // 18GB
    gpu_power: 350.5,
    gpu_temp: 65.2,
    throughput: 3500.0,               // tokens/sec
    iteration_time: 250.0              // ms
)

// 记录当前 step (定期输出日志)
log_step(collector, step: 100)
// 输出示例:
// Step=100 Loss=3.2451 LR=0.000150 Perplexity=25.62
// MoE-Load=1.23 Throughput=3500 tokens/sec Memory=72.5%
```

**收集的指标**:

| 类别 | 具体指标 |
|------|---------|
| **训练** | loss, loss_ce, loss_aux, perplexity, LR, grad_norm |
| **MoE** | expert_load, utilization, dropout_count, load_balance_ratio |
| **通信** | AllGather/Reduce/ReduceScatter 时间和字节 |
| **系统** | GPU 内存%, 功耗, 温度, 吞吐量, 迭代时间 |

---

## 模块 8: 长上下文 32K 支持

**文件**: `model/llm/long_context_32k.s`

**用途**: RoPE 位置编码扩展，支持超长上下文

**核心函数**:
```s
// 配置
config = rope_config_new(
    dim: 12288 / 96,              // head_dim = 128
    max_seq_len: 32768
)
// 自动设置: base=500000, scaling="ntk"

// 初始化并预计算缓存
rope_state = rope_state_new(config)
// 内部预计算: cos_cache, sin_cache [max_seq_len, dim/2]

// 在注意力中应用 RoPE
(rotated_q, rotated_k) = apply_rope_to_qk(
    rope_state,
    query,                        // [batch*seq, num_heads, head_dim]
    key,
    batch_size, seq_len,
    num_heads: 96, head_dim: 128
)
// 返回: 旋转后的 Q 和 K

// 处理超过最大长度的序列
if seq_len > max_seq_len {
    handle_longer_context(rope_state, seq_len)
    // 自动应用外推缩放
}
```

**RoPE 扩展方法**:

| 方法 | 公式 | 效果 |
|------|------|------|
| **NTK** (推荐) | `α = (seq_len/max)^(d/(d-2))` | 平衡内插和外推 |
| **Linear Interp** | 低频不变，高频线性缩放 | 保留短距离依赖 |
| **YARN** | NTK + Linear 结合 | 最佳性能 |

**关键参数**:
- `base: 500000` (vs 标准 10000)
- `max_seq_len: 32768` (32K)
- `scaling_type: "ntk"` (推荐)
- 支持外推至 100K+

---

## 🔗 集成示例

### 完整训练步骤

```s
func train_one_step(
    moe_1t_orchestrator orch,
    jsonl_data_loader loader,
    loss_state loss,
    lr_scheduler_state scheduler,
    metrics_collector metrics,
    zero_stage3_state zero
) {
    // 1. 加载数据
    batch = get_next_batch(loader)
    
    // 2. 前向传播 (自动包含 MoE + TP)
    logits = moe_1t_forward_pass(orch, batch.token_ids)
    
    // 3. 计算损失
    loss_val = compute_total_loss(loss, logits, batch.labels, ...)
    
    // 4. 反向传播
    grad_logits = compute_ce_gradient(logits, batch.labels, ...)
    
    // 5. 梯度规约 (异步)
    zero_stage3_accumulate_gradients(zero, gradients, ...)
    zero_stage3_start_async_reduce(zero, comm)
    
    // 6. 梯度裁剪
    zero_stage3_wait_async_reduce(zero)
    zero_stage3_clip_gradients(zero, comm, max_grad_norm: 1.0)
    
    // 7. 优化器
    lr = compute_lr(scheduler)
    zero_stage3_optimizer_step(zero, params, lr, 0.9, 0.999, 1e-8, 0.01)
    
    // 8. LR 调度
    step(scheduler)
    
    // 9. 监控
    if step % 100 == 0 {
        update_training_metrics(metrics, loss_val, ...)
        log_step(metrics, step)
    }
}
```

---

## 📊 性能对标

| 配置 | 吞吐量 | 内存 | 时间 |
|------|--------|------|------|
| 单 GPU | 5K tokens/sec | 18-20GB | - |
| 8 GPU TP | 35K tokens/sec | 144GB | - |
| 64 GPU | 280K tokens/sec | - | - |
| **1024 GPU** | **3000+ tokens/sec** | **3TB 总** | **4-6 天 (3T)** |

---

## ⚠️ 常见陷阱

1. **忘记调用 step(scheduler)**
   → LR 不会更新，整个训练用同一个 LR

2. **不等待 AllReduce 完成**
   → 梯度不同步，模型发散

3. **梯度裁剪前没有同步**
   → 每个 GPU 看不到全局梯度范数

4. **TP 中没有 AllGather**
   → 注意力计算时缺少完整 KV，输出错误

5. **数据加载超出内存**
   → 检查 batch_size * seq_len * hidden_dim

---

## 🎯 下一步

1. 编译所有 8 个模块
2. 单 GPU 功能测试
3. 8 GPU TP 验证
4. 64+ GPU 集群测试
5. 1024 GPU 全规模训练

---

**快速参考版本**: 1.0
**更新时间**: 2024 年
**状态**: ✅ 可用
