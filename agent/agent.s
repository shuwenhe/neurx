package neurx.agent

use neurx.agent.runtime
use neurx.agent.planner
use neurx.agent.memory
use neurx.agent.tool_registry
use neurx.agent.executor

func new_default_agent(string goal) agent_runtime_state {
    new_agent_runtime_state(goal, "analyze", 8)
}

func run_agent(agent_runtime_state state, string input, int max_steps) agent_runtime_state {
    run_agent_steps(state, input, max_steps)
}

func run_agent_with_goal(string goal, string input, int max_steps) agent_runtime_state {
    agent_runtime_state state = new_default_agent(goal)
    run_agent_steps(state, input, max_steps)
}

func run_agent_once(agent_runtime_state state, string input) agent_runtime_state {
    agent_runtime_step(state, input)
}

func agent_finished(agent_runtime_state state) bool {
    state.finished
}

func agent_last_observation(agent_runtime_state state) string {
    state.last_observation
}

func agent_status(agent_runtime_state state) string {
    state.plan.status
}

func agent_current_task(agent_runtime_state state) string {
    state.plan.current_task
}

func agent_step_count(agent_runtime_state state) int {
    state.steps
}

func agent_needs_replan(agent_runtime_state state) bool {
    state.plan.needs_replan
}

func agent_state_dict(agent_runtime_state state) agent_runtime_state {
    state
}

func agent_load_state_dict(agent_runtime_state state, agent_runtime_state other) agent_runtime_state {
    other
}
