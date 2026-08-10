# NeurX 高级功能实现方案 (S 语言)

## 概述

本文档记录为 NeurX 推理系统实现四个关键企业级功能的 S 语言方案。

### 已创建的模块

| 模块 | 路径 | 行数 | 状态 | 功能 |
|------|------|------|------|------|
| **Model Registry** | `advanced/model_registry.s` | 280 | ⏳ 编译调整中 | 多模型架构支持 |
| **Async Engine** | `advanced/async_engine.s` | 380 | ⏳ 编译调整中 | 并发请求处理 |
| **Multimodal** | `advanced/multimodal.s` | 350 | ⏳ 编译调整中 | 图像/音频融合 |
| **Distributed** | `advanced/distributed.s` | 380 | ⏳ 编译调整中 | 多GPU分布式 |

---

## 第一步：编译问题与解决方案

### 问题：S 编译器限制

S 语言当前版本的限制：
- ❌ 不支持 `enum` 类型声明
- ❌ 不支持现代 `const` 块
- ✅ 支持 `struct` 定义
- ✅ 支持 `func` 函数
- ✅ 支持基本类型 (int, float, string, []T)

### 解决方案：使用类型别名 + 常量

**原来的 enum 风格**:
```s
enum ModelType {
    QWEN
    LLAMA
    MIXTRAL
}
```

**改为常量风格**:
```s
// Constants for ModelType
int MODEL_TYPE_QWEN = 1
int MODEL_TYPE_LLAMA = 2
int MODEL_TYPE_MIXTRAL = 3

// Or use string constants
string MODEL_TYPE_QWEN_STR = "qwen"
string MODEL_TYPE_LLAMA_STR = "llama"
```

---

## 第二步：S 语言兼容版本

### 2.1 Model Registry (兼容版)

```s
// advanced/model_registry_compat.s - S语言兼容版本
package neurx.inference.advanced.model_registry_compat

// Model type constants
int MODEL_TYPE_QWEN = 1
int MODEL_TYPE_LLAMA = 2
int MODEL_TYPE_MIXTRAL = 3

// Architecture configuration (without enum)
struct ArchitectureConfig {
    string name
    int model_type          // Use constants instead of enum
    
    int num_hidden_layers
    int hidden_size
    int num_attention_heads
    int intermediate_size
    int vocab_size
    int max_position_embeddings
    
    // Feature flags
    bool use_rope_scaling
    bool use_dynamic_ntk
    bool use_gqa
    bool use_flash_attn
    
    string dtype             // "float32", "float16", "bfloat16"
    string quantization      // "none", "awq", "gptq"
    
    float rope_theta
    float layer_norm_eps
    float initializer_range
}

// Model factory function type
type ModelFactory func(config ArchitectureConfig) any

// Global registry
struct GlobalRegistry {
    map[string]ModelFactory factories
    map[string]ArchitectureConfig configs
    bool is_initialized
}

var global_registry GlobalRegistry

// Initialize registry
func InitializeRegistry() {
    if global_registry.is_initialized {
        return
    }
    
    global_registry.factories = make(map[string]ModelFactory)
    global_registry.configs = make(map[string]ArchitectureConfig)
    
    // Register models
    register_qwen_models()
    register_llama_models()
    register_mixtral_models()
    
    global_registry.is_initialized = true
}

// Register a model
func RegisterModel(
    string arch_name,
    ArchitectureConfig config,
    ModelFactory factory,
) bool {
    if _, exists := global_registry.factories[arch_name]; exists {
        return false
    }
    
    global_registry.factories[arch_name] = factory
    global_registry.configs[arch_name] = config
    return true
}

func register_qwen_models() {
    // Qwen-7B configuration
    ArchitectureConfig qwen_config = ArchitectureConfig {
        name: "Qwen2.5-7B",
        model_type: MODEL_TYPE_QWEN,
        num_hidden_layers: 32,
        hidden_size: 4096,
        num_attention_heads: 32,
        intermediate_size: 11008,
        vocab_size: 151936,
        max_position_embeddings: 131072,
        use_dynamic_ntk: true,
        use_rope_scaling: true,
        rope_theta: 1000000.0,
        layer_norm_eps: 1e-6,
        dtype: "float32",
    }
    
    RegisterModel(
        "QwenForCausalLM",
        qwen_config,
        func(config ArchitectureConfig) any {
            return any(nil)
        },
    )
}

func register_llama_models() {
    // Llama configuration
    ArchitectureConfig llama_config = ArchitectureConfig {
        name: "Llama-2-7B",
        model_type: MODEL_TYPE_LLAMA,
        num_hidden_layers: 32,
        hidden_size: 4096,
        num_attention_heads: 32,
        intermediate_size: 11008,
        vocab_size: 32000,
        max_position_embeddings: 4096,
        rope_theta: 10000.0,
        layer_norm_eps: 1e-5,
        dtype: "float32",
    }
    
    RegisterModel("LlamaForCausalLM", llama_config, 
        func(config ArchitectureConfig) any {
            return any(nil)
        })
}

func register_mixtral_models() {
    // Mixtral configuration
    ArchitectureConfig mixtral_config = ArchitectureConfig {
        name: "Mixtral-8x7B",
        model_type: MODEL_TYPE_MIXTRAL,
        num_hidden_layers: 32,
        hidden_size: 4096,
        intermediate_size: 14336,
        vocab_size: 32000,
        rope_theta: 10000.0,
        dtype: "float32",
    }
    
    RegisterModel("MixtralForCausalLM", mixtral_config,
        func(config ArchitectureConfig) any {
            return any(nil)
        })
}

func main() {
    InitializeRegistry()
    println("Model registry initialized")
}
```

### 2.2 Async Engine (兼容版)

关键修改：
- 使用 `int` 常量代替 `enum RequestStatus`
- 使用 `string` 代替 `enum CommunicationOp`
- 调整时间戳函数以兼容 S 语言

### 2.3 Multimodal Input (兼容版)

关键修改：
- 使用 `int` 常量代替 `enum ModalityType`
- 使用 `string` 常量代替 `enum ImageFormat`
- 简化字符串处理以避免 S 语言的限制

### 2.4 Distributed (兼容版)

关键修改：
- 使用常量代替枚举定义
- 简化通信原语（在纯 S 语言中模拟）

---

## 第三步：集成方案

### 3.1 架构层次

```
HTTP Server (现有: api/http_server.s)
    ↓
AsyncEngine (新增: async_engine_compat.s)
    ├─ RequestQueue
    ├─ Scheduler
    └─ Metrics
    ↓
ModelRegistry (新增: model_registry_compat.s)
    ├─ QwenModel
    ├─ LlamaModel
    └─ MixtralModel
    ↓
InferenceEngine (现有: inference_engine.s)
    ├─ Transformer Forward
    ├─ KV Cache
    └─ Sampling
    ↓
MultimodalInput (新增: multimodal_compat.s)
    ├─ ImageEncoder (Vision)
    ├─ AudioEncoder
    └─ FeatureFusion
    ↓
DistributedState (新增: distributed_compat.s)
    ├─ ProcessGroup
    ├─ TensorShard
    └─ Collectives
```

### 3.2 集成点

**1. HTTP API → AsyncEngine**
```s
// 在 http_server.s 中添加
func handle_inference_request(request string) {
    // 解析 JSON 请求
    prompt := extract_prompt(request)
    sampling_params := extract_sampling_params(request)
    
    // 创建异步请求
    req := InferenceRequest {
        request_id: generate_id(),
        prompt: prompt,
        sampling_params: sampling_params,
    }
    
    // 加入异步引擎队列
    success := async_engine.EnqueueRequest(req)
    
    // 返回请求 ID
    return_response(req.request_id)
}
```

**2. AsyncEngine → ModelRegistry**
```s
// 在 async_engine_compat.s 中
func (engine *AsyncInferenceEngine) ProcessBatch(
    []InferenceRequest batch,
) []CompletionOutput {
    
    // 从注册表加载模型
    model_factory := get_model_factory("QwenForCausalLM")
    model := model_factory(config)
    
    // 执行推理
    outputs := model.forward(batch_input)
}
```

**3. MultimodalInput → InferenceEngine**
```s
// 在 multimodal_compat.s 中
func (processor *MultimodalProcessor) ProcessInput(
    MultimodalInput input,
) ([]int, [][]float) {
    
    // 编码所有模态
    text_tokens := tokenize(input.text)
    image_features := processor.encode_images(input.images)
    audio_features := processor.encode_audio(input.audio)
    
    // 融合特征
    merged := merge_features(
        text_tokens, image_features, audio_features)
    
    // 返回给推理引擎
    return merged
}
```

---

## 第四步：编译与测试计划

### 4.1 编译步骤

```bash
# 1. 编译兼容版本模块
cd /home/shuwen/shuwen/neurx/inference/advanced

# Model Registry
s_seed model_registry_compat.s artifacts/model_registry.ir

# Async Engine  
s_seed async_engine_compat.s artifacts/async_engine.ir

# Multimodal
s_seed multimodal_compat.s artifacts/multimodal.ir

# Distributed
s_seed distributed_compat.s artifacts/distributed.ir

# 2. 集成到 Makefile
make posttrain-inference-advanced
```

### 4.2 测试用例

```s
// tests/test_advanced_features.s

func test_model_registry() {
    InitializeRegistry()
    
    // Test: Get Qwen config
    config := GetArchitectureConfig("QwenForCausalLM")
    assert(config.hidden_size == 4096)
    assert(config.num_hidden_layers == 32)
    
    println("✓ Model Registry Test Passed")
}

func test_async_engine() {
    engine := NewAsyncEngine(4, 16, true)
    
    // Test: Enqueue request
    req := InferenceRequest {
        request_id: "test-001",
        prompt: "Hello",
    }
    
    success := engine.EnqueueRequest(req)
    assert(success == true)
    
    println("✓ Async Engine Test Passed")
}

func test_multimodal_processor() {
    processor := NewMultimodalProcessor()
    
    // Test: Process text-only
    input := MultimodalInput {
        text: "What is AI?",
    }
    
    tokens, features := processor.ProcessInput(input)
    assert(len(tokens) > 0)
    
    println("✓ Multimodal Test Passed")
}

func main() {
    test_model_registry()
    test_async_engine()
    test_multimodal_processor()
    println("\n✅ All advanced feature tests passed!")
}
```

---

## 第五步：性能基准

### 5.1 预期性能指标

| 指标 | 单模型 (当前) | 多模型 (新增) | 改进 |
|------|------------|-----------|------|
| **模型切换延迟** | N/A | <10ms | 新增能力 |
| **并发请求** | 1 | 16 | 16x |
| **吞吐量** | 10 req/s | 50+ req/s | 5x+ |
| **多模态编码** | N/A | <50ms/image | 新增能力 |
| **代码大小** | 16.6K 行 | 20K+ 行 | +3.4K 行 |

### 5.2 优化空间

1. **内存优化**: 
   - 张量分片减少显存占用 (TP: 50%)
   - KV 缓存预分配

2. **延迟优化**:
   - 计算与通信重叠
   - 推测执行

3. **吞吐量优化**:
   - 连续批处理
   - 动态批次大小

---

## 第六步：推荐实施顺序

### Phase 1 (1-2 周): 基础设施
- [ ] 创建 `advanced/` 目录结构
- [ ] 实现 model_registry_compat.s (兼容版)
- [ ] 通过编译与单元测试

### Phase 2 (2-3 周): 核心功能
- [ ] 实现 async_engine_compat.s
- [ ] 集成到 HTTP API
- [ ] 测试并发请求

### Phase 3 (3-4 周): 多模态
- [ ] 实现 multimodal_compat.s
- [ ] CLIP/视觉编码器集成
- [ ] 医学图像处理示例

### Phase 4 (4-6 周): 分布式 (可选)
- [ ] 实现 distributed_compat.s (模拟)
- [ ] 通信原语测试
- [ ] 多GPU扩展评估

---

## 总结

NeurX 可通过纯 S 语言实现企业级功能，关键是：

1. **适应编译器限制** → 使用常量代替枚举
2. **模块化设计** → 清晰的接口边界
3. **增量集成** → 逐步添加功能
4. **兼容性优先** → 确保编译和测试

**预期成果**:
- ✅ 支持多种模型架构
- ✅ 并发请求处理
- ✅ 多模态输入融合
- ✅ 分布式推理基础

**代码量**: ~4,000-5,000 行纯 S 代码
**开发时间**: 8-12 周
**团队规模**: 2-3 人

