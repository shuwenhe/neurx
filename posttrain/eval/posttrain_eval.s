package neurx.posttrain.eval
struct posttrain_eval_state {
    int last_eval_step
    float reward_score
    float alignment_score
    float safety_score
    bool has_result
}
func new_posttrain_eval_state() posttrain_eval_state {
    posttrain_eval_state {
        last_eval_step: -1,
        reward_score: 0.0,
        alignment_score: 0.0,
        safety_score: 0.0,
        has_result: false,
    }
}
func update_posttrain_eval(posttrain_eval_state state, int step, float reward_score, float alignment_score, float safety_score) posttrain_eval_state {
    posttrain_eval_state {
        last_eval_step: step,
        reward_score: reward_score,
        alignment_score: alignment_score,
        safety_score: safety_score,
        has_result: true,
    }
}
func posttrain_eval_state_dict(posttrain_eval_state state) posttrain_eval_state {
    state
}
func posttrain_eval_load_state_dict(posttrain_eval_state state, posttrain_eval_state other) posttrain_eval_state {
    other
}
