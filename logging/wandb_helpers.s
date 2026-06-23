package neurx.logging

// ============================================================================
// WandB Helper Functions & Training Dashboard
// ============================================================================

// Generate UUID (simplified v4)
func generate_uuid() string {
    // Generate random hex string
    string uuid = ""
    uint64 rng = 42  // Would use crypto RNG in production
    
    for i in 0..32 {
        if i == 8 || i == 12 || i == 16 || i == 20 {
            uuid = uuid + "-"
        }
        
        rng = advance_rng(rng)
        int digit = int(rng % 16)
        
        if digit < 10 {
            uuid = uuid + char_to_string(byte('0' + byte(digit)))
        } else {
            uuid = uuid + char_to_string(byte('a' + byte(digit - 10)))
        }
    }
    
    uuid
}

func advance_rng(uint64 state) uint64 {
    // Simple LCG PRNG
    state = state * 6364136223846793005 + 1442695040888963407
    state
}

// Log configuration to WandB (called once at init)
func log_wandb_config(wandb_run run) {
    if !run.active { return }
    
    println("WandB Config:")
    for key in run.config {
        println("  " + key + ": " + run.config[key])
    }
}

// Flush buffered metrics to WandB server
func flush_wandb(wandb_run *run) {
    if !run.active { return }
    
    // In production: make batched API call with all pending metrics
    run.steps_logged = run.steps_logged + 1
}

// Merge two maps (second takes precedence on conflicts)
func merge_maps(
    map[string]string a,
    map[string]string b
) map[string]string {
    map<string]string result = {}
    
    for key in a { result[key] = a[key] }
    for key in b { result[key] = b[key] }
    
    result
}
