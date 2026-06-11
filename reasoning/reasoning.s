package neurx.reasoning.reasoning

use neurx.agent.observation

struct agent_reasoning_step {
    int index
    string thought
    string conclusion
}

struct agent_reasoning_state {
    []agent_reasoning_step steps
    int count
    string scratchpad
    bool chain_complete
}

func new_agent_reasoning_step(int index, string thought, string conclusion) agent_reasoning_step {
    agent_reasoning_step {
        index: index,
        thought: thought,
        conclusion: conclusion,
    }
}

func new_agent_reasoning_state() agent_reasoning_state {
    agent_reasoning_state {
        steps: [],
        count: 0,
        scratchpad: "",
        chain_complete: false,
    }
}

func agent_reasoning_append(agent_reasoning_state state, string thought, string conclusion) agent_reasoning_state {
    int n = state.count
    []agent_reasoning_step steps = []agent_reasoning_step{cap: n + 1}
    int i = 0
    while i < n {
        steps[i] = state.steps[i]
        i = i + 1
    }
    steps[n] = new_agent_reasoning_step(n, thought, conclusion)
    string new_scratch = state.scratchpad
    if new_scratch != "" {
        new_scratch = new_scratch + "\n"
    }
    new_scratch = new_scratch + "thought[" + string(n) + "]: " + thought + " => " + conclusion
    agent_reasoning_state {
        steps: steps,
        count: n + 1,
        scratchpad: new_scratch,
        chain_complete: state.chain_complete,
    }
}

func agent_reasoning_conclude(agent_reasoning_state state, string final_conclusion) agent_reasoning_state {
    agent_reasoning_state updated = agent_reasoning_append(state, "final", final_conclusion)
    agent_reasoning_state {
        steps: updated.steps,
        count: updated.count,
        scratchpad: updated.scratchpad,
        chain_complete: true,
    }
}

func agent_reasoning_for_goal(agent_reasoning_state state, string goal, string observation) agent_reasoning_state {
    string thought1 = "goal=" + goal
    string concl1 = "observation=" + observation
    agent_reasoning_state s1 = agent_reasoning_append(state, thought1, concl1)

    string thought2 = "assess_progress"
    string concl2 = "ok"
    if agent_observation_requires_replan(observation) {
        concl2 = "blocked"
    } else if agent_observation_is_no_progress(observation) {
        concl2 = "no_progress"
    }
    agent_reasoning_append(s1, thought2, concl2)
}

func agent_reasoning_last_conclusion(agent_reasoning_state state) string {
    if state.count <= 0 {
        return ""
    }
    state.steps[state.count - 1].conclusion
}

func agent_reasoning_export(agent_reasoning_state state) string {
    state.scratchpad
}
