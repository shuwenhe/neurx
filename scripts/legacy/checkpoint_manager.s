#!/usr/bin/env s

// ============================================
// NeurX Checkpoint Management Framework
// Purpose: Save, validate, and restore training checkpoints
// Language: S
// ============================================

package main

import (
    "io/ioutil"
    "os"
    "path/filepath"
    "encoding/json"
    "crypto/sha256"
    "time"
)

// CheckpointMetadata stores checkpoint information
type CheckpointMetadata struct {
    step: int
    epoch: int
    timestamp: string
    loss: float
    perplexity: float
    learning_rate: float
    optimizer_state: map[string]interface{}
    model_hash: string
    config_hash: string
}

// CheckpointManager handles checkpoint operations
type CheckpointManager struct {
    checkpoint_dir: string
    max_checkpoints: int
    checkpoints: []CheckpointMetadata
}

// Initialize checkpoint manager
func (cm *CheckpointManager) init(checkpoint_dir: string, max_checkpoints: int) error {
    cm.checkpoint_dir = checkpoint_dir
    cm.max_checkpoints = max_checkpoints
    cm.checkpoints = make([]CheckpointMetadata, 0)
    
    // Create directory if not exists
    if err := os.MkdirAll(checkpoint_dir, 0755); err != nil {
        return err
    }
    
    return nil
}

// Save checkpoint
func (cm *CheckpointManager) save_checkpoint(
    step: int,
    epoch: int,
    model_state: map[string]interface{},
    optimizer_state: map[string]interface{},
    config: map[string]interface{},
    loss: float,
    perplexity: float,
    learning_rate: float) error {
    
    // Create checkpoint directory
    checkpoint_name := "checkpoint-" + format_int(step)
    checkpoint_path := filepath.Join(cm.checkpoint_dir, checkpoint_name)
    
    if err := os.MkdirAll(checkpoint_path, 0755); err != nil {
        return err
    }
    
    // Save model state
    model_json, _ := json.Marshal(model_state)
    if err := ioutil.WriteFile(
        filepath.Join(checkpoint_path, "model_state.json"),
        model_json,
        0644); err != nil {
        return err
    }
    
    // Save optimizer state
    optimizer_json, _ := json.Marshal(optimizer_state)
    if err := ioutil.WriteFile(
        filepath.Join(checkpoint_path, "optimizer_state.json"),
        optimizer_json,
        0644); err != nil {
        return err
    }
    
    // Save config
    config_json, _ := json.Marshal(config)
    if err := ioutil.WriteFile(
        filepath.Join(checkpoint_path, "config.json"),
        config_json,
        0644); err != nil {
        return err
    }
    
    // Create metadata
    metadata := CheckpointMetadata{
        step: step,
        epoch: epoch,
        timestamp: time.Now().Format("2006-01-02T15:04:05Z"),
        loss: loss,
        perplexity: perplexity,
        learning_rate: learning_rate,
        optimizer_state: optimizer_state,
        model_hash: compute_hash(model_json),
        config_hash: compute_hash(config_json),
    }
    
    // Save metadata
    metadata_json, _ := json.Marshal(metadata)
    if err := ioutil.WriteFile(
        filepath.Join(checkpoint_path, "metadata.json"),
        metadata_json,
        0644); err != nil {
        return err
    }
    
    cm.checkpoints = append(cm.checkpoints, metadata)
    
    // Clean old checkpoints if exceeding limit
    cm.cleanup_old_checkpoints()
    
    return nil
}

// Load latest checkpoint
func (cm *CheckpointManager) load_latest(): (map[string]interface{}, error) {
    if len(cm.checkpoints) == 0 {
        return nil, error("No checkpoints available")
    }
    
    latest := cm.checkpoints[len(cm.checkpoints)-1]
    return cm.load_checkpoint(latest.step)
}

// Load specific checkpoint by step
func (cm *CheckpointManager) load_checkpoint(step: int): (map[string]interface{}, error) {
    checkpoint_name := "checkpoint-" + format_int(step)
    checkpoint_path := filepath.Join(cm.checkpoint_dir, checkpoint_name)
    
    // Check if directory exists
    if _, err := os.Stat(checkpoint_path); os.IsNotExist(err) {
        return nil, error("Checkpoint not found: " + checkpoint_name)
    }
    
    // Load metadata
    metadata_path := filepath.Join(checkpoint_path, "metadata.json")
    metadata_bytes, _ := ioutil.ReadFile(metadata_path)
    var metadata CheckpointMetadata
    json.Unmarshal(metadata_bytes, &metadata)
    
    // Validate checkpoint integrity
    if err := cm.validate_checkpoint(checkpoint_path, metadata); err != nil {
        return nil, err
    }
    
    // Load model state
    model_path := filepath.Join(checkpoint_path, "model_state.json")
    model_bytes, _ := ioutil.ReadFile(model_path)
    var model_state map[string]interface{}
    json.Unmarshal(model_bytes, &model_state)
    
    // Load optimizer state
    optimizer_path := filepath.Join(checkpoint_path, "optimizer_state.json")
    optimizer_bytes, _ := ioutil.ReadFile(optimizer_path)
    var optimizer_state map[string]interface{}
    json.Unmarshal(optimizer_bytes, &optimizer_state)
    
    // Return combined state
    return map[string]interface{}{
        "metadata": metadata,
        "model_state": model_state,
        "optimizer_state": optimizer_state,
    }, nil
}

// Validate checkpoint integrity
func (cm *CheckpointManager) validate_checkpoint(
    checkpoint_path: string,
    metadata: CheckpointMetadata) error {
    
    // Load and verify model state
    model_path := filepath.Join(checkpoint_path, "model_state.json")
    model_bytes, err := ioutil.ReadFile(model_path)
    if err != nil {
        return error("Failed to read model state")
    }
    
    if compute_hash(model_bytes) != metadata.model_hash {
        return error("Model state hash mismatch")
    }
    
    // Load and verify config
    config_path := filepath.Join(checkpoint_path, "config.json")
    config_bytes, err := ioutil.ReadFile(config_path)
    if err != nil {
        return error("Failed to read config")
    }
    
    if compute_hash(config_bytes) != metadata.config_hash {
        return error("Config hash mismatch")
    }
    
    return nil
}

// List all available checkpoints
func (cm *CheckpointManager) list_checkpoints(): []map[string]interface{} {
    result := make([]map[string]interface{}, len(cm.checkpoints))
    
    for i, metadata := range cm.checkpoints {
        result[i] = map[string]interface{}{
            "step": metadata.step,
            "epoch": metadata.epoch,
            "timestamp": metadata.timestamp,
            "loss": metadata.loss,
            "perplexity": metadata.perplexity,
            "learning_rate": metadata.learning_rate,
        }
    }
    
    return result
}

// Get checkpoint by step
func (cm *CheckpointManager) get_checkpoint_info(step: int): map[string]interface{} {
    for _, metadata := range cm.checkpoints {
        if metadata.step == step {
            return map[string]interface{}{
                "step": metadata.step,
                "epoch": metadata.epoch,
                "timestamp": metadata.timestamp,
                "loss": metadata.loss,
                "perplexity": metadata.perplexity,
                "learning_rate": metadata.learning_rate,
                "model_hash": metadata.model_hash,
            }
        }
    }
    return nil
}

// Clean up old checkpoints
func (cm *CheckpointManager) cleanup_old_checkpoints() error {
    if len(cm.checkpoints) <= cm.max_checkpoints {
        return nil
    }
    
    // Keep only the last max_checkpoints checkpoints
    num_to_delete := len(cm.checkpoints) - cm.max_checkpoints
    
    for i := 0; i < num_to_delete; i++ {
        checkpoint_name := "checkpoint-" + format_int(cm.checkpoints[i].step)
        checkpoint_path := filepath.Join(cm.checkpoint_dir, checkpoint_name)
        
        if err := os.RemoveAll(checkpoint_path); err != nil {
            return err
        }
    }
    
    // Update checkpoints list
    cm.checkpoints = cm.checkpoints[num_to_delete:]
    
    return nil
}

// Export checkpoint statistics
func (cm *CheckpointManager) export_stats(): string {
    if len(cm.checkpoints) == 0 {
        return "No checkpoints available"
    }
    
    stats := map[string]interface{}{
        "total_checkpoints": len(cm.checkpoints),
        "checkpoint_dir": cm.checkpoint_dir,
        "max_checkpoints": cm.max_checkpoints,
        "latest_step": cm.checkpoints[len(cm.checkpoints)-1].step,
        "latest_perplexity": cm.checkpoints[len(cm.checkpoints)-1].perplexity,
        "best_perplexity": cm.get_best_perplexity(),
        "checkpoints": cm.list_checkpoints(),
    }
    
    json_bytes, _ := json.Marshal(stats)
    return string(json_bytes)
}

// Get best checkpoint (lowest perplexity)
func (cm *CheckpointManager) get_best_perplexity(): float {
    if len(cm.checkpoints) == 0 {
        return 0.0
    }
    
    best := cm.checkpoints[0].perplexity
    for _, metadata := range cm.checkpoints {
        if metadata.perplexity < best {
            best = metadata.perplexity
        }
    }
    
    return best
}

// Helper functions
func compute_hash(data: []byte): string {
    h := sha256.Sum256(data)
    return fmt.Sprintf("%x", h)
}

func format_int(i: int): string {
    return fmt.Sprintf("%d", i)
}

// Example main function
func main() {
    // Initialize checkpoint manager
    cm := &CheckpointManager{}
    if err := cm.init("./checkpoints", 5); err != nil {
        println("Error initializing checkpoint manager:", err.Error())
        return
    }
    
    // Example: Save checkpoints
    for step := 100; step <= 500; step += 100 {
        model_state := map[string]interface{}{
            "weights": "model_weights_data",
            "biases": "model_biases_data",
        }
        
        optimizer_state := map[string]interface{}{
            "adam_m": "first_moment_data",
            "adam_v": "second_moment_data",
        }
        
        config := map[string]interface{}{
            "hidden_dim": 768,
            "num_layers": 12,
        }
        
        loss := 5.0 - float(step/100)*0.5
        ppl := math.Exp(loss)
        lr := 5e-4
        
        err := cm.save_checkpoint(
            step, 1, model_state, optimizer_state, config, loss, ppl, lr)
        
        if err != nil {
            println("Error saving checkpoint:", err.Error())
        } else {
            println("✓ Saved checkpoint at step", step)
        }
    }
    
    // Print checkpoint statistics
    println("\n" + cm.export_stats())
}
