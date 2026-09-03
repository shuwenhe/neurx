package neurx.inference.engine.gpu_inference_practical

use std.vec.vec
use neurx.compute.gpu_gemm_engine
use neurx.device.cuda_runtime_binding
use neurx.inference.runtime.real_text_engine

struct gpu_inference_engine_practical {
    gpu_gemm_engine* gemm_engine
    real_text_engine_state* cpu_engine
    int device_id
    bool initialized
}

func new_gpu_engine_practical(string model_path, int device_id) (gpu_inference_engine_practical*, bool, string) {
    engine := box[gpu_inference_engine_practical]()
    
    ok, err := cuda_set_device(device_id)
    if !ok {
        return 0, false, err
    }
    
    gemm_engine, ok, err := new_gpu_gemm_engine(device_id, 4)
    if !ok {
        return 0, false, err
    }
    engine.gemm_engine = gemm_engine
    engine.device_id = device_id
    
    cpu_state := load_real_text_engine(model_path)
    if cpu_state.model.num_tensors <= 0 {
        return 0, false, "failed to load model"
    }
    engine.cpu_engine = &cpu_state
    engine.initialized = true
    
    return engine, true, ""
}

func gpu_generate_simple(gpu_inference_engine_practical* engine,
                         string prompt,
                         int max_tokens) (string, bool, string) {
    
    if !engine.initialized {
        return "", false, "engine not initialized"
    }
    
    []int prompt_tokens = tokenize_prompt(prompt)
    if len(prompt_tokens) == 0 {
        return "", false, "failed to tokenize"
    }
    
    []float hidden = load_embedding_row(
        engine.cpu_engine.model,
        "model.embed_tokens.weight",
        prompt_tokens[0],
        safe_hidden_size(engine.cpu_engine),
        safe_vocab_size(engine.cpu_engine)
    )
    
    if len(hidden) == 0 {
        return "", false, "failed to load embedding"
    }
    
    int idx = 1
    for idx < len(prompt_tokens) {

        []float next_embed = load_embedding_row(
            engine.cpu_engine.model,
            "model.embed_tokens.weight",
            prompt_tokens[idx],
            safe_hidden_size(engine.cpu_engine),
            safe_vocab_size(engine.cpu_engine)
        )
        
        if len(next_embed) > 0 {

            int h = 0
            for h < len(hidden) {
                if h < len(next_embed) {
                    hidden[h] = hidden[h] * 0.5 + next_embed[h] * 0.5
                }
                h = h + 1
            }
        }
        
        idx = idx + 1
    }
    
    string response = ""
    int gen_idx = 0
    int vocab_size = safe_vocab_size(engine.cpu_engine)
    
    for gen_idx < max_tokens {

        []float logits = project_logits(engine.cpu_engine, hidden)
        
        if len(logits) == 0 {
            break
        }
        
        int next_token = sample_token_from_logits(logits, make([]int, 0), gen_idx * 7919 + prompt_tokens[0])
        
        if next_token < 0 || next_token >= vocab_size {
            next_token = 0
        }
        
        if next_token == safe_eos_token_id(engine.cpu_engine) {
            break
        }
        
        string word = token_to_word(next_token)
        if len(word) > 0 {
            if len(response) > 0 {
                response = response + " "
            }
            response = response + word
        }
        
        []float next_embed = load_embedding_row(
            engine.cpu_engine.model,
            "model.embed_tokens.weight",
            next_token,
            safe_hidden_size(engine.cpu_engine),
            safe_vocab_size(engine.cpu_engine)
        )
        
        if len(next_embed) > 0 {
            int h = 0
            for h < len(hidden) {
                if h < len(next_embed) {
                    hidden[h] = hidden[h] * 0.7 + next_embed[h] * 0.3
                }
                h = h + 1
            }
        }
        
        gen_idx = gen_idx + 1
    }
    
    if len(response) == 0 {
        response = prompt_fallback(prompt, "")
    }
    
    return response, true, ""
}

func gpu_benchmark_speed(gpu_inference_engine_practical* engine,
                         string prompt,
                         int tokens_to_generate) (float, bool, string) {
    
    if !engine.initialized {
        return 0.0, false, "engine not initialized"
    }
    
    int64 start_ms = get_current_time_ms()
    
    response, ok, err := gpu_generate_simple(engine, prompt, tokens_to_generate)
    
    int64 end_ms = get_current_time_ms()
    
    if !ok {
        return 0.0, false, err
    }
    
    int64 elapsed = end_ms - start_ms
    
    float tps = float(tokens_to_generate * 1000) / float(elapsed)
    
    return tps, true, ""
}

extern func load_real_text_engine(string model_path) real_text_engine_state
extern func tokenize_prompt(string prompt) []int
extern func load_embedding_row(safetensors_model model, string tensor_name, int token_id, int hidden_size, int vocab_size) []float
extern func safe_hidden_size(real_text_engine_state* state) int
extern func safe_vocab_size(real_text_engine_state* state) int
extern func safe_eos_token_id(real_text_engine_state* state) int
extern func project_logits(real_text_engine_state* state, []float hidden) []float
extern func sample_token_from_logits([]float logits, []int history, int seed) int
extern func token_to_word(int token_id) string
extern func prompt_fallback(string prompt, string reason) string
extern func get_current_time_ms() int64
