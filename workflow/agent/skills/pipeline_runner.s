package neurx.workflows.agent.skills.pipeline_runner
use neurx.train.skill_evolution
use neurx.agent.skill_feedback

func workflow_skill_feedback(string skill_name, string task, string signal, string summary, int step, bool success) agent_skill_feedback_state {
    agent_skill_feedback_state {
        skill_name: skill_name,
        task: task,
        signal: signal,
        summary: summary,
        step: step,
        success: success,
    }
}

func run_agent_skills_workflow_state(int max_generations, float promotion_threshold, float retire_threshold, float min_success_rate, int max_avg_steps) skill_evolution_state {
    skill_evolution_config config = new_skill_evolution_config(max_generations, promotion_threshold, retire_threshold, min_success_rate, max_avg_steps)
    skill_evolution_state state = new_skill_evolution_state(config)
    state = skill_evolution_collect(state, workflow_skill_feedback("repo", "verify", "verify", "task=verify action=verify observation=verified:route=repo;plan_ok=true;retrieved_ok=true", 1, true))
    state = skill_evolution_step(state, workflow_skill_feedback("repo", "verify", "verify", "task=verify action=verify observation=verified:route=repo;plan_ok=true;retrieved_ok=true", 1, true))
    state = skill_evolution_collect(state, workflow_skill_feedback("sql", "verify", "verify", "task=verify action=verify observation=verified:route=sql;plan_ok=true;retrieved_ok=true;schema_context=true", 2, true))
    state = skill_evolution_step(state, workflow_skill_feedback("sql", "verify", "verify", "task=verify action=verify observation=verified:route=sql;plan_ok=true;retrieved_ok=true;schema_context=true", 2, true))
    state = skill_evolution_collect(state, workflow_skill_feedback("code", "infer", "infer:tool_unavailable", "task=infer action=infer observation=tool_unavailable", 3, false))
    state = skill_evolution_step(state, workflow_skill_feedback("code", "infer", "infer:tool_unavailable", "task=infer action=infer observation=tool_unavailable", 3, false))
    state
}

func run_agent_skills_workflow(int max_generations, float promotion_threshold, float retire_threshold, float min_success_rate, int max_avg_steps, string output_dir) int {
    skill_evolution_state state = run_agent_skills_workflow_state(max_generations, promotion_threshold, retire_threshold, min_success_rate, max_avg_steps)
    string report_path = output_dir + "/candidate_report.txt"
    string snapshot_path = output_dir + "/registry_snapshot.txt"
    skill_evolution_persist_candidate_report(state, report_path)
    skill_evolution_persist_registry_snapshot(state, snapshot_path)
    println("workflow=agent_skills")
    println("output_dir=" + output_dir)
    println("candidate_report=" + report_path)
    println("registry_snapshot=" + snapshot_path)
    println(skill_evolution_candidate_report(state))
    0
}
