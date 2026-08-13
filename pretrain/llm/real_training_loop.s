package neurx.pretrain.llm.real_training_loop
use neurx.pretrain.llm.real_training.{
    relu, relu_backward, softmax_last_dim, cross_entropy_loss,
    matmul, transpose, sum_first_dim,
    adamw_update, grad_logits,
    print_training_progress, int_to_str, fmt_float
}
use neurx.pretrain.llm.gpt_large_pretrain.{gpt_large_pretrain_manifest_refs}
use neurx.data.dataset.corpus_loader.{corpus_state, corpus_batch_result, new_corpus_state_from_paths, corpus_next_batch}
use neurx.tensor.tensor
use neurx.tensor.new
use neurx.strings

struct real_training_state {
    tensor weights_q
    tensor weights_k
    tensor weights_v
    tensor weights_out
    tensor embedding
    tensor lm_head
    []float adam_m
    []float adam_v
    float learning_rate
    int total_steps
    int step
    float total_loss
    int tokens_seen
}

func shape1(int n) []int {
    []int s = []int{cap: 1}
    s[0] = n
    s
}

func init_real_training(int vocab_size, int hidden_dim, int num_layers, float lr) real_training_state {
    []float embed_data = []float{cap: vocab_size * hidden_dim}
    []float q_data = []float{cap: hidden_dim * hidden_dim}
    []float k_data = []float{cap: hidden_dim * hidden_dim}
    []float v_data = []float{cap: hidden_dim * hidden_dim}
    []float out_data = []float{cap: hidden_dim * hidden_dim}
    []float head_data = []float{cap: hidden_dim * vocab_size}
    int i = 0
    float scale = 2.0 / (hidden_dim as float)
    while i < len(embed_data) {
        embed_data[i] = (i - (i / 100) * 100) as float * 0.01 - 0.5
        i = i + 1
    }
    i = 0
    while i < len(q_data) {
        q_data[i] = (i - (i / 50) * 50) as float * 0.01 - 0.25
        i = i + 1
    }
    i = 0
    while i < len(k_data) {
        k_data[i] = (i - (i / 50) * 50) as float * 0.01 - 0.25
        i = i + 1
    }
    i = 0
    while i < len(v_data) {
        v_data[i] = (i - (i / 50) * 50) as float * 0.01 - 0.25
        i = i + 1
    }
    i = 0
    while i < len(out_data) {
        out_data[i] = (i - (i / 50) * 50) as float * 0.01 - 0.25
        i = i + 1
    }
    i = 0
    while i < len(head_data) {
        head_data[i] = (i - (i / 100) * 100) as float * 0.01 - 0.5
        i = i + 1
    }
    int param_count = len(embed_data) + len(q_data) + len(k_data) + len(v_data) + len(out_data) + len(head_data)
    []float m_state = []float{cap: param_count}
    []float v_state = []float{cap: param_count}
    real_training_state {
        weights_q: new(q_data, [hidden_dim, hidden_dim], true),
        weights_k: new(k_data, [hidden_dim, hidden_dim], true),
        weights_v: new(v_data, [hidden_dim, hidden_dim], true),
        weights_out: new(out_data, [hidden_dim, hidden_dim], true),
        embedding: new(embed_data, [vocab_size, hidden_dim], true),
        lm_head: new(head_data, [hidden_dim, vocab_size], true),
        adam_m: m_state,
        adam_v: v_state,
        learning_rate: lr,
        total_steps: 0,
        step: 0,
        total_loss: 0.0,
        tokens_seen: 0
    }
}

func forward_pass(real_training_state state, tensor input_ids) tensor {
    tensor hidden = ops.embedding_lookup(state.embedding, input_ids, 0)
    ops.matmul(hidden, state.lm_head)
}

func compute_loss(tensor logits, tensor targets) float {
    return cross_entropy_loss(logits, targets)
}

func backward_pass(tensor logits, tensor targets) tensor {
    return grad_logits(logits, targets)
}

func update_parameters(real_training_state state, tensor hidden, tensor grad) real_training_state {
    tensor hidden_t = transpose(hidden, 0, 1)
    tensor grad_lm_head = matmul(hidden_t, grad)
    int i = 0
    int n = len(state.lm_head.data)
    []float next_head = []float{cap: n}
    while i < n {
        float g = 0.0
        if i < len(grad_lm_head.data) {
            g = grad_lm_head.data[i]
        }
        next_head[i] = state.lm_head.data[i] - state.learning_rate * g
        i = i + 1
    }
    state.lm_head = new(next_head, state.lm_head.shape, true)
    state
}

func training_step(
    real_training_state state,
    tensor input_ids,
    tensor target_ids
) real_training_state {
    tensor logits = forward_pass(state, input_ids)
    float loss = compute_loss(logits, target_ids)
    tensor grad = backward_pass(logits, target_ids)
    tensor hidden = ops.embedding_lookup(state.embedding, input_ids, 0)
    real_training_state next_state = update_parameters(state, hidden, grad)
    int batch_size = input_ids.shape[0]
    next_state.step = next_state.step + 1
    next_state.total_loss = next_state.total_loss + loss
    next_state.tokens_seen = next_state.tokens_seen + batch_size
    if next_state.step / 100 * 100 == next_state.step {
        float avg_loss = next_state.total_loss / (next_state.step as float)
        print_training_progress(next_state.step, avg_loss, next_state.learning_rate, next_state.tokens_seen)
    }
    next_state
}

func run_training_loop(
    string manifest_path,
    int num_steps,
    int batch_size,
    int seq_len,
    int vocab_size,
    int hidden_dim,
    float learning_rate
) real_training_state {
    println("========================================")
    println("Starting Real Neural Network Training")
    println("========================================")
    println("manifest: " + manifest_path)
    println("Steps: " + int_to_str(num_steps, 0))
    println("batch_2 size: " + int_to_str(batch_size, 0))
    println("Seq len: " + int_to_str(seq_len, 0))
    println("Vocab size: " + int_to_str(vocab_size, 0))
    println("Hidden dim: " + int_to_str(hidden_dim, 0))
    println("Learning rate: " + fmt_float(learning_rate, 6))
    println("")
    real_training_state state = init_real_training(vocab_size, hidden_dim, 12, learning_rate)
    state.total_steps = num_steps
    []string data_paths = gpt_large_pretrain_manifest_refs(manifest_path)
    corpus_state corpus = new_corpus_state_from_paths(data_paths, batch_size, seq_len, true)
    int step = 0
    while step < num_steps {
        corpus_batch_result batch_result = corpus_next_batch(corpus)
        corpus = batch_result.state
        if len(batch_result.batch.input_ids) == 0 {
            break
        }
        tensor input_tensor = new_from_ints(batch_result.batch.input_ids, shape1(len(batch_result.batch.input_ids)))
        tensor target_tensor = one_hot_from_ints(batch_result.batch.target_ids, vocab_size)
        state = training_step(state, input_tensor, target_tensor)
        step = step + 1
    }
    println("")
    println("========================================")
    println("Training Complete!")
    println("Final loss: " + fmt_float(state.total_loss / (state.step as float), 4))
    println("Tokens seen: " + int_to_str(state.tokens_seen, 0))
    println("========================================")
    state
}

func one_hot_from_ints([]int values, int vocab_size) tensor {
    if vocab_size <= 0 {
        return new([]float{cap: 0}, shape1(0), true)
    }
    int n = len(values)
    []float data = []float{cap: n * vocab_size}
    int i = 0
    while i < n {
        int id = values[i]
        if id < 0 {
            id = 0
        }
        if vocab_size > 0 {
            id = id - (id / vocab_size) * vocab_size
        }
        data[i * vocab_size + id] = 1.0
        i = i + 1
    }
    new(data, [n, vocab_size], true)
}

func new_from_ints([]int values, []int shape) tensor {
    []float data = []float{cap: len(values)}
    int i = 0
    while i < len(values) {
        data[i] = values[i] as float
        i = i + 1
    }
    new(data, shape, true)
}
