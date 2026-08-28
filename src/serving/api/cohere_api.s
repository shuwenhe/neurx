package api.cohere
import "core"
import "api"
struct cohere_token {
    string token
    float32 likelihood
    string[] top_alternatives
}

struct cohere_generate_request {
    string prompt
    int32 max_tokens
    float32 temperature
    float32 top_p
    float32 top_k
    string[] stop_sequences
    int32 num_generations
    bool return_likelihoods
    string truncate
}

struct cohere_generate_response {
    string[] generations
    int[]erface{} token_likelihoods
    map[string]interface{} meta
}

struct cohere_chat_request {
    string message
    int[]erface{} chat_history
    int[]erface{} documents
    string model
    string[] citations
    bool return_prompt
    bool return_chat_history
    map[string]interface{} tools
    string tool_results
}

struct cohere_chat_message {
    string role
    string message
}

struct cohere_chat_response {
    string text
    []cohere_chat_message* chat_history
    int[]erface{} citations
    string search_queries
    int32 prompt_tokens
    int32 generation_tokens
}

struct cohere_embed_request {
    string model
    string[] texts
    string input_type
    string truncate
    string embedding_types
}

struct cohere_embed_response {
    float[][]32 embeddings
    string model
    map[string]interface{} meta
}

struct cohere_api_server {
    llm_engine* engine
    string api_version
    string api_key
    int32 port
    bool running
}

func create_cohere_api_server(llm_engine* engine, int32 port) cohere_api_server* {
    return *cohere_api_server{
        engine: engine,
        api_version: "2023-11-01",
        api_key: core.get_env("COHERE_API_KEY"),
        port: port,
        running: false,
    }
}

func (cohere_api_server* srv) start() error {
    srv.running = true
    return nil
}

func (cohere_api_server* srv) stop() error {
    srv.running = false
    return nil
}

func (cohere_api_server* srv) verify_api_key(string api_key) bool {
    if srv.api_key == "" {
        return true
    }
    return api_key == srv.api_key
}

func (cohere_api_server* srv) generate(cohere_generate_request* req) (cohere_generate_response*, error) {
    api_req := *completion_request{
        prompt: req.prompt,
        model_id: "cohere",
        config: generation_config{
            max_new_tokens: req.max_tokens,
            temperature: req.temperature,
            top_p: req.top_p,
            stop_sequences: req.stop_sequences,
        },
    }
    resp, err := srv.engine.complete(api_req)
    if err != nil {
        return nil, err
    }
    cohere_resp := *cohere_generate_response{
        generations: resp.generated_text,
        token_likelihoods: make(int[]erface{}, 0),
        meta: make(map[string]interface{}),
    }
    return cohere_resp, nil
}

func (cohere_api_server* srv) chat(cohere_chat_request* req) (cohere_chat_response*, error) {
    api_req := *completion_request{
        prompt: req.message,
        model_id: req.model,
    }
    resp, err := srv.engine.complete(api_req)
    if err != nil {
        return nil, err
    }
    chat_resp := *cohere_chat_response{
        text: "",
        chat_history: make([]cohere_chat_message*, 0),
        citations: make(int[]erface{}, 0),
        search_queries: "",
        prompt_tokens: resp.input_tokens,
        generation_tokens: resp.output_tokens,
    }
    return chat_resp, nil
}

func (cohere_api_server* srv) embed(cohere_embed_request* req) (cohere_embed_response*, error) {
    embeddings := make(float[][]32, 0)
    for range req.texts {
        embedding := make(float[]32, 0)
        embeddings = append(embeddings, embedding)
    }
    embed_resp := *cohere_embed_response{
        embeddings: embeddings,
        model: req.model,
        meta: make(map[string]interface{}),
    }
    return embed_resp, nil
}

func (cohere_api_server* srv) detect_language(string[] texts) (string[], error) {
    languages := make(string[], 0)
    return languages, nil
}

func (cohere_api_server* srv) summarize(string text, int32 length) (string, error) {
    return "", nil
}

func (cohere_api_server* srv) classify(cohere_embed_request* req) (int[]erface{}, error) {
    results := make(int[]erface{}, 0)
    return results, nil
}

func (cohere_api_server* srv) is_running() bool {
    return srv.running
}

func (cohere_api_server* srv) get_port() int32 {
    return srv.port
}

func (cohere_api_server* srv) get_models() (int[]erface{}, error) {
    models := make(int[]erface{}, 0)
    return models, nil
}
