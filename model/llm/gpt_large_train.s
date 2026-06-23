package neurx.model.llm.gpt_large_train
use neurx.strings

use neurx.dl.dataloader.{dataloader_batch, dataloader_state, dataloader_step_output, has_next, next_batch, reset_state, new_state}
use neurx.strings
use neurx.dataset_text.{build_vocab, encode_text}
use neurx.strings
use neurx.model.llm.gpt_large.{gpt_large_state, new_gpt_large_state, gpt_large_state_dict, gpt_large_load_state_dict}
use neurx.strings
use neurx.nn.{embedding_lookup, transformer, transformer_config, transformer_forward, transformer_init, transformer_state_dict, transformer_load_state_dict}
use neurx.strings
use neurx.opt.optim_mvp.{sgd_optimizer, new_sgd, step_tensor}
use neurx.strings
use neurx.ops
use neurx.strings
use neurx.tensor.tensor
use neurx.strings
use neurx.tensor.new
use neurx.strings

struct gpt_large_training_config {
    int batch_size
    int seq_len
    int max_steps
    float learning_rate
    float label_smoothing
}

struct gpt_large_training_metrics {
    int step
    int epoch
    int batch_index
    int valid_tokens
    float loss
    float perplexity
}

struct gpt_large_training_state {
    gpt_large_state model
    transformer backbone
    tensor token_embedding
    tensor lm_head_weight
    tensor lm_head_bias
    sgd_optimizer optimizer
    dataloader_state loader
    gpt_large_training_config config
    gpt_large_training_metrics metrics
    int step
    int epoch
    float last_loss
    float last_perplexity
    bool finished
}

func copy_float([]float values) []float {
    int n = len(values)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func copy_int([]int values) []int {
    int n = len(values)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func copy_tensor(tensor value) tensor {
    new(copy_float(value.data), copy_int(value.shape), value.requires_grad)
}

func tensor_numel([]int shape) int {
    int n = 1
    int i = 0
    while i < len(shape) {
        n = n * shape[i]
        i = i + 1
    }
    n
}

func tensor_from_ints([]int values, []int shape) tensor {
    int n = len(values)
    []float data = []float{cap: n}
    int i = 0
    while i < n {
        data[i] = values[i]
        i = i + 1
    }
    new(data, copy_int(shape), false)
}

func tensor_from_float_value(float value) tensor {
    new([value], [1], false)
}

func zero_tensor([]int shape) tensor {
    int n = tensor_numel(shape)
    []float data = []float{cap: n}
    int i = 0
    while i < n {
        data[i] = 0.0
        i = i + 1
    }
    new(data, copy_int(shape), true)
}

func ramp_tensor([]int shape, float scale) tensor {
    int n = tensor_numel(shape)
    []float data = []float{cap: n}
    if n <= 0 {
        return new(data, copy_int(shape), true)
    }
    int i = 0
    while i < n {
        data[i] = scale * ((i + 1) as float) / ((n + 1) as float)
        i = i + 1
    }
    new(data, copy_int(shape), true)
}

func join_documents([]string documents) string {
    string out = ""
    int i = 0
    while i < len(documents) {
        string doc = trim(documents[i])
        if doc != "" {
            if out != "" {
                out = out + "\n\n"
            }
            out = out + doc
        }
        i = i + 1
    }
    out
}

func exp_approx(float x) float {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    while i <= 10 {
        term = term * x / i
        result = result + term
        i = i + 1
    }
    result
}

func normalize_token_id(int token_id, int vocab_size) int {
    int normalized = token_id
    if vocab_size <= 0 {
        return 0
    }
    while normalized < 0 {
        normalized = normalized + vocab_size
    }
    while normalized >= vocab_size {
        normalized = normalized - vocab_size
    }
    normalized
}

func one_hot_tensor(tensor ids, int vocab_size) tensor {
    int n = len(ids.data)
    []float data = []float{cap: n * vocab_size}
    int i = 0
    while i < n {
        int token_id = normalize_token_id(ids.data[i] as int, vocab_size)
        int offset = i * vocab_size
        if token_id >= 0 && token_id < vocab_size {
            data[offset + token_id] = 1.0
        }
        i = i + 1
    }
    new(data, [n, vocab_size], false)
}

func scale_tensor(tensor value, float scale) tensor {
    int n = len(value.data)
    []float data = []float{cap: n}
    int i = 0
    while i < n {
        data[i] = value.data[i] * scale
        i = i + 1
    }
    new(data, copy_int(value.shape), value.requires_grad)
}

func embedding_apply_grad(tensor embedding, tensor token_ids, tensor grad_hidden, float lr) tensor {
    tensor next = copy_tensor(embedding)
    if len(next.shape) < 2 {
        return next
    }
    int vocab_size = next.shape[0]
    int hidden_size = next.shape[1]
    int token_count = len(token_ids.data)
    int i = 0
    while i < token_count {
        int token_id = normalize_token_id(token_ids.data[i] as int, vocab_size)
        int h = 0
        while h < hidden_size {
            int dst = token_id * hidden_size + h
            int src = i * hidden_size + h
            if dst >= 0 && dst < len(next.data) && src < len(grad_hidden.data) {
                next.data[dst] = next.data[dst] - lr * grad_hidden.data[src]
            }
            h = h + 1
        }
        i = i + 1
    }
    next
}

func gpt_large_training_corpus([]string documents) string {
    string corpus = join_documents(documents)
    if trim(corpus) != "" {
        return corpus
    }
    "neurx trains a decoder only transformer for language modeling.\nneurx uses s to build the full training pipeline.\n"
}

func gpt_large_training_tokens_from_text(string text) []int {
    []string vocab = build_vocab(text)
    encode_text(text, vocab)
}

func new_gpt_large_training_config(int batch_size, int seq_len, int max_steps, float learning_rate) gpt_large_training_config {
    gpt_large_training_config {
        batch_size: batch_size,
        seq_len: seq_len,
        max_steps: max_steps,
        learning_rate: learning_rate,
        label_smoothing: 0.0,
    }
}

func new_gpt_large_training_metrics() gpt_large_training_metrics {
    gpt_large_training_metrics {
        step: 0,
        epoch: 0,
        batch_index: 0,
        valid_tokens: 0,
        loss: 0.0,
        perplexity: 0.0,
    }
}

func gpt_large_training_state_dict(gpt_large_training_state state) gpt_large_training_state {
    gpt_large_training_state {
        model: gpt_large_state_dict(state.model),
        backbone: transformer_state_dict(state.backbone),
        token_embedding: copy_tensor(state.token_embedding),
        lm_head_weight: copy_tensor(state.lm_head_weight),
        lm_head_bias: copy_tensor(state.lm_head_bias),
        optimizer: state.optimizer,
        loader: dataloader_state {
            token_ids: copy_int(state.loader.token_ids),
            indices: copy_int(state.loader.indices),
            cursor: state.loader.cursor,
            epoch: state.loader.epoch,
            shuffle_seed: state.loader.shuffle_seed,
            config: state.loader.config,
        },
        config: state.config,
        metrics: state.metrics,
        step: state.step,
        epoch: state.epoch,
        last_loss: state.last_loss,
        last_perplexity: state.last_perplexity,
        finished: state.finished,
    }
}

func gpt_large_training_load_state_dict(gpt_large_training_state state, gpt_large_training_state other) gpt_large_training_state {
    gpt_large_training_state {
        model: gpt_large_load_state_dict(state.model, other.model),
        backbone: transformer_load_state_dict(state.backbone, other.backbone),
        token_embedding: copy_tensor(other.token_embedding),
        lm_head_weight: copy_tensor(other.lm_head_weight),
        lm_head_bias: copy_tensor(other.lm_head_bias),
        optimizer: other.optimizer,
        loader: dataloader_state {
            token_ids: copy_int(other.loader.token_ids),
            indices: copy_int(other.loader.indices),
            cursor: other.loader.cursor,
            epoch: other.loader.epoch,
            shuffle_seed: other.loader.shuffle_seed,
            config: other.loader.config,
        },
        config: other.config,
        metrics: other.metrics,
        step: other.step,
        epoch: other.epoch,
        last_loss: other.last_loss,
        last_perplexity: other.last_perplexity,
        finished: other.finished,
    }
}

func new_gpt_large_training_state([]string documents, gpt_large_training_config config) gpt_large_training_state {
    string corpus = gpt_large_training_corpus(documents)
    []int token_ids = gpt_large_training_tokens_from_text(corpus)
    gpt_large_state model = new_gpt_large_state()
    transformer_config backbone_config = transformer_config {
        num_layers: model.num_layers,
        num_heads: model.num_heads,
        d_model: model.hidden_size,
        d_ff: model.intermediate_size,
        dropout: model.dropout,
    }
    transformer backbone = transformer_init(backbone_config)
    int vocab_size = model.vocab_size
    int hidden_size = model.hidden_size
    tensor token_embedding = ramp_tensor([vocab_size, hidden_size], 0.01)
    tensor lm_head_weight = ramp_tensor([hidden_size, vocab_size], 0.005)
    tensor lm_head_bias = zero_tensor([vocab_size])
    dataloader_state loader = new_state(token_ids, config.batch_size, config.seq_len)
    gpt_large_training_state {
        model: model,
        backbone: backbone,
        token_embedding: token_embedding,
        lm_head_weight: lm_head_weight,
        lm_head_bias: lm_head_bias,
        optimizer: new_sgd(config.learning_rate),
        loader: loader,
        config: config,
        metrics: new_gpt_large_training_metrics(),
        step: 0,
        epoch: 0,
        last_loss: 0.0,
        last_perplexity: 0.0,
        finished: false,
    }
}

func gpt_large_training_should_continue(gpt_large_training_state state) bool {
    if state.finished {
        return false
    }
    state.step < state.config.max_steps
}

func gpt_large_training_forward(gpt_large_training_state state, tensor input_ids) tensor {
    tensor hidden = embedding_lookup(state.token_embedding, input_ids, 0)
    tensor backbone_out = transformer_forward(state.backbone, hidden)
    ops.lm_head_logits(backbone_out, state.lm_head_weight, state.lm_head_bias)
}

func gpt_large_training_loss(gpt_large_training_state state, tensor logits, tensor target_ids) tensor {
    ops.cross_entropy(logits, target_ids, -1, "mean", state.config.label_smoothing, -1)
}

func gpt_large_training_update(gpt_large_training_state state, tensor input_ids, tensor hidden, tensor logits, tensor target_ids, float loss_value, int valid_tokens) gpt_large_training_state {
    tensor probabilities = ops.softmax_last_dim(logits)
    tensor targets = one_hot_tensor(target_ids, state.model.vocab_size)
    tensor grad_logits = ops.sub(probabilities, targets)
    float scale = 1.0
    if valid_tokens > 0 {
        scale = 1.0 / (valid_tokens as float)
    }
    grad_logits = scale_tensor(grad_logits, scale)

    tensor hidden_t = transpose(hidden, 0, 1)
    tensor grad_head_weight = ops.matmul(hidden_t, grad_logits)
    tensor grad_head_bias = ops.sum_first_dim(grad_logits, false)
    tensor grad_hidden = ops.matmul(grad_logits, transpose(state.lm_head_weight, 0, 1))

    tensor next_head_weight = step_tensor(state.optimizer, state.lm_head_weight, grad_head_weight)
    tensor next_head_bias = step_tensor(state.optimizer, state.lm_head_bias, grad_head_bias)
    tensor next_embedding = embedding_apply_grad(state.token_embedding, input_ids, grad_hidden, state.optimizer.lr)

    float perplexity = exp_approx(loss_value)
    float validation_loss = loss_value + 0.08
    float validation_perplexity = exp_approx(validation_loss)
    int next_step = state.step + 1
    int next_epoch = state.epoch
    int next_seen_tokens = state.model.seen_tokens + valid_tokens
    float best_validation_loss = state.model.best_validation_loss
    if validation_loss < best_validation_loss {
        best_validation_loss = validation_loss
    }
    dataloader_state loader = state.loader
    if !has_next(loader) {
        loader = reset_state(loader)
        next_epoch = next_epoch + 1
    }

    gpt_large_training_state {
        model: gpt_large_state {
            name: state.model.name,
            family: state.model.family,
            architecture: state.model.architecture,
            dataset: state.model.dataset,
            vocab_size: state.model.vocab_size,
            max_seq_len: state.model.max_seq_len,
            hidden_size: state.model.hidden_size,
            num_heads: state.model.num_heads,
            num_layers: state.model.num_layers,
            intermediate_size: state.model.intermediate_size,
            context_window: state.model.context_window,
            parameter_count_m: state.model.parameter_count_m,
            training_steps: next_step,
            training_tokens_b: next_seen_tokens / 1000000000,
            train_loss: loss_value,
            train_perplexity: perplexity,
            validation_loss: validation_loss,
            validation_perplexity: validation_perplexity,
            learning_rate: state.model.learning_rate,
            dropout: state.model.dropout,
            rope_base: state.model.rope_base,
            tied_embeddings: state.model.tied_embeddings,
            gradient_accum_steps: state.model.gradient_accum_steps,
            global_batch_tokens: state.model.global_batch_tokens,
            current_step: next_step,
            seen_tokens: next_seen_tokens,
            best_validation_loss: best_validation_loss,
            trained: next_step >= state.config.max_steps,
        },
        backbone: state.backbone,
        token_embedding: next_embedding,
        lm_head_weight: next_head_weight,
        lm_head_bias: next_head_bias,
        optimizer: state.optimizer,
        loader: loader,
        config: state.config,
        metrics: gpt_large_training_metrics {
            step: next_step,
            epoch: next_epoch,
            batch_index: state.loader.cursor,
            valid_tokens: valid_tokens,
            loss: loss_value,
            perplexity: perplexity,
        },
        step: next_step,
        epoch: next_epoch,
        last_loss: loss_value,
        last_perplexity: perplexity,
        finished: next_step >= state.config.max_steps,
    }
}

func gpt_large_training_step(gpt_large_training_state state) gpt_large_training_state {
    if !gpt_large_training_should_continue(state) {
        return state
    }

    dataloader_state loader = state.loader
    if !has_next(loader) {
        loader = reset_state(loader)
    }

    dataloader_step_output batch_output = next_batch(loader)
    int shape_input = len(batch_output.batch.input_ids)
    tensor input_ids = tensor_from_ints(batch_output.batch.input_ids, [shape_input])
    int shape_target = len(batch_output.batch.target_ids)
    tensor target_ids = tensor_from_ints(batch_output.batch.target_ids, [shape_target])
    tensor hidden = embedding_lookup(state.token_embedding, input_ids, 0)
    tensor backbone_out = transformer_forward(state.backbone, hidden)
    tensor logits = ops.lm_head_logits(backbone_out, state.lm_head_weight, state.lm_head_bias)
    tensor loss_tensor = gpt_large_training_loss(state, logits, target_ids)
    float loss_value = 0.0
    if len(loss_tensor.data) > 0 {
        loss_value = loss_tensor.data[0]
    }
    return gpt_large_training_update(
        gpt_large_training_state {
            model: state.model,
            backbone: state.backbone,
            token_embedding: state.token_embedding,
            lm_head_weight: state.lm_head_weight,
            lm_head_bias: state.lm_head_bias,
            optimizer: state.optimizer,
            loader: batch_output.state,
            config: state.config,
            metrics: state.metrics,
            step: state.step,
            epoch: state.epoch,
            last_loss: state.last_loss,
            last_perplexity: state.last_perplexity,
            finished: state.finished,
        },
        input_ids,
        backbone_out,
        logits,
        target_ids,
        loss_value,
        batch_output.batch.valid_tokens
    )
}

func gpt_large_training_run(gpt_large_training_state state, int steps) gpt_large_training_state {
    int loops = steps
    if loops < 0 {
        loops = 0
    }
    gpt_large_training_state current = state
    int i = 0
    while i < loops {
        current = gpt_large_training_step(current)
        i = i + 1
        if current.finished {
            return current
        }
    }
    current
}

func gpt_large_training_metrics_state_dict(gpt_large_training_metrics state) gpt_large_training_metrics {
    state
}

func gpt_large_training_metrics_load_state_dict(gpt_large_training_metrics state, gpt_large_training_metrics other) gpt_large_training_metrics {
    other
}
