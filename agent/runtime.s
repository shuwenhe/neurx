package neurx.agent.runtime

use neurx.agent.planner
use neurx.agent.memory
use neurx.agent.tool_registry
use neurx.agent.executor
use neurx.agent.trace
use neurx.agent.skill_registry
use neurx.agent.skill_feedback
use neurx.agent.skill_synthesizer
use neurx.agent.skill_evaluator
use neurx.agent.skill_executor
use neurx.runtime.io.{runtime_env_get, runtime_write_text_file}

struct agent_runtime_state {
    agent_plan_state plan
    agent_memory_state memory
    agent_tool_registry_state tools
    agent_trace_state trace
    agent_skill_registry_state skills
    agent_skill_execution_state skill_execution
    int steps
    bool finished
    string last_action
    string last_observation
    string model_path
}

func trim_or_empty(string value) string {
    string next = trim(value)
    next
}

func resolve_agent_model_path(string model_path) string {
    string direct = trim_or_empty(model_path)
    if direct != "" {
        return direct
    }

    string env_path = trim_or_empty(runtime_env_get("NEURX_AGENT_MODEL_PATH", ""))
    if env_path != "" {
        return env_path
    }

    string env_file = trim_or_empty(runtime_env_get("NEURX_AGENT_CHECKPOINT_FILE", ""))
    if env_file != "" {
        return env_file
    }

    string env_root = trim_or_empty(runtime_env_get("NEURX_AGENT_CHECKPOINT_ROOT", ""))
    if env_root != "" {
        return env_root
    }

    string backend_file = trim_or_empty(runtime_env_get("NEURX_BACKEND_CHECKPOINT_FILE", ""))
    if backend_file != "" {
        return backend_file
    }

    string backend_root = trim_or_empty(runtime_env_get("NEURX_BACKEND_CHECKPOINT_ROOT", ""))
    if backend_root != "" {
        return backend_root
    }

    ""
}

func new_agent_runtime_state(string goal, string initial_task, int step_budget) agent_runtime_state {
    new_agent_runtime_state_with_model(goal, initial_task, step_budget, "")
}

func new_agent_runtime_state_with_model(string goal, string initial_task, int step_budget, string model_path) agent_runtime_state {
    string resolved_model_path = resolve_agent_model_path(model_path)
    agent_tool_registry_state tools = new_agent_tool_registry_state()
    tools = agent_tool_registry_add(tools, "search", true, 5000, 1)
    tools = agent_tool_registry_add(tools, "retrieve", true, 5000, 1)
    if resolved_model_path != "" {
        tools = agent_tool_registry_add(tools, "infer", true, 32000, 1)
    }

    agent_runtime_state {
        plan: new_agent_plan_state(goal, initial_task, step_budget),
        memory: new_agent_memory_state(),
        tools: tools,
        trace: new_agent_trace_state(),
        skills: new_agent_skill_registry_state(),
        skill_execution: new_agent_skill_execution_state(),
        steps: 0,
        finished: false,
        last_action: "",
        last_observation: "",
        model_path: resolved_model_path,
    }
}

func agent_runtime_should_synthesize_skill(agent_skill_feedback_state feedback) bool {
    if !feedback.success {
        return false
    }
    feedback.task == "verify" || feedback.task == "infer" || feedback.task == "finalize"
}

func agent_runtime_retire_failure_threshold() int {
    2
}

func agent_runtime_failed_skill_name(agent_runtime_state state, agent_skill_feedback_state feedback) string {
    string active = trim_or_empty(state.skill_execution.active_skill)
    if active != "" && active != "none" {
        return active
    }
    agent_skill_name_from_feedback(feedback)
}

func agent_runtime_update_skills(agent_runtime_state state, agent_trace_state trace_state, agent_memory_state memory_state) agent_skill_registry_state {
    agent_skill_feedback_state feedback = agent_skill_feedback_from_trace(trace_state, memory_state)
    if feedback.task == "" {
        return state.skills
    }

    string skill_name = agent_skill_name_from_feedback(feedback)
    agent_skill_registry_state next = state.skills

    if agent_runtime_should_synthesize_skill(feedback) {
        agent_skill_record record = agent_skill_synthesize(feedback)
        next = agent_skill_registry_upsert(next, record)
        next = agent_skill_registry_record_success(next, skill_name, feedback.step)
        agent_skill_eval_result eval = agent_skill_evaluate(agent_skill_registry_get(next, skill_name), 60.0, -20.0)
        if eval.should_promote {
            next = agent_skill_registry_promote(next, skill_name)
            next = agent_skill_registry_set_active(next, skill_name)
        }
        return next
    }

    if !feedback.success {
        string failed_skill = agent_runtime_failed_skill_name(state, feedback)
        if agent_skill_registry_has(next, failed_skill) {
            return agent_skill_registry_record_failure(next, failed_skill, feedback.step, agent_runtime_retire_failure_threshold())
        }
    }

    next
}

func agent_runtime_skill_snapshot(agent_runtime_state state) string {
    string out = "steps=" + string(state.steps)
    out = out + "\nfinished=" + state.plan.status
    out = out + "\nlast_action=" + state.last_action
    out = out + "\nlast_observation=" + state.last_observation
    out = out + "\nactive_skill=" + state.skill_execution.active_skill
    out = out + "\nskill_execution_status=" + state.skill_execution.status
    out = out + "\n" + agent_skill_registry_snapshot(state.skills)
    out
}

func agent_runtime_trajectory_export(agent_runtime_state state) string {
    string out = "goal=" + state.plan.goal
    out = out + "\ncurrent_task=" + state.plan.current_task
    out = out + "\nstatus=" + state.plan.status
    out = out + "\nsteps=" + string(state.steps)
    out = out + "\nmodel_path=" + state.model_path
    out = out + "\n" + agent_trace_export(state.trace)
    out = out + "\n" + agent_runtime_skill_snapshot(state)
    out
}

func agent_runtime_persist_skill_snapshot(agent_runtime_state state, string path) string {
    runtime_write_text_file(path, agent_runtime_skill_snapshot(state))
    path
}

func agent_runtime_export_trajectory(agent_runtime_state state, string path) string {
    runtime_write_text_file(path, agent_runtime_trajectory_export(state))
    path
}

func agent_runtime_step(agent_runtime_state state, string input) agent_runtime_state {
    if state.finished {
        return state
    }

    agent_execute_result result = agent_execute_step(state.tools, state.memory, state.plan.goal, state.plan.current_task, input, state.model_path)
    agent_plan_state next_plan = agent_plan_next(state.plan, result.tools, result.memory, result.observation)
    agent_trace_state next_trace = agent_trace_append(
        state.trace,
        state.steps + 1,
        state.plan.current_task,
        input,
        result.action,
        result.observation,
        state.skill_execution.active_skill,
        result.tool_name,
        result.tool_timeout_ms,
        result.tool_retries,
        result.ok,
    )
    agent_runtime_state current = agent_runtime_state {
        plan: state.plan,
        memory: state.memory,
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
    agent_skill_registry_state next_skills = agent_runtime_update_skills(current, next_trace, result.memory)
    agent_skill_execution_state next_skill_execution = agent_skill_execute(next_skills, next_plan.current_task)

    agent_runtime_state {
        plan: next_plan,
        memory: result.memory,
        tools: result.tools,
        trace: next_trace,
        skills: next_skills,
        skill_execution: next_skill_execution,
        steps: state.steps + 1,
        finished: next_plan.finished,
        last_action: result.action,
        last_observation: result.observation,
        model_path: state.model_path,
    }
}

func run_agent_steps(agent_runtime_state state, string input, int max_steps) agent_runtime_state {
    int total = max_steps
    if total < 0 {
        total = 0
    }

    agent_runtime_state current = state
    int i = 0
    while i < total {
        current = agent_runtime_step(current, input)
        if current.finished {
            return current
        }
        i = i + 1
    }

    current
}

func agent_runtime_state_dict(agent_runtime_state state) agent_runtime_state {
    state
}

func agent_runtime_load_state_dict(agent_runtime_state state, agent_runtime_state other) agent_runtime_state {
    other
}
