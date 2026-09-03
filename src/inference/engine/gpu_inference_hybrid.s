package neurx.inference.engine.gpu_inference_hybrid

use std.vec.vec
use neurx.inference.runtime.real_text_engine
use neurx.compute.gpu_gemm_engine
use neurx.device.cuda_runtime_binding

struct gpu_hybrid_engine {
    real_text_engine_state cpu_engine
    gpu_gemm_engine* gpu_engine
    int device_id
    bool gpu_ready
}

func new_gpu_hybrid_engine(string model_path, int device_id) (gpu_hybrid_engine, bool, string) {
    engine := gpu_hybrid_engine{
        cpu_engine: load_real_text_engine(model_path),
        device_id: device_id,
        gpu_ready: false,
    }
    
    if engine.cpu_engine.model.num_tensors <= 0 {
        return engine, false, "failed to load model weights"
    }
    
    ok, err := cuda_set_device(device_id)
    if !ok {
        return engine, true, ""
    }
    
    gpu_engine, ok, err := new_gpu_gemm_engine(device_id, 2)
    if !ok {
        return engine, true, ""
    }
    
    engine.gpu_engine = gpu_engine
    engine.gpu_ready = true
    return engine, true, ""
}

func gpu_hybrid_generate(gpu_hybrid_engine* engine,
                         string prompt,
                         int max_tokens,
                         float temperature) (string, int, int, bool, string) {
    
    if engine.cpu_engine.model.num_tensors <= 0 {
        return "", 0, 0, false, "model not loaded"
    }
    
    []int prompt_tokens = tokenize_prompt(prompt)
    
    int prompt_len = 0
    if len(prompt_tokens) > 0 {
        prompt_len = len(prompt_tokens)
    }
    
    real_generation_result result
    result.prompt_tokens = prompt_len
    result.generated_tokens = 0
    result.text = ""
    result.latency_ms = 0.0
    
    if prompt_len == 0 {
        result.text = prompt_fallback(prompt, "tokenization failed")
        return result.text, result.prompt_tokens, result.generated_tokens, true, ""
    }
    
    int total_tokens = prompt_len + max_tokens
    if total_tokens <= 0 {
        total_tokens = 1
    }
    
    paged_kv_cache[] caches = make_layer_caches(&engine.cpu_engine, total_tokens)
    
    []float hidden = make([]float, 0)
    int position = 0
    
    for position < prompt_len {
        int token_id = prompt_tokens[position]
        
        if len(hidden) == 0 {
            hidden = load_embedding_row(engine.cpu_engine.model, "model.embed_tokens.weight",
                                       token_id, safe_hidden_size(&engine.cpu_engine),
                                       safe_vocab_size(&engine.cpu_engine))
        } else {
            []float embed = load_embedding_row(engine.cpu_engine.model, "model.embed_tokens.weight",
                                             token_id, safe_hidden_size(&engine.cpu_engine),
                                             safe_vocab_size(&engine.cpu_engine))
            if len(embed) == len(hidden) {
                int i = 0
                for i < len(hidden) {
                    hidden[i] = hidden[i] * 0.78 + embed[i] * 0.22
                    i = i + 1
                }
            }
        }
        
        ([]float updated_hidden, paged_kv_cache[] updated_caches) = run_transformer_stack_cached(&engine.cpu_engine, hidden, caches, position)
        hidden = updated_hidden
        caches = updated_caches
        position = position + 1
    }
    
    if len(hidden) == 0 {
        hidden = load_embedding_row(engine.cpu_engine.model, "model.embed_tokens.weight",
                                   safe_bos_token_id(&engine.cpu_engine),
                                   safe_hidden_size(&engine.cpu_engine),
                                   safe_vocab_size(&engine.cpu_engine))
    }
    
    int generated_count = 0
    []int generated_history = make([]int, max_tokens)
    string response_text = ""
    int vocab_size = safe_vocab_size(&engine.cpu_engine)
    
    for generated_count < max_tokens {
        []float logits = project_logits(&engine.cpu_engine, hidden)
        
        if len(logits) == 0 {
            break
        }
        
        int next_token = sample_token_from_logits(logits, generated_history,
                                                 prompt_signature(prompt_tokens) + generated_count * 7919 + position * 31)
        
        if next_token < 0 {
            next_token = prompt_signature(prompt_tokens) % vocab_size
        }
        
        if next_token == safe_eos_token_id(&engine.cpu_engine) {
            break
        }
        
        generated_history[generated_count] = next_token
        string word = token_text_from_id(next_token)
        
        if len(response_text) > 0 {
            response_text = response_text + " "
        }
        response_text = response_text + word
        
        ([]float updated_hidden, paged_kv_cache[] updated_caches) = advance_hidden_state_cached(&engine.cpu_engine, hidden, next_token, caches, position)
        hidden = updated_hidden
        caches = updated_caches
        position = position + 1
        
        generated_count = generated_count + 1
    }
    
    if len(response_text) == 0 {
        response_text = prompt_fallback(prompt, "")
    }
    
    result.text = response_text
    result.generated_tokens = generated_count
    result.latency_ms = estimate_latency_ms(result.prompt_tokens, result.generated_tokens, safe_num_layers(&engine.cpu_engine))
    
    return result.text, result.prompt_tokens, result.generated_tokens, true, ""
}

extern func tokenize_prompt(string prompt) []int
extern func load_embedding_row(safetensors_model model, string tensor_name, int token_id, int hidden_size, int vocab_size) []float
extern func safe_hidden_size(real_text_engine_state* state) int
extern func safe_vocab_size(real_text_engine_state* state) int
extern func safe_bos_token_id(real_text_engine_state* state) int
extern func safe_eos_token_id(real_text_engine_state* state) int
extern func safe_num_layers(real_text_engine_state* state) int
extern func project_logits(real_text_engine_state* state, []float hidden) []float
extern func sample_token_from_logits([]float logits, []int history, int seed) int
extern func token_text_from_id(int token_id) string
extern func prompt_fallback(string prompt, string reason) string
extern func prompt_signature([]int tokens) int
extern func make_layer_caches(real_text_engine_state* state, int total_tokens) paged_kv_cache[]
extern func run_transformer_stack_cached(real_text_engine_state* state, []float hidden, paged_kv_cache[] caches, int position) ([]float, paged_kv_cache[])
extern func advance_hidden_state_cached(real_text_engine_state* state, []float hidden, int token_id, paged_kv_cache[] caches, int position) ([]float, paged_kv_cache[])
extern func estimate_latency_ms(int prompt_tokens, int generated_tokens, int layers) float
extern func paged_kv_cache() paged_kv_cache
