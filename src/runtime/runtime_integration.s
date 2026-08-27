package v1

use neurx.inference.runtime.model_manifest.{hf_model_manifest, load_hf_model_manifest}

struct runtime_config {
    string model_path
    string model_name
    int32 vocab_size
    int32 hidden_dim
    int32 num_layers
    int32 max_seq_length

    string http_host
    int32 http_port

    bool enable_streaming
    bool enable_prefix_caching
    int32 max_batch_size
}

func load_config_from_env() runtime_config {
    return runtime_config{
        model_path: "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct",
        model_name: "Qwen2.5-0.5B-Instruct",
        vocab_size: 151936,
        hidden_dim: 896,
        num_layers: 24,
        max_seq_length: 32768,
        http_host: "0.0.0.0",
        http_port: 8000,
        enable_streaming: true,
        enable_prefix_caching: true,
        max_batch_size: 32,
    }
}

struct neurx_runtime {
    runtime_config config
    inference_engine* engine
    http_server* http_server
    pipeline_config pipeline_cfg

    bool is_initialized
    bool is_running
}

func create_neurx_runtime(runtime_config cfg) neurx_runtime* {
    runtime := *neurx_runtime{
        config: cfg,
        engine: nil,
        http_server: nil,
        pipeline_cfg: pipeline_config{
            separate_prefill_decode: true,
            prefill_batch_size: 16,
            decode_batch_size: 32,
            max_batch_tokens: 4096,
            max_seq_length: cfg.max_seq_length,
        },
        is_initialized: false,
        is_running: false,
    }

    return runtime
}

func (neurx_runtime* rt) initialize() bool {
    manifest := load_hf_model_manifest(rt.config.model_path)

    model_cfg := model_config{
        model_name: rt.config.model_name,
        model_path: rt.config.model_path,
        vocab_size: rt.config.vocab_size,
        hidden_dim: rt.config.hidden_dim,
        num_layers: rt.config.num_layers,
        num_heads: 14,
        max_seq_length: rt.config.max_seq_length,
        rope_base: 1000000.0,
    }

    if manifest.valid {
        model_cfg.vocab_size = int32(manifest.config.vocab_size)
        model_cfg.hidden_dim = int32(manifest.config.hidden_size)
        model_cfg.num_layers = int32(manifest.config.num_layers)
        model_cfg.num_heads = int32(manifest.config.num_attention_heads)
        model_cfg.max_seq_length = int32(manifest.config.max_position_embeddings)
        if manifest.config.rope_theta > 0 {
            model_cfg.rope_base = float32(manifest.config.rope_theta)
        }
    }

    rt.engine = create_inference_engine(model_cfg)
    if rt.engine == nil {
        return false
    }

    success := rt.engine.load_model(rt.config.model_path)
    if !success {
        return false
    }

    rt.http_server = create_http_server(rt.config.http_host, rt.config.http_port, rt.engine)
    if rt.http_server == nil {
        return false
    }

    rt.is_initialized = true
    return true
}

func (neurx_runtime* rt) start_serving() bool {
    if !rt.is_initialized {
        return false
    }

    success := rt.http_server.start()
    if !success {
        return false
    }

    rt.is_running = true
    return true
}

func (neurx_runtime* rt) process_batches() bool {
    if !rt.is_running {
        return false
    }

    batch_count := rt.engine.process_batch()
    return batch_count > 0
}

func (neurx_runtime* rt) shutdown() bool {
    if rt.http_server != nil {
        rt.http_server.stop()
    }

    if rt.engine != nil {
        rt.engine.shutdown()
    }

    rt.is_running = false
    return true
}

func (neurx_runtime* rt) serve_loop(int32 max_iterations) bool {
    iteration := 0

    for iteration < max_iterations {
        if !rt.is_running {
            break
        }

        rt.process_batches()
        rt.engine.update_metrics()

        iteration = iteration + 1
    }

    return true
}

func main_test_flow() bool {
    cfg := load_config_from_env()

    rt := create_neurx_runtime(cfg)
    if rt == nil {
        return false
    }

    success := rt.initialize()
    if !success {
        return false
    }

    success = rt.start_serving()
    if !success {
        return false
    }

    req_1_prompt_tokens := make(int32[])
    req_1_prompt_tokens = append(req_1_prompt_tokens, 1)
    req_1_prompt_tokens = append(req_1_prompt_tokens, 2)
    req_1_prompt_tokens = append(req_1_prompt_tokens, 3)

    gen_config := generation_config{
        temperature: 0.7,
        top_p: 0.9,
        top_k: 40,
        repetition_penalty: 1,
    }

    stream := rt.engine.generate_streaming("req_1", req_1_prompt_tokens, 10, gen_config)
    if stream == nil {
        return false
    }

    for i := 0; i < 10; i = i + 1 {
        token, has_more := stream.next_token()
        if token < 0 || !has_more {
            break
        }
    }

    rt.serve_loop(100)

    rt.shutdown()

    return true
}
