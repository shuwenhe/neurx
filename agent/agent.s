package neurx.agent
use neurx.agent.runtime
use neurx.agent.observation
use neurx.planner
use neurx.agent.memory
use neurx.agent.tool_registry
use neurx.executor.executor
use neurx.agent.trace
use neurx.registry.skill_registry
func new_default_agent(string goal) agent_runtime_state {
    new_agent_runtime_state(goal, "analyze", 8)
}
func new_default_agent_with_model(string goal, string model_path) agent_runtime_state {
    new_agent_runtime_state_with_model(goal, "analyze", 8, model_path)
}
func new_code_agent(string goal, int step_budget) agent_runtime_state {
    new_code_agent_runtime_state(goal, step_budget)
}
func new_code_agent_with_model(string goal, int step_budget, string model_path, string build_command, string test_command) agent_runtime_state {
    new_code_agent_runtime_state_with_model(goal, step_budget, model_path, build_command, test_command)
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
func agent_skill_status(agent_runtime_state state, string name) string {
    agent_skill_registry_get(state.skills, name).spec.status
}
func agent_skill_fail_count(agent_runtime_state state, string name) int {
    agent_skill_registry_get(state.skills, name).fail_count
}
func agent_skill_snapshot(agent_runtime_state state) string {
    agent_runtime_skill_snapshot(state)
}
func agent_trajectory_export(agent_runtime_state state) string {
    agent_runtime_trajectory_export(state)
}
func agent_persist_skill_snapshot(agent_runtime_state state, string path) string {
    agent_runtime_persist_skill_snapshot(state, path)
}
func agent_export_trajectory(agent_runtime_state state, string path) string {
    agent_runtime_export_trajectory(state, path)
}
func agent_replay_trajectory(agent_runtime_state state, string path) agent_runtime_state {
    agent_skill_registry_state replayed = agent_runtime_replay_trajectory(state, path)
    agent_runtime_state {
        plan: state.plan,
        memory: state.memory,
        tools: state.tools,
        trace: state.trace,
        skills: replayed,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_import_skill_snapshot(agent_runtime_state state, string path) agent_runtime_state {
    agent_skill_registry_state imported = agent_runtime_import_skill_snapshot(state, path)
    agent_runtime_state {
        plan: state.plan,
        memory: state.memory,
        tools: state.tools,
        trace: state.trace,
        skills: imported,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_state_dict(agent_runtime_state state) agent_runtime_state {
    state
}
func agent_load_state_dict(agent_runtime_state state, agent_runtime_state other) agent_runtime_state {
    other
}
func agent_set_route(agent_runtime_state state, string route) agent_runtime_state {
    agent_runtime_set_route(state, route)
}
func agent_extend_budget(agent_runtime_state state, int extra) agent_runtime_state {
    agent_runtime_extend_budget(state, extra)
}
func agent_prune_skills(agent_runtime_state state) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: state.memory,
        tools: state.tools,
        trace: state.trace,
        skills: agent_skill_registry_prune(state.skills),
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_trim_trace(agent_runtime_state state, int max_entries) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: state.memory,
        tools: state.tools,
        trace: agent_trace_window(state.trace, max_entries),
        skills: state.skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_persist_memory(agent_runtime_state state, string path) string {
    agent_memory_persist(state.memory, path)
}
func agent_restore_memory(agent_runtime_state state, string path) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: agent_memory_restore(path),
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func run_agent_batch(agent_runtime_state state, []string inputs, int max_steps_per_input) agent_runtime_state {
    run_agent_steps_batch(state, inputs, max_steps_per_input)
}
func agent_replan_count(agent_runtime_state state) int {
    state.plan.replan_count
}
func agent_update_goal(agent_runtime_state state, string new_goal) agent_runtime_state {
    agent_memory_state next_memory = agent_memory_write_short(state.memory, "goal", new_goal)
    next_memory = agent_memory_clear_short(next_memory)
    next_memory = agent_memory_write_short(next_memory, "goal", new_goal)
    agent_runtime_state {
        plan: agent_plan_update_goal(state.plan, new_goal),
        memory: next_memory,
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: false,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_observation_history(agent_runtime_state state, int n) string {
    int size = len(state.trace.observations)
    int start = 0
    if n > 0 && size > n {
        start = size - n
    }
    string out = ""
    int i = start
    while i < size {
        if out != "" {
            out = out + "\n"
        }
        out = out + state.trace.observations[i]
        i = i + 1
    }
    out
}
func agent_clear_short_memory(agent_runtime_state state) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: agent_memory_clear_short(state.memory),
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_clear_long_memory(agent_runtime_state state) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: agent_memory_clear_long(state.memory),
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_fork(agent_runtime_state state) agent_runtime_state {
    state
}
func agent_merge_best(agent_runtime_state a, agent_runtime_state b) agent_runtime_state {
    if a.finished && !b.finished {
        return a
    }
    if b.finished && !a.finished {
        return b
    }
    if a.plan.status == "done" && b.plan.status != "done" {
        return a
    }
    if b.plan.status == "done" && a.plan.status != "done" {
        return b
    }
    if a.steps >= b.steps {
        return a
    }
    b
}
func agent_inject_task_if(agent_runtime_state state, string task, string memory_key, string expected_value) agent_runtime_state {
    agent_memory_lookup_result r = agent_memory_lookup(state.memory, memory_key)
    if !r.found || r.value != expected_value {
        return state
    }
    agent_runtime_state {
        plan: agent_plan_enqueue_task(state.plan, task),
        memory: r.state,
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_budget_remaining(agent_runtime_state state) int {
    int rem = state.plan.step_budget - state.plan.step_count
    if rem < 0 {
        return 0
    }
    rem
}
func agent_budget_exhausted(agent_runtime_state state) bool {
    state.plan.status == "budget_exhausted" || state.plan.step_count >= state.plan.step_budget
}
func agent_reset(agent_runtime_state state) agent_runtime_state {
    new_agent_runtime_state_with_model(state.plan.goal, "analyze", state.plan.step_budget, state.model_path)
}
func agent_reset_with_goal(agent_runtime_state state, string new_goal) agent_runtime_state {
    new_agent_runtime_state_with_model(new_goal, "analyze", state.plan.step_budget, state.model_path)
}
func agent_synthesize_skill(agent_runtime_state state, string task, bool success) agent_runtime_state {
    string route = agent_route(state)
    string skill_name = route + "_" + task
    agent_skill_feedback_state fb = agent_skill_feedback_state {
        skill_name: route,
        task: task,
        signal: task,
        summary: "manual:task=" + task,
        step: state.steps,
        success: success,
    }
    agent_skill_record rec = agent_skill_synthesize(fb)
    agent_skill_registry_state next_skills = agent_skill_registry_upsert(state.skills, rec)
    if success {
        next_skills = agent_skill_registry_record_success(next_skills, skill_name, state.steps, 1)
        agent_skill_eval_result ev = agent_skill_evaluate(agent_skill_registry_get(next_skills, skill_name), 60.0, -20.0)
        if ev.should_promote {
            next_skills = agent_skill_registry_promote(next_skills, skill_name)
        }
        next_skills = agent_skill_registry_activate_best(next_skills)
    }
    agent_runtime_state {
        plan: state.plan,
        memory: state.memory,
        tools: state.tools,
        trace: state.trace,
        skills: next_skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_task_queue_length(agent_runtime_state state) int {
    len(state.plan.task_queue)
}
func agent_task_queue_peek(agent_runtime_state state) string {
    if len(state.plan.task_queue) > 0 {
        return state.plan.task_queue[0]
    }
    ""
}
func agent_task_queue_peek_all(agent_runtime_state state) []string {
    int size = len(state.plan.task_queue)
    []string out = []string{cap: size}
    int i = 0
    while i < size {
        out[i] = state.plan.task_queue[i]
        i = i + 1
    }
    out
}
func agent_trace_last_n_summary(agent_runtime_state state, int n) string {
    int size = len(state.trace.tasks)
    int start = 0
    if n > 0 && size > n {
        start = size - n
    }
    string out = ""
    int i = start
    while i < size {
        if out != "" {
            out = out + "\n"
        }
        string ok_tag = "fail"
        agent_observation_state parsed = agent_observation_parse(state.trace.observations[i])
        if parsed.terminal {
            ok_tag = "done"
        } else if parsed.ok {
            ok_tag = "ok"
        } else if parsed.blocked {
            ok_tag = "blocked"
        } else if parsed.failed {
            ok_tag = "failed"
        } else if parsed.no_progress {
            ok_tag = "no_progress"
        }
        out = out + "[" + string(i) + "] task=" + state.trace.tasks[i] + " action=" + state.trace.actions[i] + " " + ok_tag + " obs=" + state.trace.observations[i]
        i = i + 1
    }
    out
}
func agent_tool_list(agent_runtime_state state) []string {
    agent_tool_registry_enabled_names(state.tools)
}
func agent_tool_summary(agent_runtime_state state) string {
    agent_tool_registry_summary(state.tools)
}
func agent_skill_names(agent_runtime_state state) []string {
    agent_skill_registry_names(state.skills)
}
func agent_skill_success_rate(agent_runtime_state state, string name) float {
    agent_skill_registry_success_rate(state.skills, name)
}
func agent_promoted_skill_names(agent_runtime_state state) []string {
    agent_skill_registry_promoted_names(state.skills)
}
func agent_memory_keys(agent_runtime_state state) []string {
    []string short_k = agent_memory_short_keys(state.memory)
    []string long_k = agent_memory_long_keys(state.memory)
    int s = len(short_k)
    int l = len(long_k)
    []string out = []string{cap: s + l}
    int i = 0
    while i < s {
        out[i] = short_k[i]
        i = i + 1
    }
    while i < s + l {
        out[i] = long_k[i - s]
        i = i + 1
    }
    out
}
func agent_memory_has(agent_runtime_state state, string key) bool {
    agent_memory_has_key(state.memory, key)
}
func agent_memory_write(agent_runtime_state state, string key, string value) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: agent_memory_write_short(state.memory, key, value),
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_memory_read(agent_runtime_state state, string key) string {
    agent_memory_lookup_result r = agent_memory_lookup(state.memory, key)
    r.value
}
func agent_memory_delete(agent_runtime_state state, string key) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: agent_memory_delete(state.memory, key),
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_skill_force_retire(agent_runtime_state state, string name) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: state.memory,
        tools: state.tools,
        trace: state.trace,
        skills: agent_skill_registry_force_retire(state.skills, name),
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_tool_set_retries(agent_runtime_state state, string tool_name, int retries) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: state.memory,
        tools: agent_tool_registry_set_retries(state.tools, tool_name, retries),
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_tool_set_timeout(agent_runtime_state state, string tool_name, int ms) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: state.memory,
        tools: agent_tool_registry_set_timeout(state.tools, tool_name, ms),
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_step_with_task(agent_runtime_state state, string task, string input) agent_runtime_state {
    agent_runtime_step_with_task(state, task, input)
}
func agent_warm_start(string goal, string memory_path, string skill_path, string model_path) agent_runtime_state {
    agent_runtime_warm_start(goal, memory_path, skill_path, model_path)
}
func agent_summary(agent_runtime_state state) string {
    agent_runtime_summary(state)
}
func agent_is_stalled(agent_runtime_state state) bool {
    agent_runtime_is_stalled(state)
}
func agent_trace_clear(agent_runtime_state state) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: state.memory,
        tools: state.tools,
        trace: agent_trace_clear(state.trace),
        skills: state.skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_set_step_budget(agent_runtime_state state, int budget) agent_runtime_state {
    agent_plan_state next_plan = agent_plan_set_budget(state.plan, budget)
    agent_runtime_state {
        plan: next_plan,
        memory: state.memory,
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: next_plan.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_skill_activate(agent_runtime_state state, string name) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: state.memory,
        tools: state.tools,
        trace: state.trace,
        skills: agent_skill_registry_set_active(state.skills, name),
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_checkpoint(agent_runtime_state state, string dir) string {
    agent_runtime_checkpoint(state, dir)
}
func agent_restore_checkpoint(string goal, string dir) agent_runtime_state {
    agent_runtime_restore_checkpoint(goal, dir)
}
func agent_trace_ok_rate(agent_runtime_state state) float {
    agent_trace_ok_rate(state.trace)
}
func agent_trace_filter_task_obs(agent_runtime_state state, string task) []string {
    agent_trace_filter_task_obs(state.trace, task)
}
func agent_skill_avg_steps(agent_runtime_state state, string name) float {
    agent_skill_registry_avg_steps(state.skills, name)
}
func agent_skill_stability(agent_runtime_state state, string name) float {
    agent_skill_registry_stability(state.skills, name)
}
func agent_skill_version(agent_runtime_state state, string name) string {
    agent_skill_registry_version(state.skills, name)
}
func agent_memory_write_long(agent_runtime_state state, string key, string value) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: agent_memory_write_long(state.memory, key, value),
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_tool_add(agent_runtime_state state, string tool_name, int timeout_ms, int retries) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: state.memory,
        tools: agent_tool_registry_add(state.tools, tool_name, true, timeout_ms, retries),
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
func agent_run_until_stalled(agent_runtime_state state, string input, int max_steps) agent_runtime_state {
    agent_runtime_run_until_stalled(state, input, max_steps)
}
func agent_merge_memory(agent_runtime_state state, agent_runtime_state other) agent_runtime_state {
    agent_runtime_merge_memory(state, other)
}
