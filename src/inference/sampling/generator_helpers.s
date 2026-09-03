package neurx.inference
use neurx.inference.sampling.sampling_utils
use neurx.inference.sampling.sampling_utils2
use neurx.inference.sampling.sampling_utils3
use neurx.inference.sampling.sampling_utils4
func greedy_step(
    []float logits,
    sampling_config cfg,
    uint64 rng_state
) (int, uint64) {
    if cfg.do_sample  cfg.temperature > 0.0 {
        return sample_from_softmax(logits, cfg.temperature, rng_state)
    }
    (argmax(logits), rng_state)
}

func extract_generated_part([]int full_ids, int prompt_length) []int {
    int gen_len = len(full_ids) - prompt_length
    if gen_len <= 0 { return [] }
    []int generated = make([]int, gen_len)
    for i in 0..gen_len {
        generated[i] = full_ids[prompt_length + i]
    }
    generated
}

func check_all_finished([]int[] sequences, int eos_id) bool {
    for seq in sequences {
        bool has_eos = false
        for id in seq {
            if id == eos_id {
                has_eos = true
                break
            }
        }
        if !has_eos {
            return false
        }
    }
    true
}

func compute_avg_score([]float[][] all_scores) float {
    if len(all_scores) == 0 { return 0.0 }
    float total = 0.0
    int count = 0
    for seq_scores in all_scores {
        for step_scores in seq_scores {
            for score in step_scores {
                total = total + score
                count = count + 1
            }
        }
    }
    if count > 0 { total / float(count) } else { 0.0 }
}
