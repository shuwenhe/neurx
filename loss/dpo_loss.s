package neurx.loss.dpo_loss
func exp_approx(float x) float {
    float x2 = x * x
    float x3 = x2 * x
    float x4 = x3 * x
    float x5 = x4 * x
    1.0 + x + (x2 / 2.0) + (x3 / 6.0) + (x4 / 24.0) + (x5 / 120.0)
}

func dpo_sigmoid(float x) float {
    float e = exp_approx(0.0 - x)
    1.0 / (1.0 + e)
}

func dpo_margin(float chosen_logp, float rejected_logp, float ref_chosen_logp, float ref_rejected_logp, float beta) float {
    float policy_gap = chosen_logp - rejected_logp
    float reference_gap = ref_chosen_logp - ref_rejected_logp
    beta * (policy_gap - reference_gap)
}

func dpo_loss_from_margin(float margin, float label_smoothing) float {
    float pref_prob = dpo_sigmoid(margin)
    float positive = 1.0 - pref_prob
    float smooth = label_smoothing * pref_prob
    positive + smooth
}

func dpo_pair_loss(float chosen_logp, float rejected_logp, float ref_chosen_logp, float ref_rejected_logp, float beta, float label_smoothing) float {
    float margin = dpo_margin(chosen_logp, rejected_logp, ref_chosen_logp, ref_rejected_logp, beta)
    dpo_loss_from_margin(margin, label_smoothing)
}

