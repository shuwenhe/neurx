package neurx.inference.sampling
func apply_repetition_penalty(
    float[] logits,
    int[] generated_ids,
    float penalty
) float[] {
    if penalty == 1.0 || len(generated_ids) == 0 {
        return logits
    }
    float[] penalized = copy_float_array(logits)
    map<int]bool seen = {}
    for id in generated_ids {
        seen[id] = true
    }
    for t in 0..len(logits) {
        if t in seen  seen[t] {
            if logits[t] > 0.0 {
                penalized[t] = logits[t] / penalty
            } else {
                penalized[t] = logits[t] * penalty
            }
        }
    }
    penalized
}

func copy_float_array(float[] arr) float[] {
    float[] copy = float[]{cap: len(arr)}
    for i in 0..len(arr) {
        copy[i] = arr[i]
    }
    copy
}

func compute_length_penalty(int length, float alpha) float {
    float lp = (float(5 + length) / 6.0)
    if abs_float(alpha - 1.0) < 1e-6 {
        return 1.0
    }
    pow_approx(lp, alpha)
}
