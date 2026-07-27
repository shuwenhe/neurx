package neurx.trainer.loop
import "neurx.autograd"
import "neurx.optimizer"
import "neurx.loss"
import "neurx.distributed.zero"
import "neurx.amp.training"
import "neurx.checkpoint.gradient"
import "neurx.checkpoint.checkpoint_training"
enum training_mode {
    TRAIN = 0
    VALIDATE = 1
    TEST = 2
}
struct training_config {
    epochs: int
    batch_size: int
    learning_rate: float
    weight_decay: float
    warmup_steps: int
    total_steps: int
    gradient_accumulation_steps: int
    max_grad_norm: float
    logging_interval: int
    eval_interval: int
    save_interval: int
    device: string
    dtype: training.amp_dtype
    enable_amp: bool
    enable_checkpointing: bool
    enable_zero: bool
    zero_stage: int
    seed: int
}
struct training_state {
    epoch: int
    step: int
    global_step: int
    loss: float
    avg_loss: float
    lr: float
    train_time: float
    samples_processed: int
    tokens_processed: int
    best_val_loss: float
    is_training: bool
}
struct training_stats {
    train_loss: []float
    val_loss: []float
    train_ppl: []float
    val_ppl: []float
    learning_rates: []float
    throughput: []float
}
struct training_loop {
    model: pointer
    optimizer: opt.adamw_optimizer
    config: training_config
    state: training_state
    stats: training_stats
    amp: training.mixed_precision_model
    checkpoint_manager: checkpoint_training.checkpoint_manager
    zero_state: zero.zero_state
    checkpoint_config: gradient.checkpoint_config
}
func new_training_config() training_config {
    training_config config {
        epochs: 10,
        batch_size: 8,
        learning_rate: 2e-4,
        weight_decay: 0.1,
        warmup_steps: 1000,
        total_steps: 100000,
        gradient_accumulation_steps: 4,
        max_grad_norm: 1.0,
        logging_interval: 10,
        eval_interval: 1000,
        save_interval: 1000,
        device: "cpu",
        dtype: training.amp_dtype.FP16,
        enable_amp: true,
        enable_checkpointing: true,
        enable_zero: true,
        zero_stage: 2,
        seed: 42,
    }
    config
}
func new_training_state(training_config config) training_state {
    training_state state {
        epoch: 0,
        step: 0,
        global_step: 0,
        loss: 0.0,
        avg_loss: 0.0,
        lr: config.learning_rate,
        train_time: 0.0,
        samples_processed: 0,
        tokens_processed: 0,
        best_val_loss: 1e18,
        is_training: true,
    }
    state
}
func new_training_loop(
    pointer model,
    opt.adamw_optimizer optimizer,
    training_config config,
) training_loop {
    training_state state = new_training_state(config)
    training.mixed_precision_model amp
    if config.enable_amp {
        training.amp_config amp_config = training.new_amp_config(config.dtype, true)
        amp = training.mixed_precision_model{
            model: model,
            amp_config: amp_config,
            amp_state: training.new_amp_state(amp_config, len(model.parameters())),
            param_groups: [][model.parameters()],
        }
    }
    checkpoint_training.checkpoint_config ckpt_config = checkpoint_training.new_checkpoint_config("./checkpoints")
    ckpt_config.save_interval = config.save_interval
    checkpoint_training.checkpoint_manager ckpt_manager = checkpoint_training.new_checkpoint_manager(ckpt_config)
    zero.zero_state zero_state
    if config.enable_zero {
        zero_state = zero.new_zero_state(config.zero_stage, len(model.parameters()))
    }
    gradient.checkpoint_config grad_ckpt_config = gradient.new_checkpoint_config(config.enable_checkpointing)
    training_loop loop {
        model: model,
        optimizer: optimizer,
        config: config,
        state: state,
        stats: training_stats{
            train_loss: []float{},
            val_loss: []float{},
            train_ppl: []float{},
            val_ppl: []float{},
            learning_rates: []float{},
            throughput: []float{},
        },
        amp: amp,
        checkpoint_manager: ckpt_manager,
        zero_state: zero_state,
        checkpoint_config: grad_ckpt_config,
    }
    loop
}
func compute_lr(training_loop loop) float {
    int step = loop.state.global_step
    int warmup = loop.config.warmup_steps
    int total = loop.config.total_steps
    if step < warmup {
        return loop.config.learning_rate * (step * 1.0 / warmup)
    }
    float progress = (step - warmup) * 1.0 / (total - warmup)
    float cos_decay = 0.5 * (1.0 + cos(progress * 3.14159))
    loop.config.learning_rate * cos_decay
}
func train_step(training_loop loop, []autograd.tensor batch, []int labels) float {
    if loop.config.enable_amp {
        training.amp_zero_grad(loop.amp)
    } else {
        autograd.zero_grad(loop.model.parameters())
    }
    float total_loss = 0.0
    for i := 0; i < loop.config.gradient_accumulation_steps; i += 1 {
        []autograd.tensor inputs = batch[i*loop.config.batch_size..(i+1)*loop.config.batch_size]
        []autograd.tensor logits
        if loop.config.enable_checkpointing {
            logits = gradient.checkpoint_wrapper(
                loop.model.forward,
                inputs,
                loop.checkpoint_config,
            )
        } else {
            logits = loop.model.forward(inputs)
        }
        float loss = loss.cross_entropy_loss(logits, labels)
        if loop.config.enable_amp {
            loss = training.amp_scale_loss(loss, loop.amp.amp_state)
        }
        loss = loss / loop.config.gradient_accumulation_steps
        autograd.backward(loss)
        total_loss = total_loss + loss
    }
    if loop.config.enable_zero {
        zero.zero_reduce_scatter_grads(loop.zero_state, loop.model.parameters())
    }
    if loop.config.max_grad_norm > 0 {
        autograd.clip_grad_norm(loop.model.parameters(), loop.config.max_grad_norm)
    }
    bool success = true
    if loop.config.enable_amp {
        success = training.amp_step(loop.amp)
    }
    if success {
        loop.state.lr = compute_lr(loop)
        loop.optimizer = opt.adamw_step(loop.optimizer, loop.state.lr)
        if loop.config.enable_zero {
            zero.zero_all_gather_params(loop.zero_state, loop.model.parameters())
        }
    }
    loop.state.step = loop.state.step + 1
    loop.state.global_step = loop.state.global_step + 1
    loop.state.samples_processed = loop.state.samples_processed + len(batch)
    total_loss
}
func validate_step(training_loop loop, []autograd.tensor batch, []int labels) float {
    autograd.disable_grad()
    []autograd.tensor logits = loop.model.forward(batch)
    float loss = loss.cross_entropy_loss(logits, labels)
    autograd.enable_grad()
    loss
}
func run_epoch(training_loop loop, func get_train_batch, func get_val_batch) training_loop {
    loop.state.epoch = loop.state.epoch + 1
    float epoch_loss = 0.0
    int num_batches = 0
    while loop.state.step < loop.config.total_steps / loop.config.epochs {
        []autograd.tensor batch, []int labels = get_train_batch()
        float loss = train_step(loop, batch, labels)
        epoch_loss = epoch_loss + loss
        num_batches = num_batches + 1
        if loop.state.global_step % loop.config.logging_interval == 0 {
            float ppl = exp(loss)
            print_training_log(loop, loss, ppl)
        }
        if loop.state.global_step % loop.config.eval_interval == 0 {
            loop = validate(loop, get_val_batch)
        }
        if loop.state.global_step % loop.config.save_interval == 0 {
            loop.checkpoint_manager = checkpoint_training.checkpoint_save(
                loop.checkpoint_manager,
                loop.model,
                loop.optimizer,
                loss,
            )
        }
    }
    loop.state.avg_loss = epoch_loss / num_batches
    loop.stats.train_loss.push(loop.state.avg_loss)
    loop.stats.train_ppl.push(exp(loop.state.avg_loss))
    loop.stats.learning_rates.push(loop.state.lr)
    loop
}
func validate(training_loop loop, func get_val_batch) training_loop {
    float val_loss = 0.0
    int num_batches = 0
    for i := 0; i < 100; i += 1 {
        []autograd.tensor batch, []int labels = get_val_batch()
        float loss = validate_step(loop, batch, labels)
        val_loss = val_loss + loss
        num_batches = num_batches + 1
    }
    val_loss = val_loss / num_batches
    float val_ppl = exp(val_loss)
    loop.stats.val_loss.push(val_loss)
    loop.stats.val_ppl.push(val_ppl)
    if val_loss < loop.state.best_val_loss {
        loop.state.best_val_loss = val_loss
        loop.checkpoint_manager = checkpoint_training.checkpoint_save(
            loop.checkpoint_manager,
            loop.model,
            loop.optimizer,
            val_loss,
        )
    }
    print_validation_log(loop, val_loss, val_ppl)
    loop
}
func run_training(training_loop loop, func get_train_batch, func get_val_batch) training_loop {
    for epoch := 0; epoch < loop.config.epochs; epoch += 1 {
        loop = run_epoch(loop, get_train_batch, get_val_batch)
        if !loop.state.is_training {
            break
        }
    }
    loop.checkpoint_manager = checkpoint_training.checkpoint_save_final(
        loop.checkpoint_manager,
        loop.model,
        loop.optimizer,
        loop.state.loss,
    )
    loop
}
func print_training_log(training_loop loop, float loss, float ppl) {
    string log = "[TRAIN] Epoch: " + string(loop.state.epoch) +
                 " Step: " + string(loop.state.global_step) +
                 " Loss: " + string(format_float(loss, 6)) +
                 " PPL: " + string(format_float(ppl, 4)) +
                 " LR: " + string(format_float(loop.state.lr, 8))
    print(log)
}
func print_validation_log(training_loop loop, float loss, float ppl) {
    string log = "[VALID] Epoch: " + string(loop.state.epoch) +
                 " Step: " + string(loop.state.global_step) +
                 " Loss: " + string(format_float(loss, 6)) +
                 " PPL: " + string(format_float(ppl, 4)) +
                 " Best: " + string(format_float(loop.state.best_val_loss, 6))
    print(log)
}
func format_float(float x, int decimals) string {
    string s = string(x)
    int dot_pos = 0
    for i := 0; i < len(s); i += 1 {
        if s[i] == '.' {
            dot_pos = i
            break
        }
    }
    if dot_pos == 0 {
        return s + "." + string(make_string(decimals, '0'))
    }
    int needed = dot_pos + decimals + 1
    if len(s) < needed {
        return s + make_string(needed - len(s), '0')
    }
    s[0..needed]
}
func make_string(int n, char c) string {
    string s = ""
    for i := 0; i < n; i += 1 {
        s = s + c
    }
    s
}
func exp(float x) float {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    float term = 1.0
    float result = 1.0
    int i = 1
    while i <= 12 {
        term = term * x / (i * 1.0)
        result = result + term
        i = i + 1
    }
    result
}
func cos(float x) float {
    float term = 1.0
    float result = 1.0
    int i = 1
    while i <= 10 {
        int sign = if i % 2 == 0 { 1 } else { -1 }
        float fact = 1.0
        int j = 1
        while j <= 2*i {
            fact = fact * j * 1.0
            j = j + 1
        }
        term = sign * pow(x, 2*i) / fact
        result = result + term
        i = i + 1
    }
    result
}
func pow(float x, int n) float {
    float result = 1.0
    for i := 0; i < n; i += 1 {
        result = result * x
    }
    result
}
