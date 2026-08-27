package neurx.inference.sampling

func select_top_k_beams([]beam_state candidates, int k) []beam_state {
    if len(candidates) <= k {
        return candidates
    }
    for i in 0..k {
        int max_idx = i
        for j in i+1 .. len(candidates) {
            if candidates[j].score > candidates[max_idx].score {
                max_idx = j
            }
        }
        if max_idx != i {
            beam temp = candidates[i]
            candidates[i] = candidates[max_idx]
            candidates[max_idx] = temp
        }
    }
    []beam_state result = []
    for i in 0..k {
        result = append(result, candidates[i])
    }
    result
}

func find_best_beam([]beam_state finished) beam {
    if len(finished) == 0 {
        return beam { token_ids: [], score: -1e10, is_finished: true }
    }
    int best_idx = 0
    float best_score = finished[0].score
    for i in 1..len(finished) {
        if finished[i].score > best_score {
            best_idx = i
            best_score = finished[i].score
        }
    }
    finished[best_idx]
}
