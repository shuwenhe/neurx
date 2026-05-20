package neurx.agent

use neurx.agent.runtime
use neurx.agent.planner
use neurx.agent.memory
use neurx.agent.tool_registry
use neurx.agent.executor
use neurx.agent.trace
use neurx.agent.skill_registry

func new_default_agent(string goal) agent_runtime_state {
    new_agent_runtime_state(goal, "analyze", 8)
}

func new_default_agent_with_model(string goal, string model_path) agent_runtime_state {
    new_agent_runtime_state_with_model(goal, "analyze", 8, model_path)
}

func run_agent(agent_runtime_state state, string input, int max_steps) agent_runtime_state {
    run_agent_steps(state, input, max_steps)
}

func run_agent_with_goal(string goal, string input, int max_steps) agent_runtime_state {
    agent_runtime_state state = new_default_agent(goal)
    run_agent_steps(state, input, max_steps)
}

func run_agent_with_local_model(string goal, string model_path, string input, int max_steps) agent_runtime_state {
    agent_runtime_state state = new_default_agent_with_model(goal, model_path)
    run_agent_steps(state, input, max_steps)
}

func run_agent_with_checkpoint_root(string goal, string checkpoint_path, string input, int max_steps) agent_runtime_state {
    agent_runtime_state state = new_default_agent_with_model(goal, checkpoint_path)
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

func agent_route(agent_runtime_state state) string {
    agent_memory_lookup_result route_result = agent_memory_lookup_short(state.memory, "route")
    if route_result.found {
        return route_result.value
    }
    ""
}

func agent_step_count(agent_runtime_state state) int {
    state.steps
}

func agent_model_path(agent_runtime_state state) string {
    state.model_path
}

func agent_needs_replan(agent_runtime_state state) bool {
    state.plan.needs_replan
}

func agent_trace_entry_count(agent_runtime_state state) int {
    agent_trace_count(state.trace)
}

func agent_trace_entry_last_step(agent_runtime_state state) int {
    agent_trace_last_step(state.trace)
}

func agent_trace_entry_last_task(agent_runtime_state state) string {
    agent_trace_last_task(state.trace)
}

func agent_trace_entry_last_action(agent_runtime_state state) string {
    agent_trace_last_action(state.trace)
}

func agent_trace_entry_last_observation(agent_runtime_state state) string {
    agent_trace_last_observation(state.trace)
}

func agent_skill_count(agent_runtime_state state) int {
    agent_skill_registry_count(state.skills)
}

func agent_has_skill(agent_runtime_state state, string name) bool {
    agent_skill_registry_has(state.skills, name)
}

func agent_active_skill_name(agent_runtime_state state) string {
    agent_skill_registry_active(state.skills).spec.name
}

func agent_active_skill_status(agent_runtime_state state) string {
    agent_skill_registry_active(state.skills).spec.status
}

func agent_state_dict(agent_runtime_state state) agent_runtime_state {
    state
}

func agent_load_state_dict(agent_runtime_state state, agent_runtime_state other) agent_runtime_state {
    other
}
