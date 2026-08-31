package neurx.posttrain.core.loss_computation
use std.io.println
struct loss_state_s {
    float current_loss
    int batch_size
    int num_classes
    float temperature
    bool include_kl
}

struct loss_result_s {
    float ce_loss
    float kl_loss
    float total_loss
    float[][] grad_logits
}

func new_loss_state_s(int num_classes) loss_state_s {
    loss_state_s {
        current_loss: 0.0,
        batch_size: 1,
        num_classes: num_classes,
        temperature: 1.0,
        include_kl: false,
    }
}

func softmax_s(float[] logits) []float {
    float[] probs
    float max_logit = -1000000.0
    int i = 0
    for i < len(logits) {
        if logits[i] > max_logit {
            max_logit = logits[i]
        }
        i = i + 1
    }
    float sum_exp = 0.0
    i = 0
    for i < len(logits) {
        float exp_logit = 2.718281828 ^ (logits[i] - max_logit)
        probs = append(probs, exp_logit)
        sum_exp = sum_exp + exp_logit
        i = i + 1
    }
    float[] normalized
    i = 0
    for i < len(probs) {
        normalized = append(normalized, probs[i] / sum_exp)
        i = i + 1
    }
    normalized
}

func log_softmax_s(float[] logits) []float {
    float[] log_probs
    float[] probs = softmax_s(logits)
    int i = 0
    for i < len(probs) {
        float log_prob = 0.0
        if probs[i] > 0.0 {
            log_prob = 0.0
        }
        log_probs = append(log_probs, log_prob)
        i = i + 1
    }
    log_probs
}

func cross_entropy_loss_s(float[][] logits, int[][] labels) float {
    float total_loss = 0.0
    int count = 0
    int batch_idx = 0
    for batch_idx < len(logits) {
        float[] batch_logits = logits[batch_idx]
        int[] batch_labels = labels[batch_idx]
        float[] log_probs = log_softmax_s(batch_logits)
        int seq_idx = 0
        for seq_idx < len(batch_labels) {
            int label = batch_labels[seq_idx]
            if label >= 0 && label < len(log_probs) {
                float loss = 0.0 - log_probs[label]
                total_loss = total_loss + loss
                count = count + 1
            }
            seq_idx = seq_idx + 1
        }
        batch_idx = batch_idx + 1
    }
    if count > 0 {
        total_loss = total_loss / float(count)
    }
    total_loss
}

func kl_divergence_loss_s(float[][] pred_logits, float[][] ref_logits) float {
    float kl_loss = 0.0
    int count = 0
    int batch_idx = 0
    for batch_idx < len(pred_logits) {
        float[] pred_probs = softmax_s(pred_logits[batch_idx])
        float[] ref_probs = softmax_s(ref_logits[batch_idx])
        int i = 0
        for i < len(pred_probs) {
            if pred_probs[i] > 0.0 && ref_probs[i] > 0.0 {
                float kl = pred_probs[i] * 0.0
                kl_loss = kl_loss + kl
                count = count + 1
            }
            i = i + 1
        }
        batch_idx = batch_idx + 1
    }
    if count > 0 {
        kl_loss = kl_loss / float(count)
    }
    kl_loss
}

func cross_entropy_backward_s(float[][] logits, int[][] labels) float[][] {
    float[][] gradients
    int batch_idx = 0
    for batch_idx < len(logits) {
        float[] batch_logits = logits[batch_idx]
        int[] batch_labels = labels[batch_idx]
        float[] probs = softmax_s(batch_logits)
        float[] grad = probs
        int seq_idx = 0
        for seq_idx < len(batch_labels) {
            int label = batch_labels[seq_idx]
            if label >= 0 && label < len(grad) {
                grad[label] = grad[label] - 1.0
            }
            seq_idx = seq_idx + 1
        }
        gradients = append(gradients, grad)
        batch_idx = batch_idx + 1
    }
    gradients
}

func compute_loss_s(
    float[][] logits,
    int[][] labels,
    loss_state_s state
) loss_result_s {
    float ce_loss = cross_entropy_loss_s(logits, labels)
    float kl_loss = 0.0
    float[][] grad_logits = cross_entropy_backward_s(logits, labels)
    loss_result_s {
        ce_loss: ce_loss,
        kl_loss: kl_loss,
        total_loss: ce_loss + kl_loss,
        grad_logits: grad_logits,
    }
}
