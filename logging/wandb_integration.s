package neurx.logging

// ============================================================================
// Weights & Biases (WandB) Integration
// Cloud-based experiment tracking, visualization, and collaboration
// ============================================================================

// ---- WandB Run State ----
struct wandb_run {
    bool active
    string run_id              // Unique run identifier
    string run_url             // URL to view this run in browser
    string project             // Project name
    string entity              // Username or team
    
    // Configuration logged with this run
    map[string]string config
    
    // Statistics
    int metrics_logged
    int steps_logged
}

// Initialize a new WandB run (or resume existing one)
func init_wandb(
    logger_config cfg,
    map[string]string additional_config  // Hyperparameters, etc.
) wandb_run {
    if !cfg.log_to_wandb { 
        return wandb_run{active: false} 
    }
    
    // Generate run ID (UUID v4 style)
    string run_id = generate_uuid()
    
    wandb_run r {
        active: true,
        run_id: run_id,
        run_url: "https://wandb.ai/" + cfg.wandb_entity + "/" + cfg.wandb_project + "/runs/" + run_id,
        project: cfg.wandb_project,
        entity: cfg.wandb_entity,
        
        // Merge configs: from logger_config + additional_config
        config: merge_maps(cfg.wandb_config, additional_config),
        
        metrics_logged: 0,
        steps_logged: 0,
    }
    
    // Log configuration to WandB server
    log_wandb_config(r)
    
    println("WandB initialized. View at: " + r.run_url)
    
    r
}

// ========================================================================
# LOG METRIC to WANDB
# Sends metric data to WandB cloud service via API call
# ========================================================================

func wandb_log_metric(
    wandb_run *run,
    string name,
    float value,
    int step,
    map<string]string tags
) {
    if !run.active { return }
    
    // Build the payload for WandB API
    map<string]any payload = {}
    payload[name] = value
    payload["_step"] = step
    payload["_timestamp"] = current_time_seconds()
    
    // Add tags as prefix or metadata
    for key in tags {
        payload["tag_" + key] = tags[key]
    }
    
    // In production, this would make an HTTP POST to:
    // POST https://api.wandb.ai/namespace/project/runs/run_id/logs
    // For now, we simulate by printing and storing locally
    
    run.metrics_logged = run.metrics_logged + 1
    
    // Flush periodically (every 100 metrics by default)
    if run.metrics_logged % 100 == 0 {
        flush_wandb(run)
    }
}
