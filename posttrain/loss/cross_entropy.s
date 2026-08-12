package neurx.posttrain.loss.cross_entropy
use neurx.posttrain.model.model_loader.{fill_model_tensor}

struct loss_batch_result {
    float total_loss
    float avg_loss
    []float loss_per_sample
    []float loss_per_token
    int num_samples
    int num_tokens
}

func softmax([]float logits) []float {
    []float softmax_probs = fill_model_tensor(len(logits), 0.0)
    float max_logit = logits[0]
    int i = 0
    while i < len(logits) {
        if logits[i] > max_logit {
            max_logit = logits[i]
        }
        i = i + 1
    }
    float sum_exp = 0.0
    i = 0
    while i < len(logits) {
        float exp_logit = exp(logits[i] - max_logit)
        softmax_probs[i] = exp_logit
        sum_exp = sum_exp + exp_logit
        i = i + 1
    }
    if sum_exp > 0.0 {
        i = 0
        while i < len(softmax_probs) {
            softmax_probs[i] = softmax_probs[i] / sum_exp
            i = i + 1
        }
    }
    return softmax_probs
}

func cross_entropy_loss_single([]float logits, int target_id) float {
    if target_id < 0 || target_id >= len(logits) {
        return 0.0
    }
    []float probs = softmax(logits)
    float target_prob = probs[target_id]
    if target_prob <= 0.0 {
        target_prob = 1e-10
    }
    return 0.0 - log(target_prob)
}

func cross_entropy_loss_batch([][]float logits_batch, []int target_ids) loss_batch_result {
    loss_batch_result result
    result.loss_per_sample = []float{}
    result.loss_per_token = []float{}
    result.num_samples = len(logits_batch)
    result.num_tokens = len(target_ids)
    result.total_loss = 0.0
    int i = 0
    while i < len(logits_batch) && i < len(target_ids) {
        float token_loss = cross_entropy_loss_single(logits_batch[i], target_ids[i])
        result.loss_per_token.push(token_loss)
        result.total_loss = result.total_loss + token_loss
        i = i + 1
    }
    if result.num_tokens > 0 {
        result.avg_loss = result.total_loss / ((result.num_tokens as float))
    }
    return result
}

func cross_entropy_loss_with_ignore_index([][]float logits_batch, []int target_ids, int ignore_index) loss_batch_result {
    loss_batch_result result
    result.loss_per_token = []float{}
    result.num_tokens = 0
    result.total_loss = 0.0
    int i = 0
    while i < len(logits_batch) && i < len(target_ids) {
        if target_ids[i] != ignore_index {
            float token_loss = cross_entropy_loss_single(logits_batch[i], target_ids[i])
            result.loss_per_token.push(token_loss)
            result.total_loss = result.total_loss + token_loss
            result.num_tokens = result.num_tokens + 1
        }
        i = i + 1
    }
    if result.num_tokens > 0 {
        result.avg_loss = result.total_loss / ((result.num_tokens as float))
    }
    return result
}

func label_smoothing_cross_entropy([][]float logits_batch, []int target_ids, float smoothing) loss_batch_result {
    loss_batch_result result
    result.loss_per_token = []float{}
    result.num_tokens = len(target_ids)
    result.total_loss = 0.0
    int vocab_size = len(logits_batch[0])
    float target_prob = 1.0 - smoothing
    float smooth_prob = smoothing / ((vocab_size as float))
    int i = 0
    while i < len(logits_batch) && i < len(target_ids) {
        []float probs = softmax(logits_batch[i])
        float loss = 0.0
        if target_ids[i] >= 0 && target_ids[i] < len(probs) {
            loss = 0.0 - log(probs[target_ids[i]] * target_prob + smooth_prob)
        }
        result.loss_per_token.push(loss)
        result.total_loss = result.total_loss + loss
        i = i + 1
    }
    if result.num_tokens > 0 {
        result.avg_loss = result.total_loss / ((result.num_tokens as float))
    }
    return result
}

func compute_perplexity(loss_batch_result loss_result) float {
    if loss_result.avg_loss < 0.0 {
        return 0.0
    }
    return exp(loss_result.avg_loss)
}

func compute_token_accuracy([][]float logits_batch, []int target_ids) float {
    if len(logits_batch) == 0 || len(target_ids) == 0 {
        return 0.0
    }
    int correct = 0
    int i = 0
    while i < len(logits_batch) && i < len(target_ids) {
        float max_logit = logits_batch[i][0]
        int predicted_id = 0
        int j = 1
        while j < len(logits_batch[i]) {
            if logits_batch[i][j] > max_logit {
                max_logit = logits_batch[i][j]
                predicted_id = j
            }
            j = j + 1
        }
        if predicted_id == target_ids[i] {
            correct = correct + 1
        }
        i = i + 1
    }
    return ((correct as float)) / ((len(logits_batch) as float))
}

