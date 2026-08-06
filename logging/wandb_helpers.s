package neurx.logging

func generate_uuid() string {
    string uuid = ""
    uint64 rng = 42
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
    state = state * 6364136223846793005 + 1442695040888963407
    state
}

func log_wandb_config(wandb_run run) {
    if !run.active { return }
    println("WandB config:")
    for key in run.config {
        println("  " + key + ": " + run.config[key])
    }
}

func flush_wandb(wandb_run *run) {
    if !run.active { return }
    run.steps_logged = run.steps_logged + 1
}

func merge_maps(
    map[string]string a,
    map[string]string b
) map[string]string {
    map<string]string result = {}
    for key in a { result[key] = a[key] }
    for key in b { result[key] = b[key] }
    result
}

