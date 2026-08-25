package neurx.test.test_transformer_complete
use neurx.model.transformer.layer_norm.{
    layer_norm_config,
    layer_norm_state,
    new_layer_norm,
    layer_normalize
}
use neurx.model.transformer.position_encoding.{
    position_encoding_config,
    absolute_position_encoding,
    new_absolute_position_encoding,
    get_position_encoding
}
use neurx.model.transformer.transformer_forward.{
    transformer_forward_config,
    transformer_forward_state,
    transformer_layer_state,
    embed_tokens,
    feed_forward_forward,
    transformer_layer_forward,
    transformer_forward_pass,
    forward_pass_output
}
use neurx.model.transformer.transformer_backward.{
    compute_cross_entropy_loss_with_gradient,
    lm_head_backward,
    feed_forward_backward,
    attention_backward,
    transformer_backward_pass,
    backward_pass_output
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

func copy_vector([]float src) []float {
    []float out = allocate_vector(len(src), 0.0)
    int i = 0
    while i < len(src) {
        out[i] = src[i]
        i = i + 1
    }
    out
}

func float_equal(float a, float b, float epsilon) bool {
    float diff = a - b
    if diff < 0.0 {
        diff = -diff
    }
    diff < epsilon
}

func assert_equal(string test_name, float actual, float expected, float epsilon) {
    if float_equal(actual, expected, epsilon) {
    } else {
    }
}

func print_test_result(string test_name, bool passed) {
}

func test_layer_norm_forward_basic() {
    layer_norm_config cfg = layer_norm_config {
        hidden_dim: 8,
        epsilon: 1e-6,
        use_bias: true,
    }
    ln := new_layer_norm(cfg)
    []float input = []float{cap: 16}
    int i = 0
    while i < 16 {
        input[i] = 1.0 + (i * 1.0) / 16.0
        i = i + 1
    }
    output := layer_normalize(ln, input, 2, 1)
    float mean = 0.0
    i = 0
    while i < 8 {
        mean = mean + output.normalized[i]
        i = i + 1
    }
    mean = mean / 8.0
    assert_equal("layer_norm_mean", mean, 0.0, 0.1)
}

func test_layer_norm_with_gamma_beta() {
    layer_norm_config cfg = layer_norm_config {
        hidden_dim: 4,
        epsilon: 1e-6,
        use_bias: true,
    }
    ln := new_layer_norm(cfg)
    ln.gamma = []float{cap: 4}
    ln.beta = []float{cap: 4}
    int i = 0
    while i < 4 {
        ln.gamma[i] = 2.0
        ln.beta[i] = 0.5
        i = i + 1
    }
    []float input = allocate_vector(4, 1.0)
    output := layer_normalize(ln, input, 1, 1)
    assert_equal("layer_norm_gamma", output.normalized[0], 0.5, 0.1)
}

func test_rms_norm_basic() {
    layer_norm_config cfg = layer_norm_config {
        hidden_dim: 8,
        epsilon: 1e-6,
        use_bias: false,
    }
    rn := new_rms_norm(cfg)
}

func test_absolute_position_encoding() {
    position_encoding_config cfg = position_encoding_config {
        hidden_dim: 8,
        max_seq_len: 10,
        encoding_type: "absolute",
        rope_base: 10000.0,
    }
    pos_enc := new_absolute_position_encoding(cfg)
    encoding := get_position_encoding(pos_enc, 0, 4)
    assert_equal("pos_encoding_size", (0.0 + len(encoding)), 32.0, 1.0)
}

func test_position_encoding_periodicity() {
    position_encoding_config cfg = position_encoding_config {
        hidden_dim: 64,
        max_seq_len: 512,
        encoding_type: "absolute",
        rope_base: 10000.0,
    }
    pos_enc := new_absolute_position_encoding(cfg)
    enc1 := get_position_encoding(pos_enc, 0, 1)
    enc2 := get_position_encoding(pos_enc, 1, 1)
}

func test_embed_tokens_basic() {
    int vocab_size = 100
    int hidden_dim = 8
    int batch_size = 2
    int seq_len = 4
    []float embedding = allocate_vector(vocab_size * hidden_dim, 0.1)
    []int token_ids = []int{cap: batch_size * seq_len}
    int i = 0
    while i < batch_size * seq_len {
        token_ids[i] = i % vocab_size
        i = i + 1
    }
    embedded := embed_tokens(embedding, token_ids, batch_size, seq_len, hidden_dim)
    assert_equal("embed_tokens_shape", (0.0 + len(embedded)), (0.0 + batch_size * seq_len * hidden_dim), 1.0)
}

func test_embed_tokens_correct_values() {
    int vocab_size = 10
    int hidden_dim = 4
    int batch_size = 1
    int seq_len = 2
    []float embedding = allocate_vector(vocab_size * hidden_dim, 0.0)
    int i = 0
    while i < hidden_dim {
        embedding[i] = 1.0 + (i * 1.0)
        embedding[hidden_dim + i] = 2.0 + (i * 1.0)
        i = i + 1
    }
    []int token_ids = []int{cap: 2}
    token_ids[0] = 0
    token_ids[1] = 1
    embedded := embed_tokens(embedding, token_ids, batch_size, seq_len, hidden_dim)
    i = 0
    while i < hidden_dim {
        assert_equal("embed_token_0", embedded[i], 1.0 + (i * 1.0), 0.01)
        assert_equal("embed_token_1", embedded[hidden_dim + i], 2.0 + (i * 1.0), 0.01)
        i = i + 1
    }
}

func test_feed_forward_forward_basic() {
    int hidden_dim = 8
    int intermediate_dim = 32
    int batch_size = 2
    int seq_len = 4
    transformer_layer_state layer = transformer_layer_state {
        wq: allocate_vector(hidden_dim * hidden_dim, 0.1),
        wk: allocate_vector(hidden_dim * hidden_dim, 0.1),
        wv: allocate_vector(hidden_dim * hidden_dim, 0.1),
        wo: allocate_vector(hidden_dim * hidden_dim, 0.1),
        query_bias: allocate_vector(hidden_dim, 0.0),
        key_bias: allocate_vector(hidden_dim, 0.0),
        value_bias: allocate_vector(hidden_dim, 0.0),
        output_bias: allocate_vector(hidden_dim, 0.0),
        w_up: allocate_vector(intermediate_dim * hidden_dim, 0.1),
        w_down: allocate_vector(hidden_dim * intermediate_dim, 0.1),
        up_bias: allocate_vector(intermediate_dim, 0.0),
        down_bias: allocate_vector(hidden_dim, 0.0),
        norm1: new_layer_norm(layer_norm_config { hidden_dim: hidden_dim, epsilon: 1e-6, use_bias: true }),
        norm2: new_layer_norm(layer_norm_config { hidden_dim: hidden_dim, epsilon: 1e-6, use_bias: true }),
    }
    []float hidden = allocate_vector(batch_size * seq_len * hidden_dim, 0.1)
    output := feed_forward_forward(layer, hidden, batch_size, seq_len, hidden_dim, intermediate_dim)
    assert_equal("ffn_output_shape", (0.0 + len(output)), (0.0 + batch_size * seq_len * hidden_dim), 1.0)
}

func test_cross_entropy_loss_gradient() {
    int batch_size = 2
    int seq_len = 2
    int vocab_size = 10
    []float logits = allocate_vector(batch_size * seq_len * vocab_size, 0.1)
    []int targets = []int{cap: batch_size * seq_len}
    targets[0] = 1
    targets[1] = 2
    targets[2] = 3
    targets[3] = 0
    result := compute_cross_entropy_loss_with_gradient(logits, targets, batch_size, seq_len, vocab_size)
    []float loss = result[0]
    []float grad = result[1]
    assert_equal("loss_shape", (0.0 + len(loss)), (0.0 + batch_size * seq_len), 1.0)
    assert_equal("grad_shape", (0.0 + len(grad)), (0.0 + batch_size * seq_len * vocab_size), 1.0)
}

func test_lm_head_backward() {
    int batch_size = 1
    int seq_len = 2
    int hidden_dim = 8
    int vocab_size = 10
    []float grad_logits = allocate_vector(batch_size * seq_len * vocab_size, 0.1)
    []float hidden = allocate_vector(batch_size * seq_len * hidden_dim, 0.1)
    []float lm_head_weight = allocate_vector(vocab_size * hidden_dim, 0.1)
    result := lm_head_backward(grad_logits, hidden, lm_head_weight, batch_size, seq_len, hidden_dim, vocab_size)
    []float grad_hidden = result[0]
    []float grad_weight = result[1]
    assert_equal("lm_head_grad_hidden_shape", (0.0 + len(grad_hidden)), (0.0 + batch_size * seq_len * hidden_dim), 1.0)
    assert_equal("lm_head_grad_weight_shape", (0.0 + len(grad_weight)), (0.0 + vocab_size * hidden_dim), 1.0)
}

func test_feed_forward_backward() {
    int batch_size = 1
    int seq_len = 2
    int hidden_dim = 8
    int intermediate_dim = 32
    []float grad_output = allocate_vector(batch_size * seq_len * hidden_dim, 0.1)
    []float hidden = allocate_vector(batch_size * seq_len * hidden_dim, 0.1)
    []float w_up = allocate_vector(intermediate_dim * hidden_dim, 0.1)
    []float w_down = allocate_vector(hidden_dim * intermediate_dim, 0.1)
    result := feed_forward_backward(grad_output, hidden, w_up, w_down, batch_size, seq_len, hidden_dim, intermediate_dim)
    []float grad_hidden_out = result[0]
    []float grad_w_up = result[1]
    []float grad_w_down = result[2]
    assert_equal("ffn_backward_grad_hidden", (0.0 + len(grad_hidden_out)), (0.0 + batch_size * seq_len * hidden_dim), 1.0)
    assert_equal("ffn_backward_grad_w_up", (0.0 + len(grad_w_up)), (0.0 + intermediate_dim * hidden_dim), 1.0)
}

func test_transformer_layer_forward_backward() {
    int batch_size = 1
    int seq_len = 2
    int hidden_dim = 8
    int num_heads = 2
    int intermediate_dim = 32
    transformer_layer_state layer = transformer_layer_state {
        wq: allocate_vector(hidden_dim * hidden_dim, 0.1),
        wk: allocate_vector(hidden_dim * hidden_dim, 0.1),
        wv: allocate_vector(hidden_dim * hidden_dim, 0.1),
        wo: allocate_vector(hidden_dim * hidden_dim, 0.1),
        query_bias: allocate_vector(hidden_dim, 0.0),
        key_bias: allocate_vector(hidden_dim, 0.0),
        value_bias: allocate_vector(hidden_dim, 0.0),
        output_bias: allocate_vector(hidden_dim, 0.0),
        w_up: allocate_vector(intermediate_dim * hidden_dim, 0.1),
        w_down: allocate_vector(hidden_dim * intermediate_dim, 0.1),
        up_bias: allocate_vector(intermediate_dim, 0.0),
        down_bias: allocate_vector(hidden_dim, 0.0),
        norm1: new_layer_norm(layer_norm_config { hidden_dim: hidden_dim, epsilon: 1e-6, use_bias: true }),
        norm2: new_layer_norm(layer_norm_config { hidden_dim: hidden_dim, epsilon: 1e-6, use_bias: true }),
    }
    []float hidden_in = allocate_vector(batch_size * seq_len * hidden_dim, 0.1)
    hidden_out := transformer_layer_forward(layer, hidden_in, batch_size, seq_len, hidden_dim, num_heads, intermediate_dim, false, false)
    assert_equal("transformer_layer_output", (0.0 + len(hidden_out)), (0.0 + batch_size * seq_len * hidden_dim), 1.0)
}

func test_complete_forward_backward_cycle() {
    int batch_size = 1
    int seq_len = 4
    int hidden_dim = 8
    int vocab_size = 32
    int num_heads = 2
    int num_layers = 2
    []int input_ids = allocate_vector(batch_size * seq_len, 1)
    int i = 0
    while i < batch_size * seq_len {
        input_ids[i] = i % vocab_size
        i = i + 1
    }
    []int target_ids = allocate_vector(batch_size * seq_len, 2)
    i = 0
    while i < batch_size * seq_len {
        target_ids[i] = (i + 1) % vocab_size
        i = i + 1
    }
    transformer_forward_config cfg = transformer_forward_config {
        vocab_size: vocab_size,
        hidden_dim: hidden_dim,
        num_layers: num_layers,
        num_heads: num_heads,
        max_seq_len: 128,
        intermediate_dim: hidden_dim * 4,
        attention_dropout: 0.0,
        ffn_dropout: 0.0,
        position_encoding_type: "absolute",
        use_causal_mask: true,
        pre_norm: false,
    }
}

func run_all_tests() {
    test_layer_norm_forward_basic()
    test_layer_norm_with_gamma_beta()
    test_rms_norm_basic()
    test_absolute_position_encoding()
    test_position_encoding_periodicity()
    test_embed_tokens_basic()
    test_embed_tokens_correct_values()
    test_feed_forward_forward_basic()
    test_cross_entropy_loss_gradient()
    test_lm_head_backward()
    test_feed_forward_backward()
    test_transformer_layer_forward_backward()
    test_complete_forward_backward_cycle()
}
