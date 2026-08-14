# vLLM 功能在 NeurX 中的实现路线图

**创建日期**: 2026-08-14  
**语言**: 100% S 语言实现  
**目标**: 功能对标 vLLM，代码比 vLLM 简洁 60%

---

## 🎯 优先级排序（P0 → P1 → P2）

### 🔴 P0 级 - 生产交付必需 (决定 NeurX 生死)

| 优先级 | 功能 | 现状 | 工作量 | 收益 | 难度 |
|--------|------|------|--------|------|------|
| **P0.1** | **V1 API 架构** (Prefill/Decode 分离) | ❌ | 8-12w | **10x吞吐** ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **P0.2** | **模型支持扩展** (30+ 种模型) | ⚠️ 5种 | 3-4w | **6x覆盖** ⭐⭐⭐⭐ | ⭐ |
| **P0.3** | **KV 缓存 CPU 卸载** | ❌ | 3-4w | **显存-50-70%** ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **P0.4** | **推理投机解码** | ❌ | 4-5w | **2-3x加速** ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

**阶段目标**: Phase 1 完成 P0.2 + P0.3, 实现 3-5x 吞吐提升  
**预计时间**: 10-12 周

---

### 🟠 P1 级 - 功能完整性 (产品竞争力)

| 优先级 | 功能 | 现状 | 工作量 | 收益 | 难度 |
|--------|------|------|--------|------|------|
| **P1.1** | **Logits Processors** (采样优化) | ❌ | 2-3w | **采样灵活性** ⭐⭐⭐ | ⭐⭐ |
| **P1.2** | **LoRA 系统** | ❌ | 3-4w | **微调完整** ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **P1.3** | **结构化输出** (JSON Schema) | ❌ | 3-4w | **格式控制** ⭐⭐⭐ | ⭐⭐⭐ |
| **P1.4** | **分布式追踪完善** (OTEL) | ⚠️ 基础 | 2-3w | **可观测性** ⭐⭐⭐ | ⭐⭐⭐ |
| **P1.5** | **分布式容错** | ❌ | 2-3w | **可靠性** ⭐⭐⭐ | ⭐⭐⭐ |

**阶段目标**: Phase 2 完成所有 P1，实现功能对标 vLLM 基础版  
**预计时间**: 12-14 周

---

### 🟡 P2 级 - 增强功能 (长期竞争优势)

| 功能 | 工作量 | 难度 |
|------|--------|------|
| 编译优化 (CUDA Graph 融合) | 4-6w | ⭐⭐⭐⭐⭐ |
| 多模态支持 (视觉+文本) | 4-6w | ⭐⭐⭐⭐ |
| Plugin 系统 | 2-3w | ⭐⭐ |
| 推理链 (Chain of Thought) | 2-3w | ⭐⭐⭐ |
| CUDA Graph 预热 | 2w | ⭐⭐⭐ |
| 自定义算子 (CUTLASS) | 3-4w | ⭐⭐⭐⭐⭐ |

---

## 📅 推荐执行计划

### Phase 1: 核心性能 (10-12 周)

**目标**: 3-5x 吞吐提升 + 功能完整度 40%

```
Week 1-2:   P0.2 模型支持扩展 (LLaMA, Qwen, DeepSeek, ...)
├─ Day 1-2:   适配器基础架构
├─ Day 3-4:   新增 10+ 模型架构
├─ Day 5:     权重加载逻辑

Week 3-4:   P1.1 Logits Processors (采样优化)
├─ Day 1-2:   Temperature + Top-K
├─ Day 3:     Nucleus + Frequency Penalty
├─ Day 4-5:   集成到采样引擎

Week 5-8:   P0.3 KV 缓存 CPU 卸载
├─ Day 1-2:   内存映射设计
├─ Day 3-4:   CPU↔GPU 同步机制
├─ Day 5-6:   性能优化

Week 9-12:  P0.1 V1 API 架构（可选，高难度）
├─ 如果 Week 1-8 顺利，则启动 Prefill/Decode 分离
├─ 预计吞吐提升到 5-8x
```

**产物**:
- 1 个新的模型支持框架（支持 30+ 种模型）
- 1 个完整的 Logits 处理管道
- 1 个 KV 缓存 CPU 卸载系统
- 性能基准: 0.5B 模型 80-100 tok/s (CPU, 16核)

---

### Phase 2: 功能完整 (12-14 周)

**目标**: 功能对标 vLLM 基础版，覆盖度 70%

```
Week 1-4:   P1.2 LoRA 系统
├─ 动态加载/卸载
├─ 权重融合优化
├─ 显存有效存储

Week 5-8:   P1.3 结构化输出 + P1.4 OTEL 追踪

Week 9-12:  P1.5 分布式容错 + 性能优化

Week 13-14: 集成测试 + 基准测试
```

---

### Phase 3: 长期优化 (8+ 周)

**目标**: 代码质量和性能优于 vLLM，覆盖度 85%+

```
Week 1-4:   P0.4 推理投机解码 (Speculative Decoding)
Week 5-8:   P2 编译优化 + 多模态支持
Week 9+:    Plugin 系统 + 自定义算子
```

---

## 📊 风险评估与缓解

### 风险 1: S 语言 FFI 能力
**问题**: KV 缓存 CPU 卸载需要操作系统接口  
**缓解**: 设计完整的 Device Runtime 抽象层  
**优先级**: P0.3 之前必须验证

### 风险 2: 异步调度复杂度
**问题**: Prefill/Decode 分离需要精细的并发控制  
**缓解**: 渐进式实现（先同步版本，再异步）  
**优先级**: P0.1 前做 PoC 验证

### 风险 3: 模型适配工作量
**问题**: 30+ 种模型适配可能有隐藏工作  
**缓解**: 建立标准化的模型定义框架，从 10 种高频模型开始  
**优先级**: P0.2 Week 1-2 做充分评估

---

## 🚀 立即可做的工作 (今天开始)

### 1️⃣ P0.2 模型支持扩展 - 开始实现 ✅

**为什么先做这个**:
- 难度最低 (⭐)
- 工作量可控 (3-4 周)
- 业务价值立竿见影 (覆盖度 6 倍扩展)
- 为 P0.3 打好基础

**实现步骤**:
```s
// 1. 抽象模型架构接口
struct model_architecture {
    name: string,
    hidden_size: int,
    num_layers: int,
    vocab_size: int,
    // ...
}

// 2. 工厂模式
func load_model_architecture(model_name: string) result[model_architecture, error] {
    switch model_name {
        "llama" : create_llama_architecture(),
        "qwen" : create_qwen_architecture(),
        "deepseek" : create_deepseek_architecture(),
        // ...
    }
}

// 3. 统一的前向传播接口
func (model: &inference_engine) forward(
    input: &tensor,
    arch: &model_architecture
) result[tensor, error] {
    // 使用 arch 的配置来处理不同模型
}
```

**产生物件**:
- `model_loader.s` (200 行) - 加载器
- `model_architectures.s` (300 行) - 30+ 种模型定义
- `model_adapter.s` (250 行) - 适配器框架

### 2️⃣ P1.1 Logits Processors - 并行实现 ✅

**为什么同时做这个**:
- 难度很低 (⭐⭐)
- 独立模块（不受 P0.2 影响）
- 可以快速集成
- 业务收益高（采样灵活性）

**实现步骤**:
```s
// 温度缩放
func apply_temperature(logits: &vec[float], temperature: float) &vec[float] {
    // 简单除法
}

// Top-K 采样
func apply_top_k(logits: &vec[float], k: int) &vec[float] {
    // 排序 + 过滤
}

// Nucleus (Top-P) 采样
func apply_nucleus(logits: &vec[float], top_p: float) &vec[float] {
    // 累积概率 + 阈值
}

// 集成到采样管道
func (engine: &inference_engine) sample_with_logits_processors(
    logits: &vec[float],
    params: &sampling_params
) int {
    let mut processed = logits.clone()
    
    // 应用所有处理器
    if params.temperature != 1.0 {
        processed = apply_temperature(processed, params.temperature)
    }
    
    if params.top_k > 0 {
        processed = apply_top_k(processed, params.top_k)
    }
    
    if params.top_p < 1.0 {
        processed = apply_nucleus(processed, params.top_p)
    }
    
    // 采样
    sample_from_logits(processed)
}
```

**产生物件**:
- `logits_processors.s` (400 行) - 完整处理管道

---

## 🎯 成功指标

### Phase 1 成功标准

- ✅ 支持 30+ 种模型 (LLaMA, Qwen, DeepSeek, Mistral, Llama2, etc.)
- ✅ Logits 采样管道完整
- ✅ KV 缓存卸载可工作 (显存节省 50%)
- ✅ 吞吐量 3-5x 提升 (vs 当前)
- ✅ 所有功能 100% Pure S 实现

### Phase 2 成功标准

- ✅ LoRA 系统全功能
- ✅ 结构化输出支持
- ✅ 分布式推理可靠
- ✅ 吞吐量 5-8x 提升
- ✅ 功能覆盖度 70%

### Phase 3 成功标准

- ✅ 推理投机解码 (2-3x 加速)
- ✅ 编译优化
- ✅ 多模态支持
- ✅ 吞吐量 8-15x 提升
- ✅ 功能覆盖度 85%+
- ✅ 代码质量超越 vLLM (60% 更简洁)

---

## 🔗 相关文档

- `VLLM_VS_NEURX_COMPREHENSIVE_GAP_ANALYSIS.md` - 完整功能对比
- `VLLM_VS_NEURX_QUICK_REFERENCE.md` - 快速查询表
- `VLLM_VS_NEURX_IMPLEMENTATION_CHECKLIST.md` - 详细实现清单
- `VLLM_VS_NEURX_EXECUTIVE_SUMMARY.md` - 管理层摘要

---

## 📌 关键决策

**Decision 1**: 优先做 P0.2 (模型支持) 还是 P0.1 (V1 API)?
- **推荐**: P0.2 先完成 (降低风险，快速赢)
- **时间**: P0.2 (3-4w) + P1.1 (2-3w) = 5-7w 先实现
- **收益**: 覆盖度 6x + 采样灵活性，业务价值明确

**Decision 2**: Phase 1 是否包含 P0.1 V1 API?
- **如果时间充足**: 包含 (10-12w 内完成)
- **如果时间紧张**: 推到 Phase 2 中期

**Decision 3**: 代码是否 100% Pure S?
- **答案**: 是 (用户要求，而且更简洁)
- **例外**: 系统接口用 S 的 FFI 包装

---

**下一步**: 现在开始实现 P0.2 模型支持扩展和 P1.1 Logits Processors!
