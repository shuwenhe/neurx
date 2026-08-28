package neurx.transformers_utils.logits_processors.processor_utils
struct logits_processor {
    string processor_type
    float[] logits
    int vocab_size
}

struct processor_result {
    float[] processed_logits
    float[] probabilities
    int[] top_token_ids
    float[] top_token_probs
}

func softmax(float[] logits) float[] {
    float max_logit = logits[0]
    for i = 1; i < len(logits); i = i + 1 {
        if logits[i] > max_logit {
            max_logit = logits[i]
        }
    }
    float[] exp_logits
    float sum_exp = 0.0
    for i = 0; i < len(logits); i = i + 1 {
        float exp_val = exp(logits[i] - max_logit)
        exp_logits.append(exp_val)
        sum_exp = sum_exp + exp_val
    }
    float[] probs
    for i = 0; i < len(exp_logits); i = i + 1 {
        probs.append(exp_logits[i] / sum_exp)
    }
    probs
}

func log_softmax(float[] logits) float[] {
    float max_logit = logits[0]
    for i = 1; i < len(logits); i = i + 1 {
        if logits[i] > max_logit {
            max_logit = logits[i]
        }
    }
    float[] log_probs
    float sum_exp = 0.0
    for i = 0; i < len(logits); i = i + 1 {
        float exp_val = exp(logits[i] - max_logit)
        sum_exp = sum_exp + exp_val
    }
    for i = 0; i < len(logits); i = i + 1 {
        float log_prob = logits[i] - max_logit - log(sum_exp)
        log_probs.append(log_prob)
    }
    log_probs
}

func get_top_k_tokens(
    logits: float[],
    int k
) (int[], float[]) {
    int[] indices
    float[] scores
    for i = 0; i < len(logits); i = i + 1 {
        indices.append(i)
        scores.append(logits[i])
    }
    for i = 0; i < k && i < len(scores); i = i + 1 {
        for j = i + 1; j < len(scores); j = j + 1 {
            if scores[j] > scores[i] {
                float temp_score = scores[i]
                scores[i] = scores[j]
                scores[j] = temp_score
                int temp_idx = indices[i]
                indices[i] = indices[j]
                indices[j] = temp_idx
            }
        }
    }
    int[] top_indices
    float[] top_scores
    for i = 0; i < k && i < len(indices); i = i + 1 {
        top_indices.append(indices[i])
        top_scores.append(scores[i])
    }
    (top_indices, top_scores)
}

func apply_token_mask(
    logits: float[],
    mask: bool[]
) float[] {
    float[] masked_logits
    for i = 0; i < len(logits); i = i + 1 {
        if mask[i] {
            masked_logits.append(logits[i])
        } else {
            masked_logits.append(-1000000.0)
        }
    }
    masked_logits
}

func find_token_index(int token_id, int vocab_size) int {
    if token_id < 0 || token_id >= vocab_size {
        return -1
    }
    token_id
}

func cumulative_softmax(float[] probs) float[] {
    float[] cum_probs
    float cumsum = 0.0
    for i = 0; i < len(probs); i = i + 1 {
        cumsum = cumsum + probs[i]
        cum_probs.append(cumsum)
    }
    cum_probs
}

struct batch_processor_state {
    int batch_size
    float[][] batch_logits
    []processor_result results
}

func create_batch_processor(int batch_size, int vocab_size) batch_processor_state {
    batch_processor_state {
        batch_size: batch_size,
        batch_logits: [],
        results: [],
    }
}

func logits_processor_to_string(logits_processor processor) string {
    string s = ""
    s = s + "Processor: " + processor.processor_type + "\n"
    s = s + "Vocab size: " + int_to_string(processor.vocab_size) + "\n"
    s = s + "Logits size: " + int_to_string(len(processor.logits)) + "\n"
    s
}
