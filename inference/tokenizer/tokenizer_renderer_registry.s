package neurx.inference.tokenizer.tokenizer_renderer_registry
func tokenizer_backend_hf() int { 1 }

func tokenizer_backend_mistral() int { 2 }

func tokenizer_backend_deepseek_v32() int { 3 }

func tokenizer_backend_deepseek_v4() int { 4 }

func tokenizer_backend_kimi_audio() int { 5 }

func renderer_backend_hf() int { 1 }

func renderer_backend_mistral() int { 2 }

func renderer_backend_cohere() int { 3 }

func renderer_backend_deepseek() int { 4 }

func renderer_backend_inkling() int { 5 }

func renderer_backend_kimi() int { 6 }

func tokenizer_truncate_left() int { 1 }

func tokenizer_truncate_right() int { 2 }

struct tokenizer_renderer_request {
    string tokenizer_mode
    string model_family
    string runner_type
    bool use_fast
    bool skip_tokenizer_init
}

struct tokenizer_renderer_selection {
    int tokenizer_backend
    int renderer_backend
    int truncation_side
    bool tokenizer_available
    bool supported
    int error_code
}

func tokenizer_mode_backend(string mode, string family) int {
    if mode == "mistral" || (mode == "auto" && family == "mistral") { return tokenizer_backend_mistral() }
    if mode == "deepseek_v32" || (mode == "auto" && family == "deepseek_v32") { return tokenizer_backend_deepseek_v32() }
    if mode == "deepseek_v4" || (mode == "auto" && family == "deepseek_v4") { return tokenizer_backend_deepseek_v4() }
    if mode == "kimi_audio" || (mode == "auto" && family == "kimi_audio") { return tokenizer_backend_kimi_audio() }
    tokenizer_backend_hf()
}

func renderer_for_family(string family) int {
    if family == "mistral" { return renderer_backend_mistral() }
    if family == "cohere" { return renderer_backend_cohere() }
    if family == "deepseek_v32" || family == "deepseek_v4" { return renderer_backend_deepseek() }
    if family == "inkling" { return renderer_backend_inkling() }
    if family == "kimi_k3" || family == "kimi_audio" { return renderer_backend_kimi() }
    renderer_backend_hf()
}

func select_tokenizer_renderer(tokenizer_renderer_request request) tokenizer_renderer_selection {
    if request.runner_type != "generate" && request.runner_type != "draft" && request.runner_type != "pooling" { return tokenizer_renderer_selection {tokenizer_backend: 0, renderer_backend: 0, truncation_side: 0, tokenizer_available: false, supported: false, error_code: 1} }
    if request.tokenizer_mode == "slow" && request.use_fast { return tokenizer_renderer_selection {tokenizer_backend: 0, renderer_backend: 0, truncation_side: 0, tokenizer_available: false, supported: false, error_code: 2} }
    int truncation = tokenizer_truncate_left()
    if request.runner_type == "pooling" { truncation = tokenizer_truncate_right() }
    tokenizer_renderer_selection {
        tokenizer_backend: tokenizer_mode_backend(request.tokenizer_mode, request.model_family),
        renderer_backend: renderer_for_family(request.model_family),
        truncation_side: truncation,
        tokenizer_available: !request.skip_tokenizer_init,
        supported: true,
        error_code: 0,
    }
}
