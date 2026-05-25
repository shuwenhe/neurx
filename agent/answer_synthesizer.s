package neurx.agent.answer_synthesizer

use neurx.agent.trace
use neurx.agent.memory

struct agent_answer_state {
    string goal
    string answer
    string confidence
    string source
    bool ready
    int synthesized_at_step
}

func new_agent_answer_state(string goal) agent_answer_state {
    agent_answer_state {
        goal: goal,
        answer: "",
        confidence: "none",
        source: "",
        ready: false,
        synthesized_at_step: 0,
    }
}

func agent_answer_confidence_from_trace(agent_trace_state trace_state) string {
    int n = trace_state.count
    if n == 0 {
        return "none"
    }
    int ok_count = 0
    int i = 0
    while i < n {
        if trace_state.ok_flags[i] {
            ok_count = ok_count + 1
        }
        i = i + 1
    }
    int ratio = ok_count * 100 / n
    if ratio >= 80 {
        return "high"
    } else if ratio >= 50 {
        return "medium"
    }
    "low"
}

func agent_answer_extract_from_memory(agent_memory_state memory_state) string {
    agent_memory_lookup_result final_result = agent_memory_lookup_long(memory_state, "final_answer")
    if final_result.found && final_result.value != "" {
        return final_result.value
    }
    agent_memory_lookup_result infer_result = agent_memory_lookup_long(memory_state, "inferred_model")
    if infer_result.found && infer_result.value != "" {
        return "infer:" + infer_result.value
    }
    agent_memory_lookup_result analysis_result = agent_memory_lookup_long(memory_state, "analysis")
    if analysis_result.found && analysis_result.value != "" {
        return "analysis:" + analysis_result.value
    }
    ""
}

func agent_answer_synthesize(agent_answer_state state, agent_trace_state trace_state, agent_memory_state memory_state, int step) agent_answer_state {
    string answer = agent_answer_extract_from_memory(memory_state)
    string source = "memory"
    if answer == "" && trace_state.count > 0 {
        answer = agent_trace_last_observation(trace_state)
        source = "trace"
    }
    string confidence = agent_answer_confidence_from_trace(trace_state)
    agent_answer_state {
        goal: state.goal,
        answer: answer,
        confidence: confidence,
        source: source,
        ready: answer != "",
        synthesized_at_step: step,
    }
}

func agent_answer_format(agent_answer_state state) string {
    if !state.ready {
        return "answer_not_ready goal=" + state.goal
    }
    "goal=" + state.goal + "\nanswer=" + state.answer + "\nconfidence=" + state.confidence + "\nsource=" + state.source
}

func agent_answer_summary(agent_answer_state state) string {
    "ready=" + string(state.ready) + " confidence=" + state.confidence + " step=" + string(state.synthesized_at_step)
}
