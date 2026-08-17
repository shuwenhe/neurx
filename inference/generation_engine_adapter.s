package neurx.inference.generation_engine_adapter
use neurx.attention.paged_attention_core.{
    paged_attention_config,
    paged_kv_cache,
    slot_mapping,
    new_paged_kv_cache,
    reserve_tokens,
}
use neurx.inference.real_transformer_layer.{
    transformer_layer_config,
    transformer_layer_weights,
    default_layer_config,
    make_identity_weights,
    transformer_layer_forward,
}
use neurx.tokenizer.real_bpe_tokenizer.{
    real_bpe_tokenizer,
    new_real_bpe_tokenizer,
    encode,
    decode,
}
use neurx.inference.api.sse_server.generation_callback_state
use neurx.inference.real_sampling.{
    sampling_params,
    rng_state,
    new_sampling_params,
    new_rng,
    sample,
    greedy_sample,
}
use neurx.inference.safetensors_weight_loader.{
    safetensors_header,
    load_safetensors_header,
    load_tensor_floats,
    has_tensor,
}

struct generation_engine {
    transformer_layer_config layer_config
    transformer_layer_weights weights
    real_bpe_tokenizer tokenizer
    paged_kv_cache cache
    []slot_mapping slots
    int hidden_size
    int num_layers
    float[] embedding_table
    float[] lm_head
    sampling_params sampling
    rng_state rng
}

struct generation_result {
    []int token_ids
    []string token_strings
    int num_generated
}

func new_generation_engine(int num_layers) generation_engine {
    transformer_layer_config cfg = default_layer_config()
    transformer_layer_weights w = make_identity_weights(cfg)
    real_bpe_tokenizer tok = new_real_bpe_tokenizer()
    paged_attention_config pacfg = paged_attention_config{
        block_size: cfg.block_size,
        num_kv_heads: cfg.num_kv_heads,
        head_size: cfg.head_size,
        max_blocks: cfg.max_blocks,
        scale: 1.0,
    }
    paged_kv_cache cache = new_paged_kv_cache(pacfg)
    int hidden = cfg.hidden_size
    int vocab = tok.vocab_size
    float[] emb = make([]float, vocab * hidden)
    int i = 0
    while i < vocab && i < hidden {
        emb[i * hidden + i] = 1.0
        i = i + 1
    }
    float[] head = make([]float, hidden * vocab)
    int j = 0
    while j < hidden && j < vocab {
        head[j * vocab + j] = 1.0
        j = j + 1
    }
    generation_engine{
        layer_config: cfg,
        weights: w,
        tokenizer: tok,
        cache: cache,
        slots: []slot_mapping{},
        hidden_size: hidden,
        num_layers: num_layers,
        embedding_table: emb,
        lm_head: head,
        sampling: new_sampling_params(1.0, 0, 1.0, 42),
        rng: new_rng(42),
    }
}

func embed_token(generation_engine engine, int token_id) []float {
    []float hidden = make([]float, engine.hidden_size)
    if token_id < 0 || token_id >= engine.tokenizer.vocab_size {
        return hidden
    }
    int base = token_id * engine.hidden_size
    int i = 0
    while i < engine.hidden_size {
        if base + i < len(engine.embedding_table) {
            hidden[i] = engine.embedding_table[base + i]
        }
        i = i + 1
    }
    hidden
}

func argmax_logits([]float logits, int vocab_size) int {
    if vocab_size == 0 {
        return 0
    }
    float best = logits[0]
    int best_idx = 0
    int i = 1
    while i < vocab_size {
        if logits[i] > best {
            best = logits[i]
            best_idx = i
        }
        i = i + 1
    }
    best_idx
}

func compute_logits([]float hidden, float[] lm_head, int hidden_size, int vocab_size) []float {
    []float logits = make([]float, vocab_size)
    int v = 0
    while v < vocab_size {
        float acc = 0.0
        int h = 0
        while h < hidden_size {
            acc = acc + hidden[h] * lm_head[h * vocab_size + v]
            h = h + 1
        }
        logits[v] = acc
        v = v + 1
    }
    logits
}

func run_layer_stack(generation_engine engine, []float hidden, int position) ([]float, paged_kv_cache) {
    paged_kv_cache cache = engine.cache
    []float current = hidden
    int layer = 0
    while layer < engine.num_layers {
        ([]float out, paged_kv_cache c) = transformer_layer_forward(current, engine.weights, engine.layer_config, cache, engine.slots, position)
        current = out
        cache = c
        layer = layer + 1
    }
    engine.cache = cache
    current
}

func generate(generation_engine engine, string prompt, int max_new_tokens) generation_result {
    []int prompt_ids = encode(engine.tokenizer, prompt)
    engine.cache = reserve_tokens(engine.cache, len(prompt_ids) + max_new_tokens)
    []slot_mapping slots = []slot_mapping{}
    int t = 0
    while t < len(prompt_ids) + max_new_tokens {
        int block_id = t / engine.layer_config.block_size
        int offset = t - (t / engine.layer_config.block_size) * engine.layer_config.block_size
        slots = append(slots, slot_mapping{block_id: block_id, offset_in_block: offset})
        t = t + 1
    }
    engine.slots = slots
    []float hidden
    int position = 0
    while position < len(prompt_ids) {
        hidden = embed_token(engine, prompt_ids[position])
        hidden = run_layer_stack(engine, hidden, position)
        position = position + 1
    }
    []int generated = []int{}
    []string token_strings = []string{}
    rng_state rng = engine.rng
    int step = 0
    while step < max_new_tokens {
        if len(hidden) == 0 {
            hidden = embed_token(engine, engine.tokenizer.eos_id)
        }
        []float logits = compute_logits(hidden, engine.lm_head, engine.hidden_size, engine.tokenizer.vocab_size)
        int next_id
        (next_id, rng) = sample(logits, engine.tokenizer.vocab_size, engine.sampling, rng)
        generated = append(generated, next_id)
        if map_has_int(engine.tokenizer.id_to_token, next_id) {
            token_strings = append(token_strings, engine.tokenizer.id_to_token[next_id])
        } else {
            token_strings = append(token_strings, engine.tokenizer.unk_token)
        }
        if next_id == engine.tokenizer.eos_id {
            break
        }
        hidden = embed_token(engine, next_id)
        hidden = run_layer_stack(engine, hidden, position)
        position = position + 1
        step = step + 1
    }
    engine.rng = rng
    generation_result{token_ids: generated, token_strings: token_strings, num_generated: len(generated)}
}

func map_has_int(map[int]string m, int key) bool {
    string v = m[key]
    v != ""
}

func engine_to_callback_state(generation_result result) generation_callback_state {
    []string toks = result.token_strings
    generation_callback_state state
    state.tokens = toks
    state.cursor = 0
    state.done = false
    state
}

func generate_stream(generation_engine engine, string prompt, int max_new_tokens) generation_callback_state {
    generation_result result = generate(engine, prompt, max_new_tokens)
    engine_to_callback_state(result)
}

func decode_ids(generation_engine engine, []int ids) string {
    decode(engine.tokenizer, ids)
}

func generate_with_sampling(generation_engine engine, string prompt, int max_new_tokens, sampling_params params) generation_result {
    engine.sampling = params
    generate(engine, prompt, max_new_tokens)
}

func generate_greedy(generation_engine engine, string prompt, int max_new_tokens) generation_result {
    engine.sampling = new_sampling_params(1.0, 0, 1.0, 0)
    engine.sampling.greedy = true
    generate(engine, prompt, max_new_tokens)
}

func load_weights_from_safetensors(generation_engine engine, string path) bool {
    safetensors_header hdr = load_safetensors_header(path)
    if !hdr.valid {
        return false
    }
    if has_tensor(hdr, "embedding.weight") {
        engine.embedding_table = load_tensor_floats(hdr, "embedding.weight")
    }
    if has_tensor(hdr, "lm_head.weight") {
        engine.lm_head = load_tensor_floats(hdr, "lm_head.weight")
    }
    string layer_prefix = "layers.0."
    if has_tensor(hdr, layer_prefix + "input_norm.weight") {
        engine.weights.input_norm_weight = load_tensor_floats(hdr, layer_prefix + "input_norm.weight")
    }
    if has_tensor(hdr, layer_prefix + "post_attention_norm.weight") {
        engine.weights.post_attention_norm_weight = load_tensor_floats(hdr, layer_prefix + "post_attention_norm.weight")
    }
    if has_tensor(hdr, layer_prefix + "w_q.weight") {
        engine.weights.w_q = load_tensor_floats(hdr, layer_prefix + "w_q.weight")
    }
    if has_tensor(hdr, layer_prefix + "w_k.weight") {
        engine.weights.w_k = load_tensor_floats(hdr, layer_prefix + "w_k.weight")
    }
    if has_tensor(hdr, layer_prefix + "w_v.weight") {
        engine.weights.w_v = load_tensor_floats(hdr, layer_prefix + "w_v.weight")
    }
    if has_tensor(hdr, layer_prefix + "w_o.weight") {
        engine.weights.w_o = load_tensor_floats(hdr, layer_prefix + "w_o.weight")
    }
    if has_tensor(hdr, layer_prefix + "gate_proj.weight") {
        engine.weights.gate_proj_weight = load_tensor_floats(hdr, layer_prefix + "gate_proj.weight")
    }
    if has_tensor(hdr, layer_prefix + "up_proj.weight") {
        engine.weights.up_proj_weight = load_tensor_floats(hdr, layer_prefix + "up_proj.weight")
    }
    if has_tensor(hdr, layer_prefix + "down_proj.weight") {
        engine.weights.down_proj_weight = load_tensor_floats(hdr, layer_prefix + "down_proj.weight")
    }
    true
}
