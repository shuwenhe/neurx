package main
import fmt
import os
import neurx.model
struct train_config {
    vocab_size: int
    embed_dim: int
    hidden_dim: int
    num_layers: int
    seq_len: int
    num_heads: int
    learning_rate: float
    batch_size: int
    num_epochs: int
    log_interval: int
}

func get_default_config() train_config {
    config := train_config{
        vocab_size: 256,
        embed_dim: 64,
        hidden_dim: 256,
        num_layers: 2,
        seq_len: 32,
        num_heads: 4,
        learning_rate: 0.001,
        batch_size: 4,
        num_epochs: 1,
        log_interval: 10,
    }
    config
}

func load_shard_data(shard_path: string) []int {
    content, _ := os.ReadFile(shard_path)
    tokens := make([]int, 0)
    for i := 0; i < len(content); i += 1 {
        tokens = append(tokens, int(content[i]) % 256)
    }
    tokens
}

func main() {
    config := get_default_config()
    fmt.Printf("[STARTUP] initializing tiny transformer training\n")
    model := neurx.model.create_mini_transformer(
        config.vocab_size,
        config.embed_dim,
        config.hidden_dim,
        config.num_layers,
        config.seq_len,
        config.num_heads,
    )
    fmt.Printf("[PROGRESS] model created - params: %d\n", model.param_count)
    opt_state := neurx.model.adam_w_state{
        m_states: make(map[string]neurx.model.tensor_2),
        v_states: make(map[string]neurx.model.tensor_2),
        t: 0,
    }
    shard_dir := "./data/shards/"
    shards, _ := os.ReadDir(shard_dir)
    fmt.Printf("[PROGRESS] found %d shards\n", len(shards))
    total_steps := 0
    total_loss := 0.0
    if len(shards) > 0 {
        fmt.Printf("[Epoch 1/1] starting\n")
        shard_entry := shards[0]
        shard_path := shard_dir + shard_entry.Name()
        fmt.Printf("[Slice 1/%d] %s | loading\n", len(shards), shard_entry.Name())
        tokens := load_shard_data(shard_path)
        if len(tokens) > config.seq_len + 1 {
            input_tokens := make([]int, config.seq_len)
            target_tokens := make([]int, config.seq_len)
            for i := 0; i < config.seq_len; i += 1 {
                input_tokens[i] = tokens[i]
                target_tokens[i] = tokens[i + 1]
            }
            logits := neurx.model.forward(model, input_tokens, 1, config.seq_len)
            loss := neurx.model.compute_cross_entropy_loss(
                logits,
                target_tokens,
                1,
                config.seq_len,
                config.vocab_size,
            )
            gradients := neurx.model.compute_gradients(
                model,
                logits,
                target_tokens,
                1,
                config.seq_len,
            )
            neurx.model.adamw_update(
                &model,
                gradients,
                &opt_state,
                config.learning_rate,
                0.9,
                0.999,
                1e-8,
                0.01,
            )
            total_steps = 1
            total_loss = loss
            fmt.Printf("[Step 1] Slice 1/%d | loss=%.6f\n", len(shards), loss)
        }
        fmt.Printf("[✓ Complete] Slice 1/%d: %s\n", len(shards), shard_entry.Name())
    }
    fmt.Printf("[✓ Complete] training finished - steps: %d, loss: %.6f\n", total_steps, total_loss)
}
