package neurx.test_agent_skill_failure_retire

use neurx.agent.runtime
use neurx.agent.planner
use neurx.agent.{new_default_agent, run_agent_once, agent_skill_status, agent_skill_fail_count}

func force_task(agent_runtime_state state, string task, string model_path) agent_runtime_state {
    agent_runtime_state {
        plan: agent_plan_state {
            goal: state.plan.goal,
            current_task: task,
            step_budget: state.plan.step_budget,
            step_count: state.plan.step_count,
            needs_replan: false,
            finished: false,
            status: "forced:" + task,
        },
        memory: state.memory,
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: false,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: model_path,
    }
}

func main() int {
    string prompt = "fix qml agent bug"
    agent_runtime_state state = new_default_agent(prompt)

    state = run_agent_once(state, prompt)
    state = run_agent_once(state, prompt)
    state = run_agent_once(state, prompt)
    state = run_agent_once(state, prompt)

    if agent_skill_status(state, "code_verify") != "promoted" {
        println("expected code_verify to be promoted before failure retire")
        return 1
    }

    state = force_task(state, "infer", "")
    state = agent_runtime_step(state, prompt)
    if agent_skill_status(state, "code_verify") == "retired" {
        println("skill retired too early after one failure")
        return 1
    }
    if agent_skill_fail_count(state, "code_verify") != 1 {
        println("skill fail_count did not increment after first failure")
        return 1
    }

    state = force_task(state, "infer", "")
    state = agent_runtime_step(state, prompt)
    if agent_skill_status(state, "code_verify") != "retired" {
        println("skill was not retired after repeated failure")
        return 1
    }
    if agent_skill_fail_count(state, "code_verify") < 2 {
        println("skill fail_count did not reach retire threshold")
        return 1
    }

    println("agent failure-driven retire test passed")
    0
}