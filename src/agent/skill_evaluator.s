package neurx.agent.skill_evaluator
use neurx.agent.skill_schema

struct agent_skill_eval_result {
    float score
    bool should_promote
    bool should_retire
    string reason
}

func new_agent_skill_eval_result() agent_skill_eval_result {
    agent_skill_eval_result {
        score: 0.0,
        should_promote: false,
        should_retire: false,
        reason: "pending",
    }
}

func agent_skill_score(agent_skill_record record) float {
    float score = record.metrics.success_rate * 100.0
    score = score + (record.metrics.stability * 25.0)
    score = score - (record.metrics.avg_steps * 2.0)
    score = score - record.metrics.tool_cost
    score
}

func agent_skill_evaluate(agent_skill_record record, float promotion_threshold, float retire_threshold) agent_skill_eval_result {
    float score = agent_skill_score(record)
    bool promote = score >= promotion_threshold
    bool retire = score <= retire_threshold
    string reason = "candidate"
    if promote {
        reason = "promote"
    } else if retire {
        reason = "retire"
    }
    agent_skill_eval_result {
        score: score,
        should_promote: promote,
        should_retire: retire,
        reason: reason,
    }
}

func agent_skill_eval_result_state_dict(agent_skill_eval_result result) agent_skill_eval_result {
    result
}

func agent_skill_eval_result_load_state_dict(agent_skill_eval_result result, agent_skill_eval_result other) agent_skill_eval_result {
    other
}
