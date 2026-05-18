package neurx.app.backend

use neurx.platform.config.{parse_optional_int}
use neurx.model.llm.gpt_large.{gpt_large_state, new_gpt_large_state, gpt_large_summary, gpt_large_next_token}
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_read_text_file}

struct llm_backend_request_state {
    string model_name
    string prompt
    int max_tokens
    string request_source
}

struct llm_backend_response_state {
    string backend_name
    string model_name
    string prompt
    string summary
    string completion
    string token_trace
    int generated_tokens
    int last_token
    float train_loss
    float validation_loss
    bool ready
}

func json_escape(string text) string {
    int n = len(text)
    string out = ""
    int i = 0
    while i < n {
        string ch = text[i]
        if ch == "\\" {
            out = out + "\\\\"
        } else if ch == "\"" {
            out = out + "\\\""
        } else if ch == "\n" {
            out = out + "\\n"
        } else if ch == "\r" {
            out = out + "\\r"
        } else if ch == "\t" {
            out = out + "\\t"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out
}

func default_prompt() string {
    "Explain NeurX LLM backend in one short paragraph."
}

func backend_request_state() llm_backend_request_state {
    string model_name = runtime_env_get("NEURX_BACKEND_MODEL", "gpt_large")
    string prompt = runtime_env_get("NEURX_BACKEND_PROMPT", "")
    string request_source = "env"

    string request_file = runtime_env_get("NEURX_BACKEND_REQUEST_FILE", "")
    if request_file != "" && runtime_file_exists(request_file) {
        prompt = runtime_read_text_file(request_file)
        request_source = "file"
    }

    if prompt == "" {
        prompt = default_prompt()
    }

    int max_tokens = 16
    string max_tokens_text = runtime_env_get("NEURX_BACKEND_MAX_TOKENS", "16")
    if max_tokens_text != "" {
        int_parse_result max_tokens_out = parse_optional_int("NEURX_BACKEND_MAX_TOKENS", max_tokens_text)
        if max_tokens_out.ok && max_tokens_out.has_value {
            max_tokens = max_tokens_out.value
        }
    }
    if max_tokens < 1 {
        max_tokens = 1
    }
    if max_tokens > 64 {
        max_tokens = 64
    }

    llm_backend_request_state {
        model_name: model_name,
        prompt: prompt,
        max_tokens: max_tokens,
        request_source: request_source,
    }
}

func build_token_trace(gpt_large_state model, string prompt, int max_tokens) string {
    int seed = len(prompt) + model.num_layers + model.num_heads
    int token = seed
    string trace = ""
    int generated = 0
    while generated < max_tokens {
        token = gpt_large_next_token(model, token, generated)
        if generated > 0 {
            trace = trace + ","
        }
        trace = trace + string(token)
        generated = generated + 1
    }
    trace
}

func build_last_token(gpt_large_state model, string prompt, int max_tokens) int {
    int seed = len(prompt) + model.num_layers + model.num_heads
    int token = seed
    int generated = 0
    while generated < max_tokens {
        token = gpt_large_next_token(model, token, generated)
        generated = generated + 1
    }
    token
}

func build_completion(gpt_large_state model, llm_backend_request_state request, string token_trace) string {
    string completion = "NeurX S backend is serving the local GPT-large scaffold."
    completion = completion + " model=" + request.model_name
    completion = completion + " summary=" + gpt_large_summary(model)
    completion = completion + " prompt_len=" + string(len(request.prompt))
    completion = completion + " source=" + request.request_source
    if token_trace != "" {
        completion = completion + " token_trace=" + token_trace
    }
    completion
}

func run_llm_backend(llm_backend_request_state request) llm_backend_response_state {
    gpt_large_state model = new_gpt_large_state()
    string token_trace = build_token_trace(model, request.prompt, request.max_tokens)
    string completion = build_completion(model, request, token_trace)

    llm_backend_response_state {
        backend_name: "neurx.app.backend.llm",
        model_name: request.model_name,
        prompt: request.prompt,
        summary: gpt_large_summary(model),
        completion: completion,
        token_trace: token_trace,
        generated_tokens: request.max_tokens,
        last_token: build_last_token(model, request.prompt, request.max_tokens),
        train_loss: model.train_loss,
        validation_loss: model.validation_loss,
        ready: true,
    }
}

func response_to_json(llm_backend_response_state response) string {
    string out = "{"
    out = out + "\"backend_name\":\"" + json_escape(response.backend_name) + "\""
    out = out + ",\"model_name\":\"" + json_escape(response.model_name) + "\""
    out = out + ",\"summary\":\"" + json_escape(response.summary) + "\""
    out = out + ",\"prompt\":\"" + json_escape(response.prompt) + "\""
    out = out + ",\"completion\":\"" + json_escape(response.completion) + "\""
    out = out + ",\"token_trace\":\"" + json_escape(response.token_trace) + "\""
    out = out + ",\"generated_tokens\":" + string(response.generated_tokens)
    out = out + ",\"last_token\":" + string(response.last_token)
    out = out + ",\"train_loss\":" + string(response.train_loss)
    out = out + ",\"validation_loss\":" + string(response.validation_loss)
    out = out + ",\"ready\":" + string(response.ready)
    out = out + "}"
    out
}

func main() int {
    llm_backend_request_state request = backend_request_state()
    llm_backend_response_state response = run_llm_backend(request)

    println(response_to_json(response))
    0
}
