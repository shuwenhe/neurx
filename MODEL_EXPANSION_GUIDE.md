# NeurX 模型扩展快速指南

**目标**: 从 16 个模型快速扩展到 50+ 个  
**难度**: ⭐ 非常简单  
**时间**: 15 分钟/模型

---

## 🎯 目标扩展清单

### 第一阶段 (简单, 2 小时)
添加 10 个新模型变体，达到 **26 个**

- [ ] Llama 3.1-8B (新上下文: 131K)
- [ ] Llama 3.1-70B (超大)
- [ ] Qwen 1.5-7B (v1.5 版本)
- [ ] Qwen 72B (超大)
- [ ] Yi-6B (本地优化)
- [ ] Yi-34B (超大)
- [ ] Baichuan-7B (中文优化)
- [ ] Baichuan2-13B (改进版)
- [ ] ChatGLM-6B (中文专优)
- [ ] Phi-1.5 (最小, 1.5B)

### 第二阶段 (中等, 1 周)
再添加 20 个，达到 **46 个** (接近 sglang)

- [ ] 所有 Llama 变体 (3.1-405B, 2-7b, 2-13b, 2-70b...)
- [ ] 所有 Qwen 变体 (0.5B, 1.8B, 7B, 14B, 32B, 72B...)
- [ ] MPT (开源竞品)
- [ ] Falcon (大模型)
- [ ] StableLM (稳定版)
- [ ] Zephyr (对齐版)
- [ ] 其他...

---

## 📝 扩展步骤

### 步骤 1: 查找模型参数

从 HuggingFace 获取 config.json:

```bash
# 以 Llama 3.1-8B 为例
curl -s https://huggingface.co/meta-llama/Llama-2-8b/raw/main/config.json | jq
```

**关键参数**:
```json
{
  "hidden_size": 4096,
  "num_hidden_layers": 32,
  "num_attention_heads": 32,
  "num_key_value_heads": 8,
  "intermediate_size": 14336,
  "vocab_size": 128256,
  "max_position_embeddings": 131072,
  "rope_theta": 500000.0,
  "hidden_act": "silu",
  "norm_eps": 1e-05,
  ...
}
```

### 步骤 2: 识别模型家族

| 模型 | 家族 | 特征 |
|------|------|------|
| Llama 3.1-8B | `llama` | GQA, RoPE, SiLU |
| Qwen 1.5-7B | `qwen` | MHA, RoPE, SwiGLU |
| Yi-34B | `llama` | GQA, RoPE (衍生) |
| Baichuan-7B | `baichuan` | ALiBi, GeLU |
| ChatGLM-6B | `chatglm` | 特殊位置嵌入 |

### 步骤 3: 在 base_llm_model.s 中添加配置

打开: `/home/shuwen/shuwen/neurx/models/base_llm_model.s`

在 `NewModelConfig()` 函数中添加:

```s
func NewModelConfig(model_type string) model_config {
    // ... 现有代码 ...
    
    // ===== 新增配置 START =====
    
    // Llama 3.1 系列
    } else if model_type == "llama3.1-8b" {
        config.vocab_size = 128256
        config.hidden_size = 4096
        config.num_attention_heads = 32
        config.num_key_value_heads = 8
        config.intermediate_size = 14336
        config.max_position_embeddings = 131072
        config.rope_base = 500000.0
        config.hidden_act = ACT_SILU
        config.attention_type = ATTN_GQA
        
    } else if model_type == "llama3.1-70b" {
        config.vocab_size = 128256
        config.hidden_size = 8192
        config.num_attention_heads = 64
        config.num_key_value_heads = 8
        config.intermediate_size = 28672
        config.max_position_embeddings = 131072
        config.rope_base = 500000.0
        config.hidden_act = ACT_SILU
        config.attention_type = ATTN_GQA
        
    // Qwen 1.5 系列
    } else if model_type == "qwen1.5-7b" {
        config.vocab_size = 152064
        config.hidden_size = 4096
        config.num_attention_heads = 32
        config.num_key_value_heads = 32
        config.intermediate_size = 11008
        config.max_position_embeddings = 32768
        config.hidden_act = ACT_SWIGLU
        config.attention_type = ATTN_MHA
        
    } else if model_type == "qwen1.5-72b" {
        config.vocab_size = 152064
        config.hidden_size = 8192
        config.num_attention_heads = 64
        config.num_key_value_heads = 64
        config.intermediate_size = 27392
        config.max_position_embeddings = 32768
        config.hidden_act = ACT_SWIGLU
        config.attention_type = ATTN_MHA
        
    // Yi 系列 (Llama 衍生)
    } else if model_type == "yi-6b" {
        config.vocab_size = 64000
        config.hidden_size = 4096
        config.num_attention_heads = 32
        config.num_key_value_heads = 8
        config.intermediate_size = 11008
        config.max_position_embeddings = 4096
        config.hidden_act = ACT_SILU
        config.attention_type = ATTN_GQA
        
    } else if model_type == "yi-34b" {
        config.vocab_size = 64000
        config.hidden_size = 7168
        config.num_attention_heads = 56
        config.num_key_value_heads = 8
        config.intermediate_size = 20480
        config.max_position_embeddings = 4096
        config.hidden_act = ACT_SILU
        config.attention_type = ATTN_GQA
        
    // Baichuan 系列 (中文优化)
    } else if model_type == "baichuan-7b" {
        config.vocab_size = 100000
        config.hidden_size = 4096
        config.num_attention_heads = 32
        config.num_key_value_heads = 32
        config.intermediate_size = 11008
        config.max_position_embeddings = 4096
        config.position_embedding_type = POS_ALIBI
        config.hidden_act = ACT_SILU
        config.attention_type = ATTN_MHA
        
    } else if model_type == "baichuan2-13b" {
        config.vocab_size = 125696
        config.hidden_size = 5120
        config.num_attention_heads = 40
        config.num_key_value_heads = 40
        config.intermediate_size = 13696
        config.max_position_embeddings = 4096
        config.position_embedding_type = POS_ALIBI
        config.hidden_act = ACT_SILU
        config.attention_type = ATTN_MHA
        
    // ChatGLM 系列 (中文专优)
    } else if model_type == "chatglm-6b" {
        config.vocab_size = 150528
        config.hidden_size = 4096
        config.num_attention_heads = 32
        config.num_key_value_heads = 32
        config.intermediate_size = 16384
        config.max_position_embeddings = 2048
        config.position_embedding_type = POS_ROPE
        config.hidden_act = ACT_GELU
        config.attention_type = ATTN_MHA
        
    // Phi 1.5 (最小模型)
    } else if model_type == "phi-1.5" {
        config.vocab_size = 50257
        config.hidden_size = 2048
        config.num_attention_heads = 32
        config.num_key_value_heads = 32
        config.intermediate_size = 8192
        config.max_position_embeddings = 2048
        config.hidden_act = ACT_GELU
        config.attention_type = ATTN_MHA
    
    // ===== 新增配置 END =====
    
    return config
}
```

### 步骤 4: 更新 SupportedModels()

在 `SupportedModels()` 函数中添加新模型:

```s
func SupportedModels() []string {
    return []string{
        // Llama 系列 (原有 + 新增)
        "llama", "llama2", "llama3", "llama4",
        "llama3.1-8b", "llama3.1-70b",  // ← 新增
        
        // Qwen 系列 (原有 + 新增)
        "qwen", "qwen2", "qwen2.5",
        "qwen1.5-7b", "qwen1.5-72b",    // ← 新增
        
        // Deepseek 系列
        "deepseek", "deepseekv3", "deepseekv4",
        
        // Yi 系列 (新增)
        "yi-6b", "yi-34b",              // ← 新增
        
        // Baichuan 系列 (新增)
        "baichuan-7b", "baichuan2-13b", // ← 新增
        
        // ChatGLM 系列 (新增)
        "chatglm-6b",                   // ← 新增
        
        // 其他
        "mistral", "mixtral",
        "gemma", "gemma2",
        "phi", "phi3", "phi-1.5",       // ← 新增 phi-1.5
    }
}
```

### 步骤 5: 编译并测试

```bash
cd /home/shuwen/shuwen/neurx

# 编译
make clean && make

# 测试新模型
cat > test_new_models.s << 'EOF'
func main() {
    // 测试 Llama 3.1-8B
    var llama31_config = NewModelConfig("llama3.1-8b")
    println("Llama 3.1-8B:")
    println("  Hidden size: " + strings.from_i32(llama31_config.hidden_size))
    println("  Vocab size: " + strings.from_i32(llama31_config.vocab_size))
    println("  Max seq len: " + strings.from_i32(llama31_config.max_position_embeddings))
    
    // 测试 Qwen 1.5-72B
    var qwen_config = NewModelConfig("qwen1.5-72b")
    println("\nQwen 1.5-72B:")
    println("  Hidden size: " + strings.from_i32(qwen_config.hidden_size))
    println("  Vocab size: " + strings.from_i32(qwen_config.vocab_size))
    
    // 测试 Yi-34B
    var yi_config = NewModelConfig("yi-34b")
    println("\nYi-34B:")
    println("  Hidden size: " + strings.from_i32(yi_config.hidden_size))
    println("  Vocab size: " + strings.from_i32(yi_config.vocab_size))
    
    // 打印所有支持的模型
    println("\nAll supported models:")
    var models = SupportedModels()
    for i := 0; i < len(models); i++ {
        println("  - " + models[i])
    }
}
EOF

s build test_new_models.s
s run test_new_models
```

---

## 📊 优化建议

### 优化 1: 使用模型变体基类

```s
// 避免重复, 使用"原型"模式
func get_base_config(base_type string) model_config {
    // 先获取基础配置
    base := NewModelConfig(base_type)
    return base
}

// 然后针对变体微调
func NewModelConfig(model_type string) model_config {
    config := model_config{...}  // 默认值
    
    if model_type == "llama" {
        config.vocab_size = 32000
    } else if model_type == "llama3.1-8b" {
        // 从 llama3 基础变体开始
        base := NewModelConfig("llama3")
        base.max_position_embeddings = 131072
        base.rope_base = 500000.0
        return base
    }
}
```

### 优化 2: 配置表驱动

```s
// 可创建单独文件: model_configs_table.s
type model_preset struct {
    name string
    vocab_size int32
    hidden_size int32
    num_layers int32
    num_heads int32
    intermediate_size int32
    max_seq_len int32
    rope_theta float32
}

var model_presets = []model_preset{
    {
        name: "llama3.1-8b",
        vocab_size: 128256,
        hidden_size: 4096,
        num_layers: 32,
        num_heads: 32,
        intermediate_size: 14336,
        max_seq_len: 131072,
        rope_theta: 500000.0,
    },
    // ... 更多预设
}

func NewModelConfigFromPreset(preset_name string) model_config {
    for i := 0; i < len(model_presets); i++ {
        if model_presets[i].name == preset_name {
            // 填充配置
            return model_config{...}
        }
    }
    return model_config{}  // 默认
}
```

---

## ⚡ 快速检查清单

添加每个模型时, 验证:

```
- [ ] 模型名称在 SupportedModels() 中
- [ ] 配置中所有参数都填充了
- [ ] vocab_size 正确 (关键!)
- [ ] hidden_size / num_layers 一致
- [ ] 注意力类型正确 (GQA/MHA/MQA/MLA)
- [ ] 激活函数正确 (SILU/GELU/SWIGLU)
- [ ] 位置嵌入类型正确 (ROPE/ALIBI/ABSOLUTE)
- [ ] max_position_embeddings 合理
- [ ] rope_theta 值准确 (ROPE 模型)
- [ ] 编译通过 (make clean && make)
- [ ] 测试通过 (s run test_new_models)
```

---

## 📈 扩展里程碑

| 阶段 | 模型数 | 工作量 | 时间 | 提交命令 |
|------|-------|--------|------|---------|
| **现状** | 16 | - | - | - |
| **第 1 阶段** | 26 | 2 小时 | 3 天 | `git add -A && git commit -m "Add 10 new model variants (Llama 3.1, Qwen 1.5, Yi, Baichuan, ChatGLM)"` |
| **第 2 阶段** | 46 | 8 小时 | 1 周 | `git add -A && git commit -m "Expand model support to 46 models - approaching sglang parity"` |
| **第 3 阶段** | 50+ | 20 小时 | 2 周 | `git add -A && git commit -m "Complete model ecosystem - 50+ models, auto HF loading, full parity with vLLM"` |

---

## 🎯 当前状态

```
✅ 完成: 16 个基础模型
📋 待做: 34 个新模型 (目标 50+)

按家族进度:
├─ Llama: 4/8 ⬜⬜⬜⬜
├─ Qwen: 3/7 ⬜⬜⬜⬜
├─ Deepseek: 3/3 ⬜⬜⬜⬜
├─ Mistral: 2/2 ⬜⬜⬜⬜
├─ Gemma: 2/2 ⬜⬜⬜⬜
├─ Phi: 2/4 ⬜⬜
├─ Yi: 0/2 ⬜⬜⬜⬜
├─ Baichuan: 0/2 ⬜⬜⬜⬜
├─ ChatGLM: 0/1 ⬜⬜⬜⬜⬜
└─ 其他: 0/15 ⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜

总进度: 16/50 ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░
```

---

## 🚀 立即开始

1. **选择一个模型** (推荐: Llama 3.1-8B)
2. **查找参数** (HuggingFace config.json)
3. **复制模板** (上面的代码)
4. **修改参数**
5. **编译测试**
6. **提交**

**预期时间**: 15 分钟/模型 🚀
