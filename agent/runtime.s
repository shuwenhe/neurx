package neurx.agent.runtime

use neurx.agent.planner
use neurx.agent.memory
use neurx.agent.tool_registry
use neurx.agent.executor.{agent_execute_step, agent_text_contains}
use neurx.agent.trace
use neurx.agent.skill_registry
use neurx.agent.skill_feedback
use neurx.agent.skill_synthesizer
use neurx.agent.skill_evaluator
use neurx.agent.skill_executor
use neurx.agent.reflection
use neurx.agent.context_manager
use neurx.agent.context_builder
use neurx.agent.reasoning
use neurx.agent.subagent
use neurx.agent.perception
use neurx.agent.answer_synthesizer
use neurx.agent.interrupt
use neurx.agent.safety
use neurx.agent.session
use neurx.runtime.io.{runtime_env_get, runtime_write_text_file, runtime_read_text_file, runtime_file_exists}

struct agent_runtime_state {
    agent_plan_state plan
    agent_memory_state memory
    agent_tool_registry_state tools
    agent_trace_state trace
    agent_skill_registry_state skills
    agent_skill_execution_state skill_execution
    agent_reflection_state reflection
    agent_context_state context
    agent_reasoning_state reasoning
    agent_subagent_registry_state subagents
    agent_answer_state answer
    agent_interrupt_state interrupt
    agent_session_state session
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

func s_char_is_digit(string s, int i) bool {
    string ch = string(s[i])
    ch == "0" || ch == "1" || ch == "2" || ch == "3" || ch == "4" || ch == "5" || ch == "6" || ch == "7" || ch == "8" || ch == "9"
}

func s_char_digit_val(string s, int i) int {
    string ch = string(s[i])
    if ch == "1" { return 1 }
    if ch == "2" { return 2 }
    if ch == "3" { return 3 }
    if ch == "4" { return 4 }
    if ch == "5" { return 5 }
    if ch == "6" { return 6 }
    if ch == "7" { return 7 }
    if ch == "8" { return 8 }
    if ch == "9" { return 9 }
    0
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
    tools = agent_tool_registry_add(tools, "write", true, 10000, 1)
    tools = agent_tool_registry_add(tools, "delete", true, 10000, 1)
    tools = agent_tool_registry_add(tools, "apply_patch", true, 10000, 1)
    tools = agent_tool_registry_add(tools, "build", true, 20000, 0)
    tools = agent_tool_registry_add(tools, "test", true, 20000, 0)
    if resolved_model_path != "" {
        tools = agent_tool_registry_add(tools, "infer", true, 32000, 1)
    }

    string session_id = "session_" + string(0)
    agent_runtime_state {
        plan: new_agent_plan_state(goal, initial_task, step_budget),
        memory: new_agent_memory_state(),
        tools: tools,
        trace: new_agent_trace_state(),
        skills: new_agent_skill_registry_state(),
        skill_execution: new_agent_skill_execution_state(),
        reflection: new_agent_reflection_state(),
        context: new_agent_context_state(agent_context_default_max_tokens()),
        reasoning: new_agent_reasoning_state(),
        subagents: new_agent_subagent_registry_state(),
        answer: new_agent_answer_state(goal),
        interrupt: new_agent_interrupt_state(),
        session: new_agent_session_state(session_id, goal),
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
        next = agent_skill_registry_record_success(next, skill_name, feedback.step, state.skill_execution.step_count)
        agent_skill_eval_result eval = agent_skill_evaluate(agent_skill_registry_get(next, skill_name), 60.0, -20.0)
        if eval.should_promote {
            next = agent_skill_registry_promote(next, skill_name)
            next = agent_skill_registry_activate_best(next)
        }
        return next
    }

    if !feedback.success {
        string failed_skill = agent_runtime_failed_skill_name(state, feedback)
        if agent_skill_registry_has(next, failed_skill) {
            agent_skill_record failed_record = agent_skill_registry_get(next, failed_skill)
            bool signal_matched = agent_skill_registry_observation_matches_failure(failed_record, feedback.signal)
            if signal_matched || feedback.signal == "tool_unavailable" {
                agent_skill_registry_state after_failure = agent_skill_registry_record_failure(next, failed_skill, feedback.step, agent_runtime_retire_failure_threshold())
                return agent_skill_registry_activate_best(after_failure)
            }
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
    out = out + "\n" + agent_reflection_summary(state.reflection)
    out = out + "\n" + agent_context_summary(state.context)
    out = out + "\n" + agent_answer_summary(state.answer)
    out = out + "\n" + agent_interrupt_summary(state.interrupt)
    out = out + "\n" + agent_subagent_summary(state.subagents)
    out = out + "\n" + agent_session_summary(state.session)
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

func agent_runtime_make_blocked(agent_runtime_state state, string reason) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: state.memory,
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        reflection: state.reflection,
        context: state.context,
        reasoning: state.reasoning,
        subagents: state.subagents,
        answer: state.answer,
        interrupt: state.interrupt,
        session: state.session,
        steps: state.steps + 1,
        finished: true,
        last_action: "blocked",
        last_observation: "safety:" + reason,
        model_path: state.model_path,
    }
}

func agent_runtime_step(agent_runtime_state state, string input) agent_runtime_state {
    if state.finished {
        return state
    }

    agent_safety_result safety = agent_safety_check(state.plan.current_task, input, state.plan.goal)
    if !safety.allowed {
        return agent_runtime_make_blocked(state, safety.reason)
    }

    agent_session_state next_session = agent_session_user(state.session, input)

    agent_context_state next_context = agent_context_maybe_compress(
        agent_context_append(state.context, input)
    )

    agent_reasoning_state next_reasoning = agent_reasoning_for_goal(
        state.reasoning, state.plan.goal, state.last_observation
    )

    agent_execute_result result = agent_execute_step(state.tools, state.memory, state.plan.goal, state.plan.current_task, input, state.model_path)

    agent_reflection_state next_reflection = agent_reflect(
        state.reflection, state.plan.goal, result.action, result.observation, state.steps + 1
    )

    agent_perception_result perception = agent_perceive(result.observation, "tool")

    agent_plan_state next_plan = agent_plan_next(state.plan, result.tools, result.memory, result.observation)
    if next_reflection.needs_correction && !next_plan.needs_replan {
        next_plan = agent_plan_set_task(next_plan, "analyze")
    }

    agent_memory_state final_memory = result.memory
    if next_plan.needs_replan && next_plan.replan_reason != "" {
        final_memory = agent_memory_write_short(final_memory, "replan_reason", next_plan.replan_reason)
        if next_plan.replan_reason == "tool_unavailable" && result.tool_name != "" {
            next_plan = agent_plan_set_task(next_plan, "analyze")
        }
    }
    if state.plan.current_task == "plan" && result.ok {
        agent_memory_lookup_result pq_result = agent_memory_lookup_long(final_memory, "plan_queue")
        if pq_result.found && pq_result.value != "" {
            final_memory = pq_result.state
            string pq = pq_result.value
            int pq_start = 0
            int pi = 0
            while pi < len(pq) {
                if string(pq[pi]) == "[" {
                    pq_start = pi + 1
                    break
                }
                pi = pi + 1
            }
            int pq_end = len(pq)
            pi = pq_end - 1
            while pi >= 0 {
                if string(pq[pi]) == "]" {
                    pq_end = pi
                    break
                }
                pi = pi - 1
            }
            string token = ""
            pi = pq_start
            while pi <= pq_end {
                bool at_sep = pi == pq_end || string(pq[pi]) == ","
                if at_sep {
                    string t = trim(token)
                    if len(t) > 0 {
                        next_plan = agent_plan_enqueue_task(next_plan, t)
                    }
                    token = ""
                } else {
                    token = token + string(pq[pi])
                }
                pi = pi + 1
            }
        }
    }
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
        result.ok
    )
    agent_tool_registry_state final_tools = result.tools
    if next_plan.needs_replan && next_plan.replan_reason == "tool_unavailable" && result.tool_name != "" {
        final_tools = agent_tool_registry_disable(final_tools, result.tool_name)
    }
    agent_skill_registry_state next_skills = agent_runtime_update_skills(state, next_trace, result.memory)
    agent_skill_execution_state next_skill_execution = agent_skill_execute(next_skills, next_plan.current_task)

    agent_answer_state next_answer = state.answer
    if next_plan.finished {
        next_answer = agent_answer_synthesize(state.answer, next_trace, final_memory, state.steps + 1)
    }

    next_session = agent_session_assistant(next_session, result.observation)
    next_context = agent_context_append(next_context, result.observation)
    next_context = agent_context_build_from_memory(next_context, final_memory)

    agent_runtime_state {
        plan: next_plan,
        memory: final_memory,
        tools: final_tools,
        trace: next_trace,
        skills: next_skills,
        skill_execution: next_skill_execution,
        reflection: next_reflection,
        context: next_context,
        reasoning: next_reasoning,
        subagents: state.subagents,
        answer: next_answer,
        interrupt: state.interrupt,
        session: next_session,
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

func run_agent_steps_batch(agent_runtime_state state, []string inputs, int max_steps_per_input) agent_runtime_state {
    agent_runtime_state current = state
    int ni = 0
    while ni < len(inputs) {
        current = run_agent_steps(current, inputs[ni], max_steps_per_input)
        if current.finished {
            return current
        }
        ni = ni + 1
    }
    current
}

func agent_runtime_replay_line_value(string line) string {
    int eq = 0
    int li = 0
    while li < len(line) {
        if string(line[li]) == "=" {
            eq = li + 1
            break
        }
        li = li + 1
    }
    if eq <= 0 {
        return ""
    }
    int val_len = len(line) - eq
    string val = ""
    int vi = 0
    while vi < val_len {
        val = val + string(line[eq + vi])
        vi = vi + 1
    }
    val
}

func agent_runtime_replay_trajectory(agent_runtime_state state, string path) agent_skill_registry_state {
    if !runtime_file_exists(path) {
        return state.skills
    }
    string content = runtime_read_text_file(path)
    int content_len = len(content)
    agent_skill_registry_state next = state.skills

    string cur_task = ""
    string cur_action = ""
    string cur_obs = ""
    bool cur_ok = false
    string cur_skill = ""
    int cur_step = 0
    string cur_line = ""

    int ci = 0
    while ci <= content_len {
        bool at_end = ci == content_len
        bool at_newline = !at_end && string(content[ci]) == "\n"
        if at_newline || at_end {
            string ln = cur_line
            cur_line = ""
            if len(ln) > 0 {
                string val = agent_runtime_replay_line_value(ln)
                if agent_text_contains(ln, "task[") {
                    cur_task = val
                } else if agent_text_contains(ln, "action[") {
                    cur_action = val
                } else if agent_text_contains(ln, "observation[") {
                    cur_obs = val
                } else if agent_text_contains(ln, "active_skill[") {
                    cur_skill = val
                } else if agent_text_contains(ln, "step[") {
                    int step_val = 0
                    int si = 0
                    while si < len(val) {
                        if s_char_is_digit(val, si) {
                            step_val = step_val * 10 + s_char_digit_val(val, si)
                        }
                        si = si + 1
                    }
                    cur_step = step_val
                } else if agent_text_contains(ln, "ok[") {
                    cur_ok = val == "true"
                    if cur_task != "" && cur_obs != "" {
                        agent_skill_feedback_state fb = agent_skill_feedback_state {
                            skill_name: cur_skill,
                            task: cur_task,
                            signal: cur_action,
                            summary: cur_obs,
                            step: cur_step,
                            success: cur_ok,
                        }
                        bool should_syn = cur_ok && (cur_task == "verify" || cur_task == "infer" || cur_task == "finalize")
                        if should_syn {
                            string sname = agent_skill_name_from_feedback(fb)
                            agent_skill_record rec = agent_skill_synthesize(fb)
                            next = agent_skill_registry_upsert(next, rec)
                            next = agent_skill_registry_record_success(next, sname, cur_step, 1)
                            agent_skill_eval_result ev = agent_skill_evaluate(agent_skill_registry_get(next, sname), 60.0, -20.0)
                            if ev.should_promote {
                                next = agent_skill_registry_promote(next, sname)
                            }
                        }
                        cur_task = ""
                        cur_action = ""
                        cur_obs = ""
                        cur_skill = ""
                        cur_ok = false
                    }
                }
            }
        } else {
            cur_line = cur_line + string(content[ci])
        }
        ci = ci + 1
    }

    agent_skill_registry_activate_best(next)
}

func agent_runtime_import_skill_snapshot(agent_runtime_state state, string path) agent_skill_registry_state {
    if !runtime_file_exists(path) {
        return state.skills
    }
    string content = runtime_read_text_file(path)
    int content_len = len(content)
    agent_skill_registry_state next = state.skills

    string cur_name = ""
    string cur_version = ""
    string cur_intent = ""
    string cur_status = ""
    float cur_success_rate = 0.0
    float cur_stability = 0.0
    float cur_avg_steps = 0.0
    int cur_step = 0
    string cur_line = ""

    int ci = 0
    while ci <= content_len {
        bool at_end = ci == content_len
        bool at_newline = !at_end && string(content[ci]) == "\n"
        if at_newline || at_end {
            string ln = cur_line
            cur_line = ""
            if len(ln) > 0 {
                string val = agent_runtime_replay_line_value(ln)
                if agent_text_contains(ln, ".name=") {
                    cur_name = val
                } else if agent_text_contains(ln, ".version=") {
                    cur_version = val
                } else if agent_text_contains(ln, ".intent=") {
                    cur_intent = val
                } else if agent_text_contains(ln, ".status=") {
                    cur_status = val
                } else if agent_text_contains(ln, ".created_step=") {
                    int sv = 0
                    int si = 0
                    while si < len(val) {
                        if s_char_is_digit(val, si) {
                            sv = sv * 10 + s_char_digit_val(val, si)
                        }
                        si = si + 1
                    }
                    cur_step = sv
                } else if agent_text_contains(ln, ".success_rate=") {
                    float fv = 0.0
                    int si = 0
                    int int_part = 0
                    bool past_dot = false
                    float frac = 0.1
                    while si < len(val) {
                        if s_char_is_digit(val, si) {
                            if past_dot {
                                fv = fv + float(s_char_digit_val(val, si)) * frac
                                frac = frac * 0.1
                            } else {
                                int_part = int_part * 10 + s_char_digit_val(val, si)
                            }
                        } else if string(val[si]) == "." {
                            past_dot = true
                            fv = float(int_part)
                        }
                        si = si + 1
                    }
                    if !past_dot {
                        fv = float(int_part)
                    }
                    cur_success_rate = fv
                } else if agent_text_contains(ln, ".stability=") {
                    float fv = 0.0
                    int si = 0
                    int int_part = 0
                    bool past_dot = false
                    float frac = 0.1
                    while si < len(val) {
                        if s_char_is_digit(val, si) {
                            if past_dot {
                                fv = fv + float(s_char_digit_val(val, si)) * frac
                                frac = frac * 0.1
                            } else {
                                int_part = int_part * 10 + s_char_digit_val(val, si)
                            }
                        } else if string(val[si]) == "." {
                            past_dot = true
                            fv = float(int_part)
                        }
                        si = si + 1
                    }
                    if !past_dot {
                        fv = float(int_part)
                    }
                    cur_stability = fv
                } else if agent_text_contains(ln, ".avg_steps=") {
                    float fv = 0.0
                    int si = 0
                    int int_part = 0
                    bool past_dot = false
                    float frac = 0.1
                    while si < len(val) {
                        if s_char_is_digit(val, si) {
                            if past_dot {
                                fv = fv + float(s_char_digit_val(val, si)) * frac
                                frac = frac * 0.1
                            } else {
                                int_part = int_part * 10 + s_char_digit_val(val, si)
                            }
                        } else if string(val[si]) == "." {
                            past_dot = true
                            fv = float(int_part)
                        }
                        si = si + 1
                    }
                    if !past_dot {
                        fv = float(int_part)
                    }
                    cur_avg_steps = fv
                    if cur_name != "" && cur_status != "" {
                        agent_skill_spec spec = new_agent_skill_spec(cur_name, cur_version, cur_intent, cur_status)
                        agent_skill_metrics metrics = new_agent_skill_metrics()
                        metrics.success_rate = cur_success_rate
                        metrics.stability = cur_stability
                        metrics.avg_steps = cur_avg_steps
                        agent_skill_record record = new_agent_skill_record(spec, metrics, cur_step)
                        next = agent_skill_registry_upsert(next, record)
                        if cur_status == "promoted" || cur_status == "validated" {
                            next = agent_skill_registry_promote(next, cur_name)
                        }
                        cur_name = ""
                        cur_version = ""
                        cur_intent = ""
                        cur_status = ""
                        cur_success_rate = 0.0
                        cur_stability = 0.0
                        cur_avg_steps = 0.0
                        cur_step = 0
                    }
                }
            }
        } else {
            cur_line = cur_line + string(content[ci])
        }
        ci = ci + 1
    }

    agent_skill_registry_activate_best(next)
}

func agent_runtime_state_dict(agent_runtime_state state) agent_runtime_state {
    state
}

func agent_runtime_load_state_dict(agent_runtime_state state, agent_runtime_state other) agent_runtime_state {
    other
}

func agent_runtime_set_route(agent_runtime_state state, string route) agent_runtime_state {
    agent_memory_state next_memory = agent_memory_write_short(state.memory, "route", route)
    agent_plan_state next_plan = agent_plan_set_task(state.plan, "plan")
    agent_runtime_state {
        plan: next_plan,
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

func agent_runtime_extend_budget(agent_runtime_state state, int extra) agent_runtime_state {
    int add = extra
    if add < 0 {
        add = 0
    }
    agent_plan_state next_plan = agent_plan_state {
        goal: state.plan.goal,
        current_task: state.plan.current_task,
        step_budget: state.plan.step_budget + add,
        step_count: state.plan.step_count,
        needs_replan: state.plan.needs_replan,
        finished: false,
        status: "running",
        replan_reason: state.plan.replan_reason,
        task_queue: state.plan.task_queue,
        replan_count: state.plan.replan_count,
    }
    if state.plan.status != "budget_exhausted" {
        next_plan = agent_plan_state {
            goal: state.plan.goal,
            current_task: state.plan.current_task,
            step_budget: state.plan.step_budget + add,
            step_count: state.plan.step_count,
            needs_replan: state.plan.needs_replan,
            finished: false,
            status: state.plan.status,
            replan_reason: state.plan.replan_reason,
            task_queue: state.plan.task_queue,
            replan_count: state.plan.replan_count,
        }
    }
    agent_runtime_state {
        plan: next_plan,
        memory: state.memory,
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        reflection: state.reflection,
        context: state.context,
        reasoning: state.reasoning,
        subagents: state.subagents,
        answer: state.answer,
        interrupt: state.interrupt,
        session: state.session,
        steps: state.steps,
        finished: false,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}

func agent_runtime_with_plan(agent_runtime_state state, agent_plan_state plan) agent_runtime_state {
    agent_runtime_state {
        plan: plan,
        memory: state.memory,
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        reflection: state.reflection,
        context: state.context,
        reasoning: state.reasoning,
        subagents: state.subagents,
        answer: state.answer,
        interrupt: state.interrupt,
        session: state.session,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}

func agent_runtime_with_memory(agent_runtime_state state, agent_memory_state memory) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: memory,
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        reflection: state.reflection,
        context: state.context,
        reasoning: state.reasoning,
        subagents: state.subagents,
        answer: state.answer,
        interrupt: state.interrupt,
        session: state.session,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}

func agent_runtime_with_skills(agent_runtime_state state, agent_skill_registry_state skills) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: state.memory,
        tools: state.tools,
        trace: state.trace,
        skills: skills,
        skill_execution: state.skill_execution,
        reflection: state.reflection,
        context: state.context,
        reasoning: state.reasoning,
        subagents: state.subagents,
        answer: state.answer,
        interrupt: state.interrupt,
        session: state.session,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}

func agent_runtime_step_with_task(agent_runtime_state state, string task, string input) agent_runtime_state {
    agent_plan_state forced_plan = agent_plan_set_task(state.plan, task)
    agent_runtime_step(agent_runtime_with_plan(state, forced_plan), input)
}

func agent_runtime_warm_start(string goal, string memory_path, string skill_path, string model_path) agent_runtime_state {
    agent_runtime_state base = new_agent_runtime_state_with_model(goal, "analyze", 32, model_path)
    agent_memory_state loaded_memory = base.memory
    if memory_path != "" {
        if runtime_file_exists(memory_path) {
            loaded_memory = agent_memory_restore(memory_path)
        }
    }
    agent_runtime_state mid = agent_runtime_with_memory(base, loaded_memory)
    agent_skill_registry_state loaded_skills = mid.skills
    if skill_path != "" {
        if runtime_file_exists(skill_path) {
            loaded_skills = agent_runtime_import_skill_snapshot(mid, skill_path)
        }
    }
    agent_runtime_with_skills(mid, loaded_skills)
}

func agent_runtime_summary(agent_runtime_state state) string {
    string finished_str = "false"
    if state.finished {
        finished_str = "true"
    }
    string out = "goal=" + state.plan.goal
    out = out + "\nstatus=" + state.plan.status
    out = out + "\ntask=" + state.plan.current_task
    out = out + "\nsteps=" + string(state.plan.step_count) + "/" + string(state.plan.step_budget)
    out = out + "\nfinished=" + finished_str
    out = out + "\nskills=" + string(len(state.skills.records))
    out = out + "\ntools=" + string(len(state.tools.tool_names))
    out = out + "\nobs=" + state.last_observation
    out
}

func agent_runtime_is_stalled(agent_runtime_state state) bool {
    int size = len(state.trace.tasks)
    if size < 3 {
        return false
    }
    int start = size - 3
    string ref_task = state.trace.tasks[start]
    int i = start + 1
    while i < size {
        if state.trace.tasks[i] != ref_task {
            return false
        }
        i = i + 1
    }
    i = start
    while i < size {
        if state.trace.ok_flags[i] {
            return false
        }
        i = i + 1
    }
    true
}

func agent_runtime_checkpoint(agent_runtime_state state, string dir) string {
    string mem_path  = dir + "/memory.txt"
    string snap_path = dir + "/snapshot.txt"
    agent_memory_persist(state.memory, mem_path)
    agent_skill_registry_persist(state.skills, snap_path)
    dir
}

func agent_runtime_restore_checkpoint(string goal, string dir) agent_runtime_state {
    agent_runtime_warm_start(goal, dir + "/memory.txt", dir + "/snapshot.txt", "")
}

func agent_runtime_run_until_stalled(agent_runtime_state state, string input, int max_steps) agent_runtime_state {
    agent_runtime_state current = state
    int i = 0
    while i < max_steps {
        if current.finished {
            return current
        }
        if agent_runtime_is_stalled(current) {
            return current
        }
        current = agent_runtime_step(current, input)
        i = i + 1
    }
    current
}

func agent_runtime_merge_memory(agent_runtime_state state, agent_runtime_state other) agent_runtime_state {
    agent_memory_state merged = state.memory
    int si = 0
    while si < len(other.memory.short_keys) {
        merged = agent_memory_write_short(merged, other.memory.short_keys[si], other.memory.short_values[si])
        si = si + 1
    }
    int li = 0
    while li < len(other.memory.long_keys) {
        merged = agent_memory_write_long(merged, other.memory.long_keys[li], other.memory.long_values[li])
        li = li + 1
    }
    agent_runtime_state {
        plan: state.plan,
        memory: merged,
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
