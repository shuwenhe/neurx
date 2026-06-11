package neurx.test_agent_skill_evolution

use neurx.agent.{new_default_agent, run_agent_once, agent_skill_count, agent_has_skill, agent_active_skill_name, agent_active_skill_status}

func main() int {
    string prompt = "fix qml agent bug"
    agent_runtime_state state = new_default_agent(prompt)

    state = run_agent_once(state, prompt)
    state = run_agent_once(state, prompt)
    state = run_agent_once(state, prompt)
    state = run_agent_once(state, prompt)

    if agent_skill_count(state) <= 0 {
        println("agent did not synthesize any skill")
        return 1
    }
    if !agent_has_skill(state, "code_verify") {
        println("agent did not synthesize expected code_verify skill")
        return 1
    }
    if agent_active_skill_name(state) != "code_verify" {
        println("agent did not activate synthesized skill")
        return 1
    }
    if agent_active_skill_status(state) != "promoted" {
        println("synthesized skill was not promoted")
        return 1
    }

    println("agent self-evolution skill test passed")
    0
}