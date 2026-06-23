package neurx.pretrain.llm.gpt_large_pretrain
use neurx.strings

use neurx.dl.dataloader.{dataloader_state, dataloader_step_output, dataloader_state_dict, dataloader_load_state_dict, has_next, next_batch, new_state, reset_state}
use neurx.model.llm.gpt_large_train.{gpt_large_state, gpt_large_training_config, gpt_large_training_state, new_gpt_large_training_config, new_gpt_large_training_state, gpt_large_training_forward, gpt_large_training_loss, gpt_large_training_state_dict, gpt_large_training_load_state_dict}
use neurx.pretrain.distributed.{pretrain_ddp_state, pretrain_ddp_state_dict, pretrain_ddp_load_state_dict, new_pretrain_ddp_state_from_env, pretrain_ddp_enabled, pretrain_ddp_sync_tensor, pretrain_ddp_step, pretrain_ddp_rank, pretrain_ddp_world_size}
use neurx.pretrain.optimizer.pretrain_adamw.{pretrain_optimizer_state, pretrain_optimizer_step_state, new_pretrain_optimizer_state, pretrain_optimizer_step, pretrain_optimizer_state_dict, pretrain_optimizer_load_state_dict}
use neurx.pretrain.tokenizer.bpe.{bpe_split_state, bpe_tokenizer_state, bpe_tokenized_corpus_state, bpe_tokenized_corpus_from_documents, bpe_split_state_dict, bpe_split_load_state_dict, bpe_tokenizer_state_dict, bpe_tokenizer_load_state_dict, bpe_tokenized_corpus_state_dict, bpe_tokenized_corpus_load_state_dict}
use neurx.strings
use neurx.pretrain.checkpoint.{pretrain_checkpoint_state, new_pretrain_checkpoint_state, mark_saved, mark_best, pretrain_checkpoint_state_dict, pretrain_checkpoint_load_state_dict}
use neurx.strings
use neurx.pretrain.config.{pretrain_config, new_pretrain_config, with_max_steps, with_lr, pretrain_config_state_dict, pretrain_config_load_state_dict}
use neurx.strings
use neurx.pretrain.data.{pretrain_data_state, new_pretrain_data_state, advance_tokens, next_epoch, pretrain_data_state_dict, pretrain_data_load_state_dict}
use neurx.strings
use neurx.pretrain.eval.{pretrain_eval_state, new_pretrain_eval_state, update_pretrain_eval, pretrain_eval_state_dict, pretrain_eval_load_state_dict}
use neurx.strings
use neurx.pretrain.loop.{pretrain_loop_state, new_pretrain_loop_state, pretrain_step, pretrain_reset_micro_step, pretrain_loop_state_dict, pretrain_loop_load_state_dict}
use neurx.strings
use neurx.checkpoint.{save_checkpoint}
use neurx.strings
use neurx.runtime.io.{runtime_make_dirs, runtime_write_text_file}
use neurx.strings
use neurx.nn.{embedding_lookup, transformer_forward}
use neurx.strings
use neurx.ops
use neurx.tensor.new
use neurx.tensor.tensor
use neurx.strings

struct gpt_large_pretrain_state {
    pretrain_config cfg
    pretrain_data_state data
    pretrain_loop_state loop
    pretrain_checkpoint_state checkpoint
    pretrain_eval_state eval
    bpe_tokenized_corpus_state corpus
    pretrain_optimizer_state optimizer
    pretrain_ddp_state ddp
    gpt_large_training_state training
    dataloader_state valid_loader
    int rng_seed
    int rng_state
}

struct gpt_large_pretrain_eval_result {
    pretrain_eval_state eval
    dataloader_state valid_loader
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

func shape1(int size) []int {
    []int out = []int{cap: 1}
    out[0] = size
    out
}

func one_hot_tensor(tensor ids, int vocab_size) tensor {
    int n = len(ids.data)
    []float data = []float{cap: n * vocab_size}
    int i = 0
    while i < n {
        int token_id = ids.data[i] as int
        if token_id < 0 {
            token_id = 0
        }
        if vocab_size > 0 {
            while token_id >= vocab_size {
                token_id = token_id - vocab_size
            }
        } else {
            token_id = 0
        }
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

func zero_pad_int(int value, int width) string {
    string digits = string(value)
    string prefix = ""
    int missing = width - len(digits)
    if missing < 0 {
        missing = 0
    }
    int i = 0
    while i < missing {
        prefix = prefix + "0"
        i = i + 1
    }
    prefix + digits
}

func gpt_large_pretrain_documents() []string {
    []string docs = []string{cap: 3}
    docs[0] = "neurx is a transformer first deep learning framework."
    docs[1] = "pretraining trains decoder only language models on token streams."
    docs[2] = "the pretrain layer coordinates loop, checkpoint, and evaluation states."
    docs
}

func new_gpt_large_pretrain_config() pretrain_config {
    pretrain_config cfg = new_pretrain_config()
    cfg = with_max_steps(cfg, 64)
    cfg = with_lr(cfg, 0.00015)
    pretrain_config {
        global_batch_size: cfg.global_batch_size,
        micro_batch_size: 8,
        seq_len: 16,
        max_steps: cfg.max_steps,
        warmup_steps: cfg.warmup_steps,
        lr: cfg.lr,
        min_lr: cfg.min_lr,
        weight_decay: cfg.weight_decay,
        log_interval: 8,
        eval_interval: 16,
        save_interval: 32,
        bf16: cfg.bf16,
        grad_checkpoint: cfg.grad_checkpoint,
        optimizer: "adamw",
        scheduler: "cosine",
        backend: cfg.backend,
    }
}

func new_gpt_large_pretrain_state() gpt_large_pretrain_state {
    pretrain_config cfg = new_gpt_large_pretrain_config()
    gpt_large_training_config training_cfg = new_gpt_large_training_config(cfg.micro_batch_size, cfg.seq_len, cfg.max_steps, cfg.lr)
    []string documents = gpt_large_pretrain_documents()
    bpe_tokenized_corpus_state corpus = bpe_tokenized_corpus_from_documents(documents, 4096, 2, 0.1, 1337)
    gpt_large_training_state training = new_gpt_large_training_state(documents, training_cfg)
    dataloader_state train_loader = new_state(corpus.train_token_ids, training_cfg.batch_size, training_cfg.seq_len)
    dataloader_state valid_loader = new_state(corpus.valid_token_ids, training_cfg.batch_size, training_cfg.seq_len)
    training = gpt_large_training_state {
        model: training.model,
        backbone: training.backbone,
        token_embedding: training.token_embedding,
        lm_head_weight: training.lm_head_weight,
        lm_head_bias: training.lm_head_bias,
        optimizer: training.optimizer,
        loader: train_loader,
        config: training.config,
        metrics: training.metrics,
        step: training.step,
        epoch: training.epoch,
        last_loss: training.last_loss,
        last_perplexity: training.last_perplexity,
        finished: training.finished,
    }
    pretrain_data_state data = new_pretrain_data_state(training.model.dataset, 0, 1)
    pretrain_loop_state loop = new_pretrain_loop_state(cfg, data)
    pretrain_optimizer_state optimizer = new_pretrain_optimizer_state(cfg.lr, cfg.min_lr, cfg.warmup_steps, cfg.max_steps, cfg.weight_decay, 1.0)
    pretrain_ddp_state ddp = new_pretrain_ddp_state_from_env("gpt_large_pretrain", 256, false)
    gpt_large_pretrain_state {
        cfg: cfg,
        data: data,
        loop: loop,
        checkpoint: new_pretrain_checkpoint_state("gpt_large_pretrain", "artifacts/checkpoints/run_20260518_001"),
        eval: new_pretrain_eval_state(),
        corpus: corpus,
        optimizer: optimizer,
        ddp: ddp,
        training: training,
        valid_loader: valid_loader,
        rng_seed: 1337,
        rng_state: 1337,
    }
}

func new_gpt_large_pretrain_state_with_params(int micro_batch_size, int seq_len, int max_steps, float lr, int log_interval, int eval_interval, int save_interval) gpt_large_pretrain_state {
    pretrain_config base_cfg = new_gpt_large_pretrain_config()
    pretrain_config cfg = pretrain_config {
        global_batch_size: base_cfg.global_batch_size,
        micro_batch_size: micro_batch_size,
        seq_len: seq_len,
        max_steps: max_steps,
        warmup_steps: base_cfg.warmup_steps,
        lr: lr,
        min_lr: base_cfg.min_lr,
        weight_decay: base_cfg.weight_decay,
        log_interval: log_interval,
        eval_interval: eval_interval,
        save_interval: save_interval,
        bf16: base_cfg.bf16,
        grad_checkpoint: base_cfg.grad_checkpoint,
        optimizer: base_cfg.optimizer,
        scheduler: base_cfg.scheduler,
        backend: base_cfg.backend,
    }

    gpt_large_training_config training_cfg = new_gpt_large_training_config(cfg.micro_batch_size, cfg.seq_len, cfg.max_steps, cfg.lr)
    []string documents = gpt_large_pretrain_documents()
    bpe_tokenized_corpus_state corpus = bpe_tokenized_corpus_from_documents(documents, 4096, 2, 0.1, 1337)
    gpt_large_training_state training = new_gpt_large_training_state(documents, training_cfg)
    dataloader_state train_loader = new_state(corpus.train_token_ids, training_cfg.batch_size, training_cfg.seq_len)
    dataloader_state valid_loader = new_state(corpus.valid_token_ids, training_cfg.batch_size, training_cfg.seq_len)
    training = gpt_large_training_state {
        model: training.model,
        backbone: training.backbone,
        token_embedding: training.token_embedding,
        lm_head_weight: training.lm_head_weight,
        lm_head_bias: training.lm_head_bias,
        optimizer: training.optimizer,
        loader: train_loader,
        config: training.config,
        metrics: training.metrics,
        step: training.step,
        epoch: training.epoch,
        last_loss: training.last_loss,
        last_perplexity: training.last_perplexity,
        finished: training.finished,
    }
    pretrain_data_state data = new_pretrain_data_state(training.model.dataset, 0, 1)
    pretrain_loop_state loop = new_pretrain_loop_state(cfg, data)
    pretrain_optimizer_state optimizer = new_pretrain_optimizer_state(cfg.lr, cfg.min_lr, cfg.warmup_steps, cfg.max_steps, cfg.weight_decay, 1.0)
    pretrain_ddp_state ddp = new_pretrain_ddp_state_from_env("gpt_large_pretrain", 256, false)
    gpt_large_pretrain_state {
        cfg: cfg,
        data: data,
        loop: loop,
        checkpoint: new_pretrain_checkpoint_state("gpt_large_pretrain", "artifacts/checkpoints/run_20260518_001"),
        eval: new_pretrain_eval_state(),
        corpus: corpus,
        optimizer: optimizer,
        ddp: ddp,
        training: training,
        valid_loader: valid_loader,
        rng_seed: 1337,
        rng_state: 1337,
    }
}

func gpt_large_pretrain_checkpoint_path(gpt_large_pretrain_state state) string {
    string run_root = state.checkpoint.root
    if trim(run_root) == "" {
        run_root = "artifacts/checkpoints/run_20260518_001"
    }
    run_root + "/step_" + zero_pad_int(state.loop.global_step, 7) + "/latest/" + state.checkpoint.run_name
}

func gpt_large_pretrain_checkpoint_dir(gpt_large_pretrain_state state) string {
    string run_root = state.checkpoint.root
    if trim(run_root) == "" {
        run_root = "artifacts/checkpoints/run_20260518_001"
    }
    run_root + "/step_" + zero_pad_int(state.loop.global_step, 7) + "/latest"
}

func gpt_large_pretrain_checkpoint_params(gpt_large_pretrain_state state) []tensor {
    []tensor params = []tensor{cap: 0}
    params.push(state.training.token_embedding)
    params.push(state.training.lm_head_weight)
    params.push(state.training.lm_head_bias)
    int i = 0
    while i < len(state.training.backbone.layers) {
        params.push(state.training.backbone.layers[i].w_q)
        params.push(state.training.backbone.layers[i].w_k)
        params.push(state.training.backbone.layers[i].w_v)
        params.push(state.training.backbone.layers[i].w_o)
        params.push(state.training.backbone.layers[i].w_ff1)
        params.push(state.training.backbone.layers[i].w_ff2)
        params.push(state.training.backbone.layers[i].b_ff1)
        params.push(state.training.backbone.layers[i].b_ff2)
        i = i + 1
    }
    params
}

func gpt_large_pretrain_metadata_path(gpt_large_pretrain_state state) string {
    gpt_large_pretrain_checkpoint_path(state) + ".meta"
}

func gpt_large_pretrain_metadata_text(gpt_large_pretrain_state state) string {
    string out = "pretrain_meta_v1\n"
    out = out + "step=" + string(state.loop.global_step) + "\n"
    out = out + "epoch=" + string(state.loop.data.epoch) + "\n"
    out = out + "loss=" + string(state.training.last_loss) + "\n"
    out = out + "best_metric=" + string(state.checkpoint.best_metric) + "\n"
    out = out + "optimizer.step=" + string(state.optimizer.step) + "\n"
    out = out + "optimizer.lr=" + string(state.optimizer.last_lr) + "\n"
    out = out + "optimizer.grad_norm=" + string(state.optimizer.last_grad_norm) + "\n"
    out = out + "loader.cursor=" + string(state.training.loader.cursor) + "\n"
    out = out + "loader.epoch=" + string(state.training.loader.epoch) + "\n"
    out = out + "valid_loader.cursor=" + string(state.valid_loader.cursor) + "\n"
    out = out + "valid_loader.epoch=" + string(state.valid_loader.epoch) + "\n"
    out = out + "rng.seed=" + string(state.rng_seed) + "\n"
    out = out + "rng.state=" + string(state.rng_state) + "\n"
    out = out + "ddp.enabled=" + string(pretrain_ddp_enabled(state.ddp)) + "\n"
    out = out + "ddp.rank=" + string(pretrain_ddp_rank(state.ddp)) + "\n"
    out = out + "ddp.world_size=" + string(pretrain_ddp_world_size(state.ddp)) + "\n"
    out = out + "corpus.train_docs=" + string(len(state.corpus.split.train_documents)) + "\n"
    out = out + "corpus.valid_docs=" + string(len(state.corpus.split.valid_documents)) + "\n"
    out = out + "corpus.train_tokens=" + string(len(state.corpus.train_token_ids)) + "\n"
    out = out + "corpus.valid_tokens=" + string(len(state.corpus.valid_token_ids)) + "\n"
    out
}

func gpt_large_pretrain_train_batch(gpt_large_pretrain_state state) dataloader_step_output {
    dataloader_state loader = state.training.loader
    if !has_next(loader) {
        loader = reset_state(loader)
    }
    next_batch(loader)
}

func gpt_large_pretrain_valid_batch(gpt_large_pretrain_state state) dataloader_step_output {
    dataloader_state loader = state.valid_loader
    if !has_next(loader) {
        loader = reset_state(loader)
    }
    next_batch(loader)
}

func gpt_large_pretrain_loss_value(gpt_large_training_state training, tensor logits, tensor target_ids) float {
    tensor loss_tensor = gpt_large_training_loss(training, logits, target_ids)
    if len(loss_tensor.data) > 0 {
        return loss_tensor.data[0]
    }
    0.0
}

func gpt_large_pretrain_validation_metrics(gpt_large_pretrain_state state) gpt_large_pretrain_eval_result {
    dataloader_step_output batch_output = gpt_large_pretrain_valid_batch(state)
    int input_len = len(batch_output.batch.input_ids)
    int target_len = len(batch_output.batch.target_ids)
    tensor input_ids = tensor_from_ints(batch_output.batch.input_ids, shape1(input_len))
    tensor target_ids = tensor_from_ints(batch_output.batch.target_ids, shape1(target_len))
    tensor hidden = embedding_lookup(state.training.token_embedding, input_ids, 0)
    tensor backbone_out = transformer_forward(state.training.backbone, hidden)
    tensor logits = ops.lm_head_logits(backbone_out, state.training.lm_head_weight, state.training.lm_head_bias)
    float val_loss = gpt_large_pretrain_loss_value(state.training, logits, target_ids)
    float ppl = 1.0 + val_loss * val_loss * 3.0
    gpt_large_pretrain_eval_result {
        eval: update_pretrain_eval(state.eval, state.loop.global_step, val_loss, ppl),
        valid_loader: batch_output.state,
    }
}

func embedding_grad_tensor(tensor token_ids, tensor grad_hidden, int vocab_size, int hidden_size) tensor {
    []float data = []float{cap: vocab_size * hidden_size}
    int token_count = len(token_ids.data)
    int i = 0
    while i < token_count {
        int token_id = token_ids.data[i] as int
        if token_id < 0 {
            token_id = 0
        }
        if vocab_size > 0 {
            while token_id >= vocab_size {
                token_id = token_id - vocab_size
            }
        } else {
            token_id = 0
        }
        int h = 0
        while h < hidden_size && i * hidden_size + h < len(grad_hidden.data) {
            int dst = token_id * hidden_size + h
            data[dst] = data[dst] + grad_hidden.data[i * hidden_size + h]
            h = h + 1
        }
        i = i + 1
    }
    new(data, [vocab_size, hidden_size], false)
}

func gpt_large_pretrain_forward_logits(gpt_large_pretrain_state state, tensor input_ids) tensor {
    tensor hidden = embedding_lookup(state.training.token_embedding, input_ids, 0)
    tensor backbone_out = transformer_forward(state.training.backbone, hidden)
    ops.lm_head_logits(backbone_out, state.training.lm_head_weight, state.training.lm_head_bias)
}

func gpt_large_pretrain_optimizer_update(gpt_large_pretrain_state state, dataloader_step_output train_output, dataloader_step_output valid_output) gpt_large_pretrain_state {
    int train_input_len = len(train_output.batch.input_ids)
    int train_target_len = len(train_output.batch.target_ids)
    tensor input_ids = tensor_from_ints(train_output.batch.input_ids, shape1(train_input_len))
    tensor target_ids = tensor_from_ints(train_output.batch.target_ids, shape1(train_target_len))
    tensor hidden = embedding_lookup(state.training.token_embedding, input_ids, 0)
    tensor backbone_out = transformer_forward(state.training.backbone, hidden)
    tensor logits = ops.lm_head_logits(backbone_out, state.training.lm_head_weight, state.training.lm_head_bias)
    tensor loss_tensor = gpt_large_training_loss(state.training, logits, target_ids)
    float loss_value = 0.0
    if len(loss_tensor.data) > 0 {
        loss_value = loss_tensor.data[0]
    }

    tensor probabilities = ops.softmax_last_dim(logits)
    tensor targets = one_hot_tensor(target_ids, state.training.model.vocab_size)
    tensor grad_logits = ops.sub(probabilities, targets)
    float scale = 1.0
    if train_output.batch.valid_tokens > 0 {
        scale = 1.0 / float(train_output.batch.valid_tokens)
    }
    grad_logits = scale_tensor(grad_logits, scale)

    tensor grad_head_weight = ops.matmul(transpose(backbone_out, 0, 1), grad_logits)
    tensor grad_head_bias = ops.sum_first_dim(grad_logits, false)
    tensor grad_hidden = ops.matmul(grad_logits, transpose(state.training.lm_head_weight, 0, 1))
    tensor grad_embedding = embedding_grad_tensor(input_ids, grad_hidden, state.training.model.vocab_size, state.training.model.hidden_size)

    if pretrain_ddp_enabled(state.ddp) {
        grad_embedding = pretrain_ddp_sync_tensor(state.ddp, grad_embedding)
        grad_head_weight = pretrain_ddp_sync_tensor(state.ddp, grad_head_weight)
        grad_head_bias = pretrain_ddp_sync_tensor(state.ddp, grad_head_bias)
    }

    pretrain_optimizer_step_state optimizer_step = pretrain_optimizer_step(
        state.optimizer,
        state.training.token_embedding,
        grad_embedding,
        state.training.lm_head_weight,
        grad_head_weight,
        state.training.lm_head_bias,
        grad_head_bias
    )

    dataloader_state next_train_loader = train_output.state
    int next_loader_epoch = next_train_loader.epoch
    int next_step = state.training.step + 1
    int next_seen_tokens = state.training.model.seen_tokens + train_output.batch.valid_tokens
    float train_ppl = 1.0 + loss_value * loss_value * 3.0
    int valid_input_len = len(valid_output.batch.input_ids)
    int valid_target_len = len(valid_output.batch.target_ids)
    tensor valid_input_ids = tensor_from_ints(valid_output.batch.input_ids, shape1(valid_input_len))
    tensor valid_target_ids = tensor_from_ints(valid_output.batch.target_ids, shape1(valid_target_len))
    tensor valid_hidden = embedding_lookup(state.training.token_embedding, valid_input_ids, 0)
    tensor valid_backbone_out = transformer_forward(state.training.backbone, valid_hidden)
    tensor valid_logits = ops.lm_head_logits(valid_backbone_out, state.training.lm_head_weight, state.training.lm_head_bias)
    float validation_loss = gpt_large_pretrain_loss_value(state.training, valid_logits, valid_target_ids)
    float validation_perplexity = 1.0 + validation_loss * validation_loss * 3.0
    float best_validation_loss = state.training.model.best_validation_loss
    if validation_loss < best_validation_loss {
        best_validation_loss = validation_loss
    }

    pretrain_eval_state next_eval = state.eval
    if state.cfg.eval_interval > 0 && (next_step / state.cfg.eval_interval) * state.cfg.eval_interval == next_step {
        next_eval = update_pretrain_eval(state.eval, next_step, validation_loss, validation_perplexity)
    }
    dataloader_state next_valid_loader = valid_output.state

    pretrain_checkpoint_state next_checkpoint = state.checkpoint
    if state.cfg.save_interval > 0 && (next_step / state.cfg.save_interval) * state.cfg.save_interval == next_step {
        next_checkpoint = mark_saved(next_checkpoint, next_step)
    }
    next_checkpoint = mark_best(next_checkpoint, next_step, validation_loss)

    pretrain_loop_state next_loop = pretrain_step(state.loop, loss_value, optimizer_step.grad_norm, train_output.batch.valid_tokens)
    pretrain_data_state next_data = advance_tokens(state.data, train_output.batch.valid_tokens)
    if next_loader_epoch > state.training.epoch {
        next_data = next_epoch(next_data)
    }

    gpt_large_training_state next_training = gpt_large_training_state {
        model: gpt_large_state {
            name: state.training.model.name,
            family: state.training.model.family,
            architecture: state.training.model.architecture,
            dataset: state.training.model.dataset,
            vocab_size: state.training.model.vocab_size,
            max_seq_len: state.training.model.max_seq_len,
            hidden_size: state.training.model.hidden_size,
            num_heads: state.training.model.num_heads,
            num_layers: state.training.model.num_layers,
            intermediate_size: state.training.model.intermediate_size,
            context_window: state.training.model.context_window,
            parameter_count_m: state.training.model.parameter_count_m,
            training_steps: next_step,
            training_tokens_b: next_seen_tokens / 1000000000,
            train_loss: loss_value,
            train_perplexity: train_ppl,
            validation_loss: validation_loss,
            validation_perplexity: validation_perplexity,
            learning_rate: optimizer_step.lr,
            dropout: state.training.model.dropout,
            rope_base: state.training.model.rope_base,
            tied_embeddings: state.training.model.tied_embeddings,
            gradient_accum_steps: state.training.model.gradient_accum_steps,
            global_batch_tokens: state.training.model.global_batch_tokens,
            current_step: next_step,
            seen_tokens: next_seen_tokens,
            best_validation_loss: best_validation_loss,
            trained: next_step >= state.training.config.max_steps,
        },
        backbone: state.training.backbone,
        token_embedding: optimizer_step.token_embedding,
        lm_head_weight: optimizer_step.lm_head_weight,
        lm_head_bias: optimizer_step.lm_head_bias,
        optimizer: state.training.optimizer,
        loader: next_train_loader,
        config: state.training.config,
        metrics: state.training.metrics,
        step: next_step,
        epoch: next_loader_epoch,
        last_loss: loss_value,
        last_perplexity: train_ppl,
        finished: next_step >= state.training.config.max_steps,
    }

    gpt_large_pretrain_state {
        cfg: state.cfg,
        data: next_data,
        loop: next_loop,
        checkpoint: next_checkpoint,
        eval: next_eval,
        corpus: state.corpus,
        optimizer: optimizer_step.optimizer,
        ddp: pretrain_ddp_step(state.ddp),
        training: next_training,
        valid_loader: next_valid_loader,
        rng_seed: state.rng_seed,
        rng_state: state.rng_state + 1,
    }
}

func gpt_large_pretrain_save_checkpoint(gpt_large_pretrain_state state) () {
    runtime_make_dirs(gpt_large_pretrain_checkpoint_dir(state))
    save_checkpoint(
        gpt_large_pretrain_checkpoint_path(state),
        state.loop.global_step,
        state.training.last_loss,
        gpt_large_pretrain_checkpoint_params(state)
    )
    runtime_write_text_file(gpt_large_pretrain_metadata_path(state), gpt_large_pretrain_metadata_text(state))
}

func gpt_large_pretrain_state_dict(gpt_large_pretrain_state state) gpt_large_pretrain_state {
    gpt_large_pretrain_state {
        cfg: pretrain_config_state_dict(state.cfg),
        data: pretrain_data_state_dict(state.data),
        loop: pretrain_loop_state_dict(state.loop),
        checkpoint: pretrain_checkpoint_state_dict(state.checkpoint),
        eval: pretrain_eval_state_dict(state.eval),
        corpus: bpe_tokenized_corpus_state_dict(state.corpus),
        optimizer: pretrain_optimizer_state_dict(state.optimizer),
        ddp: pretrain_ddp_state_dict(state.ddp),
        training: gpt_large_training_state_dict(state.training),
        valid_loader: dataloader_state_dict(state.valid_loader),
        rng_seed: state.rng_seed,
        rng_state: state.rng_state,
    }
}

func gpt_large_pretrain_load_state_dict(gpt_large_pretrain_state state, gpt_large_pretrain_state other) gpt_large_pretrain_state {
    gpt_large_pretrain_state {
        cfg: pretrain_config_load_state_dict(state.cfg, other.cfg),
        data: pretrain_data_load_state_dict(state.data, other.data),
        loop: pretrain_loop_load_state_dict(state.loop, other.loop),
        checkpoint: pretrain_checkpoint_load_state_dict(state.checkpoint, other.checkpoint),
        eval: pretrain_eval_load_state_dict(state.eval, other.eval),
        corpus: bpe_tokenized_corpus_load_state_dict(state.corpus, other.corpus),
        optimizer: pretrain_optimizer_load_state_dict(state.optimizer, other.optimizer),
        ddp: pretrain_ddp_load_state_dict(state.ddp, other.ddp),
        training: gpt_large_training_load_state_dict(state.training, other.training),
        valid_loader: dataloader_load_state_dict(state.valid_loader, other.valid_loader),
        rng_seed: other.rng_seed,
        rng_state: other.rng_state,
    }
}

func gpt_large_pretrain_step(gpt_large_pretrain_state state) gpt_large_pretrain_state {
    if state.loop.finished {
        return state
    }

    dataloader_step_output train_output = gpt_large_pretrain_train_batch(state)
    dataloader_step_output valid_output = gpt_large_pretrain_valid_batch(state)
    gpt_large_pretrain_state next = gpt_large_pretrain_optimizer_update(state, train_output, valid_output)
    if next.loop.global_step < state.loop.global_step {
        return state
    }
    next
}

func gpt_large_pretrain_run(gpt_large_pretrain_state state, int steps) gpt_large_pretrain_state {
    int loops = steps
    if loops < 0 {
        loops = 0
    }
    gpt_large_pretrain_state current = state
    int i = 0
    while i < loops {
        current = gpt_large_pretrain_step(current)
        i = i + 1
        if current.loop.finished {
            return current
        }
    }
    current
}

func gpt_large_pretrain_run_and_save(gpt_large_pretrain_state state, int steps) gpt_large_pretrain_state {
    gpt_large_pretrain_state current = gpt_large_pretrain_run(state, steps)
    gpt_large_pretrain_save_checkpoint(current)
    current
}

func gpt_large_pretrain_complete(gpt_large_pretrain_state state) bool {
    state.loop.finished
}
