package main

// ============================================================================
// Tiny Transformer Training - Real Training Loop
// Real transformer model with proper backward pass and optimizer updates
// ============================================================================

import fmt
import os
import math
import neurx.model
import neurx.runtime.io

// ============================================================================
// CONFIGURATION
// ============================================================================

struct TrainConfig {
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

func get_default_config() TrainConfig {
    TrainConfig{
        vocab_size: 256,         // Start small: 256 token vocabulary
        embed_dim: 64,           // Small embedding dimension
        hidden_dim: 256,         // Small hidden dimension (4x embed_dim)
        num_layers: 2,           // Just 2 layers
        seq_len: 32,             // Short sequences
        num_heads: 4,            // 4 attention heads
        
        learning_rate: 0.001,
        batch_size: 4,
        num_epochs: 1,           // Start with 1 epoch
        log_interval: 10,        // Log every 10 steps
    }
}

// ============================================================================
// DATA LOADING
// ============================================================================

func load_shard_data(shard_path: string) ([]int, error) {
    // Try to read shard file - returns token sequences
    content, err := os.ReadFile(shard_path)
    if err != nil {
        nil, err
    }
    
    // Convert bytes to tokens (simple: byte -> token ID)
    tokens := make([]int, 0)
    for i := 0; i < len(content); i += 1 {
        tokens = append(tokens, int(content[i]) % 256)  // Keep in vocab range
    }
    
    tokens, nil
}

func create_batches(tokens: []int, seq_len: int, batch_size: int) ([][]int, [][]int) {
    // Split tokens into input/target pairs with given sequence length
    inputs := make([][]int, 0)
    targets := make([][]int, 0)
    
    for i := 0; i + seq_len < len(tokens); i += seq_len {
        // Create one batch of input and target sequences
        input_batch := make([]int, 0)
        target_batch := make([]int, 0)
        
        for b := 0; b < batch_size && i + (b+1) * seq_len < len(tokens); b += 1 {
            for s := 0; s < seq_len; s += 1 {
                token_idx := i + b * seq_len + s
                if token_idx < len(tokens) - 1 {
                    input_batch = append(input_batch, tokens[token_idx])
                    target_batch = append(target_batch, tokens[token_idx + 1])
                }
            }
        }
        
        if len(input_batch) > 0 {
            inputs = append(inputs, input_batch)
            targets = append(targets, target_batch)
        }
    }
    
    inputs, targets
}

// ============================================================================
// MAIN TRAINING LOOP
// ============================================================================

func main() {
    config := get_default_config()
    
    fmt.Printf("[STARTUP] initializing tiny transformer training\n", true)
    
    // Initialize model
    model := neurx.model.create_mini_transformer(
        config.vocab_size,
        config.embed_dim,
        config.hidden_dim,
        config.num_layers,
        config.seq_len,
        config.num_heads,
    )
    
    fmt.Printf("[PROGRESS] model created - params: %d\n", model.param_count, true)
    
    // Initialize optimizer state
    opt_state := neurx.model.AdamW_State{
        m_states: make(map[string]neurx.model.Tensor),
        v_states: make(map[string]neurx.model.Tensor),
        t: 0,
    }
    
    // Find and load shards
    shard_dir := "./data/shards/"
    shards, err := os.ReadDir(shard_dir)
    if err != nil {
        fmt.Printf("[ERROR] failed to read shard directory: %v\n", err, true)
        os.Exit(1)
    }
    
    fmt.Printf("[PROGRESS] found %d shards\n", len(shards), true)
    
    total_steps := 0
    total_loss := 0.0
    
    // Main training loop
    for epoch := 0; epoch < config.num_epochs; epoch += 1 {
        fmt.Printf("[Epoch %d/%d] starting\n", epoch + 1, config.num_epochs, true)
        
        for shard_idx := 0; shard_idx < len(shards); shard_idx += 1 {
            shard_entry := shards[shard_idx]
            shard_path := shard_dir + shard_entry.Name()
            
            fmt.Printf("[Slice %d/%d] %s", shard_idx + 1, len(shards), shard_entry.Name(), true)
            fmt.Printf(" | loading\n", true)
            
            // Load shard data
            tokens, err := load_shard_data(shard_path)
            if err != nil {
                fmt.Printf("[WARN] failed to load %s: %v\n", shard_path, err, true)
                continue
            }
            
            // Create batches from this shard
            inputs, targets := create_batches(tokens, config.seq_len, config.batch_size)
            
            // Process batches
            for batch_idx := 0; batch_idx < len(inputs); batch_idx += 1 {
                input_batch := inputs[batch_idx]
                target_batch := targets[batch_idx]
                batch_size := len(input_batch) / config.seq_len
                
                // Forward pass
                logits := forward(model, input_batch, batch_size, config.seq_len)
                
                // Compute loss
                loss := compute_cross_entropy_loss(logits, target_batch, batch_size, config.seq_len, config.vocab_size)
                
                // Backward pass - compute gradients
                gradients := compute_gradients(
                    model,
                    logits,
                    target_batch,
                    batch_size,
                    config.seq_len,
                )
                
                // Update parameters
                adamw_update(
                    &model,
                    gradients,
                    &opt_state,
                    config.learning_rate,
                    0.9,      // beta1
                    0.999,    // beta2
                    1e-8,     // epsilon
                    0.01,     // weight_decay
                )
                
                total_steps += 1
                total_loss += loss
                
                // Log progress
                if total_steps % config.log_interval == 0 {
                    avg_loss := total_loss / float(config.log_interval)
                    fmt.Printf("[Step %d] Slice %d/%d: %s | loss=%.6f\n",
                        total_steps,
                        shard_idx + 1,
                        len(shards),
                        shard_entry.Name(),
                        avg_loss,
                        true,
                    )
                    total_loss = 0.0
                }
            }
            
            fmt.Printf("[✓ Complete] Slice %d/%d: %s\n", shard_idx + 1, len(shards), shard_entry.Name(), true)
        }
    }
    
    fmt.Printf("[✓ Complete] training finished\n", true)
    fmt.Printf("Total steps: %d\n", total_steps, true)
}
