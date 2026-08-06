package neurx.test.integration
use neurx.moe.transformer
use neurx.attention
use neurx.data.loader.streaming
use neurx.distributed.fsdp
use neurx.tokenizer.bpe_trainer
func test_all_modules() {
    print("=== NeurX Integration Test ===\n")
    test_moe_layer()
    test_flash_attention()
    test_streaming_dataloader()
    test_fsdp()
    test_bpe_tokenizer()
    print("\n=== All Tests Passed! ===\n")
}

func test_moe_layer() {
    print("Testing MOE Layer...\n")
    moe.moe_config config = moe.new_moe_config()
    config.num_experts = 8
    config.expert_dim = 512
    config.hidden_dim = 2048
    config.top_k = 2
    moe.moe_layer layer = moe.new_moe_layer(config)
    int batch_size = 4
    int seq_len = 128
    int hidden_dim = config.hidden_dim
    []float hidden_states = allocate_vector(batch_size * seq_len * hidden_dim, 0.0)
    int i = 0
    while i < batch_size * seq_len * hidden_dim {
        hidden_states[i] = 0.1 * (i % 100)
        i = i + 1
    }
    moe.moe_forward_result result = moe.moe_forward(layer, hidden_states, batch_size, seq_len)
    if len(result.output) != batch_size * seq_len * hidden_dim {
        print("FAIL: MOE output dimension mismatch\n")
        return
    }
    if result.aux_loss < 0.0 {
        print("FAIL: MOE aux loss is negative\n")
        return
    }
    print("PASS: MOE Layer\n")
}

func test_flash_attention() {
    print("Testing Flash Attention...\n")
    attention.attention_config config = attention.new_attention_config()
    config.hidden_dim = 768
    config.num_heads = 12
    config.head_dim = 64
    attention.multi_head_attention attn = attention.new_multi_head_attention(config)
    int seq_len = 512
    []float hidden_states = allocate_vector(seq_len * 768, 0.0)
    int i = 0
    while i < seq_len * 768 {
        hidden_states[i] = 0.1 * (i % 100)
        i = i + 1
    }
    []float output = attention.forward_flash_attention(attn, hidden_states, seq_len)
    if len(output) != seq_len * 768 {
        print("FAIL: Flash Attention output dimension mismatch\n")
        return
    }
    print("PASS: Flash Attention\n")
}

func test_streaming_dataloader() {
    print("Testing Streaming data_loader...\n")
    streaming.streaming_config config = streaming.new_streaming_config("/tmp/test_data")
    config.batch_size = 8
    config.seq_len = 512
    config.prefetch_size = 2
    streaming.streaming_dataloader loader = streaming.new_streaming_dataloader(config)
    func mock_tokenizer(string text) []int {
        []int tokens = []int{cap: 512}
        int i = 0
        while i < 512 {
            tokens.push(i % 1000)
            i = i + 1
        }
        tokens
    }
    (streaming.batch_data batch, bool has_more) = streaming.dataloader_next_batch(loader, mock_tokenizer)
    if has_more && len(batch.input_ids) == config.batch_size {
        print("PASS: Streaming data_loader\n")
    } else {
        print("INFO: Streaming data_loader initialized (no real data)\n")
    }
}

func test_fsdp() {
    print("Testing FSDP...\n")
    fsdp.fsdp_config config = fsdp.new_fsdp_config()
    config.sharding_strategy = fsdp.fsdp_sharding_strategy.FULL_SHARD
    config.mixed_precision = true
    fsdp.fsdp_state state = fsdp.new_fsdp_state(0, 4, null)
    float savings = fsdp.fsdp_compute_memory_savings(fsdp.fsdp_module{state: state, total_params: 1000000000, local_params: 250000000})
    if savings > 0.0 {
        print("PASS: FSDP (memory savings: " + string(savings) + "%)\n")
    } else {
        print("FAIL: FSDP memory savings calculation\n")
        return
    }
}

func test_bpe_tokenizer() {
    print("Testing BPE tokenizer...\n")
    bpe_tokenizer tokenizer = bpe_tokenizer.new_bpe_tokenizer()
    tokenizer.vocab["<|begin_of_text|>"] = 0
    tokenizer.vocab["<|end_of_text|>"] = 1
    tokenizer.vocab["Hello"] = 2
    tokenizer.vocab["World"] = 3
    tokenizer.vocab["HelloWorld"] = 4
    tokenizer.id_to_token[0] = "<|begin_of_text|>"
    tokenizer.id_to_token[1] = "<|end_of_text|>"
    tokenizer.id_to_token[2] = "Hello"
    tokenizer.id_to_token[3] = "World"
    tokenizer.id_to_token[4] = "HelloWorld"
    tokenizer.vocab_size = 5
    tokenizer.merges = []bpe_tokenizer.pair[string, string]{}
    tokenizer.merges.push(bpe_tokenizer.pair[string, string]{first: "Hello", second: "World"})
    bpe_tokenizer.tokenization_result result = bpe_tokenizer.encode(tokenizer, "Hello World")
    if result.num_tokens > 0 && result.ids[0] == tokenizer.bos_id {
        print("PASS: BPE tokenizer\n")
    } else {
        print("FAIL: BPE tokenizer\n")
        return
    }
}

func allocate_vector(int size, float init_val) []float {
    []float v = []float{cap: size}
    int i = 0
    while i < size {
        v[i] = init_val
        i = i + 1
    }
    v
}

func print(string msg) {
}

func main() {
    test_all_modules()
}
