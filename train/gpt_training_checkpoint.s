package neurx.train.gpt_training_checkpoint

// ============================================================================
// GPT Training Checkpoint Bridge
//
// Purpose:
//   Capture and restore the full NeurX GPT training state, including:
//   - model architecture/config
//   - token embedding + position embedding
//   - all transformer layers
//   - final normalization and LM head
//   - AdamW optimizer state
//   - training stage metadata
//
// This is the bridge the older generic checkpoint module is missing.
// ============================================================================

use neurx.model.llm.gpt.{gpt_config, gpt_model, gpt_layer, gpt_output}
use neurx.model.llm.gpt_backward.{gpt_adamw_state}

// Full snapshot of a GPT training run
struct gpt_training_checkpoint {
    gpt_config config
    gpt_model model
    gpt_adamw_state optimizer
    int global_step
    int epoch
    float learning_rate
    float loss
    float best_loss
    string stage_name
    string model_name
    int64 timestamp
}

// Create a checkpoint snapshot from current state
func snapshot_gpt_training_state(
    gpt_model model,
    gpt_adamw_state optimizer,
    int global_step,
    int epoch,
    float learning_rate,
    float loss,
    float best_loss,
    string stage_name,
    string model_name,
    int64 timestamp
) gpt_training_checkpoint {
    gpt_training_checkpoint {
        config: model.config,
        model: model,
        optimizer: optimizer,
        global_step: global_step,
        epoch: epoch,
        learning_rate: learning_rate,
        loss: loss,
        best_loss: best_loss,
        stage_name: stage_name,
        model_name: model_name,
        timestamp: timestamp,
    }
}

// Restore model and optimizer from a snapshot
func restore_gpt_training_state(
    gpt_training_checkpoint ckpt
) (gpt_model, gpt_adamw_state) {
    (ckpt.model, ckpt.optimizer)
}

// Get a human-readable checkpoint label
func gpt_checkpoint_label(gpt_training_checkpoint ckpt) string {
    string label = ckpt.model_name + "|" + ckpt.stage_name + "|step="
    label = label + int_to_string_simple(ckpt.global_step)
    label = label + "|loss=" + float_to_string_simple(ckpt.loss)
    label
}

// Compare checkpoints by loss
func is_better_gpt_checkpoint(gpt_training_checkpoint a, gpt_training_checkpoint b) bool {
    a.loss < b.loss
}

// Simple integer to string conversion
func int_to_string_simple(int value) string {
    if value == 0 {
        return "0"
    }
    bool negative = value < 0
    int current = value
    if negative {
        current = -current
    }
    string text = ""
    while current > 0 {
        int digit = current - (current / 10) * 10
        text = string(digit + 48) + text
        current = current / 10
    }
    if negative {
        text = "-" + text
    }
    text
}

// Simple float to string conversion with 4 decimal places.
// The runtime already uses a light-weight formatting style elsewhere,
// so this keeps checkpoint labels dependency-free.
func float_to_string_simple(float value) string {
    int whole = 0
    float remainder = value
    bool negative = remainder < 0.0
    if negative {
        remainder = -remainder
    }
    while remainder >= 1.0 {
        remainder = remainder - 1.0
        whole = whole + 1
    }

    int frac = 0
    int i = 0
    float scaled = remainder * 10000.0
    while i < 4 {
        frac = frac * 10 + int(scaled)
        scaled = (scaled - int(scaled)) * 10.0
        i = i + 1
    }

    string text = int_to_string_simple(whole) + "."
    int div = 1000
    while div > 0 {
        int digit = frac / div
        text = text + string(digit + 48)
        frac = frac - digit * div
        div = div / 10
    }
    if negative {
        text = "-" + text
    }
    text
}
