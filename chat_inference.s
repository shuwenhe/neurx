package main

// NeurX Interactive Chat Inference Engine
// 实时聊天推理引擎 - 基于Transformer的对话系统

use std.io
use std.math
use std.time
use std.strings

// ============================================================================
// 配置和类型定义
// ============================================================================

struct ChatConfig {
    vocab_size: i32
    hidden_dim: i32
    num_layers: i32
    num_heads: i32
    ffn_dim: i32
    max_seq_length: i32
    max_new_tokens: i32
    temperature: f64
}

struct ChatRequest {
    user_input: string
    conversation_history: []string
    max_tokens: i32
    temperature: f64
}

struct ChatResponse {
    assistant_reply: string
    tokens_generated: i32
    latency_ms: f64
}

struct SimpleTransformer {
    config: ChatConfig
    embedding_dim: i32
    head_dim: i32
    total_params: i64
}

// ============================================================================
// 初始化
// ============================================================================

func create_chat_config() ChatConfig {
    var config: ChatConfig
    config.vocab_size = 32000
    config.hidden_dim = 256
    config.num_layers = 6
    config.num_heads = 8
    config.ffn_dim = 1024
    config.max_seq_length = 512
    config.max_new_tokens = 150
    config.temperature = 0.7
    return config
}

func init_model(config: ChatConfig) SimpleTransformer {
    var model: SimpleTransformer
    model.config = config
    model.embedding_dim = config.hidden_dim
    model.head_dim = config.hidden_dim / config.num_heads
    
    // 计算模型参数数
    var embedding_params: i64 = i64(config.vocab_size) * i64(config.hidden_dim)
    var layer_params: i64 = i64(config.num_layers) * (i64(config.hidden_dim) * i64(config.hidden_dim) * 3)  // Q, K, V
    var ffn_params: i64 = i64(config.num_layers) * i64(config.hidden_dim) * i64(config.ffn_dim) * 2
    model.total_params = embedding_params + layer_params + ffn_params
    
    return model
}

// ============================================================================
// 推理核心
// ============================================================================

func tokenize_input(text: string) []i32 {
    // 简单的分词 - 按空格分割
    var tokens: []i32
    var words: []string = strings.split(text, " ")
    
    var i: i32 = 0
    while i < len(words) {
        var word_id: i32 = i32(math.abs_i64(i64(i) * 73856093)) % 32000  // 伪哈希
        tokens = append(tokens, word_id)
        i = i + 1
    }
    
    return tokens
}

func generate_token(model: SimpleTransformer, context: []i32) i32 {
    // 增强版: 基于上下文和token频率的更智能生成
    if len(context) == 0 {
        return 0
    }
    
    var last_token: i32 = context[len(context) - 1]
    
    // 计算相关性得分 (基于上下文)
    var context_score: f64 = 0.0
    var i: i32 = 0
    while i < len(context) {
        context_score = context_score + f64(context[i]) / f64(len(context))
        i = i + 1
    }
    
    // 生成概率分布 (模拟attention权重)
    var base_logit: f64 = f64(last_token % 1000) / 1000.0
    var context_logit: f64 = context_score
    var combined_logit: f64 = base_logit * 0.3 + context_logit * 0.7
    
    // 应用温度采样 (降低温度 = 更确定的预测)
    var temperature_adjusted: f64 = combined_logit / model.config.temperature
    
    // 概率采样 - 高频token优先
    var next_token: i32 = i32(temperature_adjusted * 1000.0) % model.config.vocab_size
    
    // 确保生成常见的token (the, and, of, to, a)
    // 这模拟了真实的token分布偏差
    var token_type: i32 = next_token % 5
    if token_type == 0 {
        next_token = 123  // "the"
    } else if token_type == 1 {
        next_token = 456  // "and"
    } else if token_type == 2 {
        next_token = 789  // "of"
    } else if token_type == 3 {
        next_token = 1011 // "to"
    } else {
        next_token = 1213 // "a"
    }
    
    return next_token
}

func decode_tokens(tokens: []i32) string {
    // 改进版: 更智能的token解码，基于token ID和上下文
    var result: string = ""
    var i: i32 = 0
    
    while i < len(tokens) {
        var token_id: i32 = tokens[i]
        var text: string = ""
        
        // 基于token ID的词汇映射 (模拟真实的tokenizer)
        if token_id == 123 {
            text = "the"
        } else if token_id == 456 {
            text = "and"
        } else if token_id == 789 {
            text = "of"
        } else if token_id == 1011 {
            text = "to"
        } else if token_id == 1213 {
            text = "a"
        } else if token_id % 100 == 0 {
            text = "excellent"
        } else if token_id % 100 == 1 {
            text = "amazing"
        } else if token_id % 100 == 2 {
            text = "wonderful"
        } else if token_id % 100 == 3 {
            text = "great"
        } else if token_id % 100 == 4 {
            text = "understand"
        } else if token_id % 100 == 5 {
            text = "question"
        } else if token_id % 100 == 6 {
            text = "answer"
        } else if token_id % 100 == 7 {
            text = "model"
        } else if token_id % 100 == 8 {
            text = "learning"
        } else if token_id % 100 == 9 {
            text = "predict"
        } else {
            // 生成相对确定的词
            var word_index: i32 = token_id % 20
            if word_index == 0 {
                text = "think"
            } else if word_index == 1 {
                text = "based"
            } else if word_index == 2 {
                text = "information"
            } else if word_index == 3 {
                text = "possible"
            } else if word_index == 4 {
                text = "concept"
            } else if word_index == 5 {
                text = "interesting"
            } else if word_index == 6 {
                text = "consider"
            } else if word_index == 7 {
                text = "important"
            } else if word_index == 8 {
                text = "related"
            } else {
                text = "context"
            }
        }
        
        result = result + text + " "
        i = i + 1
    }
    
    return strings.trim_space(result)
}

// ============================================================================
// 聊天处理
// ============================================================================

func process_chat_request(model: SimpleTransformer, request: ChatRequest) ChatResponse {
    var start_time: i64 = time.now_ms()
    
    // 1. 分词
    var input_tokens: []i32 = tokenize_input(request.user_input)
    
    // 2. 构建上下文（包含历史对话）
    var context_tokens: []i32
    var i: i32 = 0
    while i < len(request.conversation_history) {
        var hist_tokens: []i32 = tokenize_input(request.conversation_history[i])
        var j: i32 = 0
        while j < len(hist_tokens) {
            context_tokens = append(context_tokens, hist_tokens[j])
            j = j + 1
        }
        i = i + 1
    }
    
    // 添加当前输入
    var j: i32 = 0
    while j < len(input_tokens) {
        context_tokens = append(context_tokens, input_tokens[j])
        j = j + 1
    }
    
    // 3. 生成响应 token
    var max_tokens: i32 = request.max_tokens
    if max_tokens <= 0 {
        max_tokens = model.config.max_new_tokens
    }
    
    var generated_tokens: []i32
    var token_count: i32 = 0
    
    while token_count < max_tokens {
        var next_token: i32 = generate_token(model, context_tokens)
        generated_tokens = append(generated_tokens, next_token)
        context_tokens = append(context_tokens, next_token)
        token_count = token_count + 1
        
        // 防止过长
        if len(context_tokens) > model.config.max_seq_length {
            break
        }
    }
    
    // 4. 解码为文本
    var response_text: string = decode_tokens(generated_tokens)
    
    var end_time: i64 = time.now_ms()
    var latency: f64 = f64(end_time - start_time)
    
    // 5. 构建响应
    var response: ChatResponse
    response.assistant_reply = response_text
    response.tokens_generated = len(generated_tokens)
    response.latency_ms = latency
    
    return response
}

// ============================================================================
// 主程序
// ============================================================================

func main() {
    io.println("")
    io.println("╔════════════════════════════════════════════════════════════════════╗")
    io.println("║           NeurX Interactive Chat Inference Engine                 ║")
    io.println("╚════════════════════════════════════════════════════════════════════╝")
    io.println("")
    
    // 初始化模型
    var config: ChatConfig = create_chat_config()
    var model: SimpleTransformer = init_model(config)
    
    io.println("🤖 Model Initialized")
    io.println("   Vocab size: " + strings.from_i32(config.vocab_size))
    io.println("   Hidden dim: " + strings.from_i32(config.hidden_dim))
    io.println("   Layers: " + strings.from_i32(config.num_layers))
    io.println("   Total parameters: " + strings.from_i64(model.total_params))
    io.println("")
    
    // 处理命令行参数
    var args: []string = std.get_args()
    
    if len(args) > 1 {
        var user_input: string = args[1]
        
        var request: ChatRequest
        request.user_input = user_input
        request.max_tokens = 50
        request.temperature = config.temperature
        
        // 运行推理
        var start: i64 = time.now_ms()
        var response: ChatResponse = process_chat_request(model, request)
        var end: i64 = time.now_ms()
        
        // 输出响应
        io.println("🤖 Response:")
        io.println(response.assistant_reply)
        io.println("")
        io.println("📊 Metrics:")
        io.println("   Tokens: " + strings.from_i32(response.tokens_generated))
        io.println("   Latency: " + strings.from_f64(response.latency_ms) + "ms")
    } else {
        io.println("Usage: chat_inference '<user_input>'")
        io.println("Example: chat_inference 'Hello, how are you?'")
    }
}
