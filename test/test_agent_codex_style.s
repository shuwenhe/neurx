package neurx.test_agent_codex_style

use neurx.agent.runtime
use neurx.agent.{new_default_agent, new_default_agent_with_model, run_agent_once, agent_current_task, agent_route}
use neurx.agent.tool_registry.{agent_tool_registry_has_enabled}

func main() int {
    string prompt = "fix qml agent bug"

    agent_runtime_state code_state = new_default_agent(prompt)
    code_state = run_agent_once(code_state, prompt)
    if agent_route(code_state) != "code" {
        println("agent did not classify the request as code")
        return 1
    }
    if agent_current_task(code_state) != "plan" {
        println("agent did not advance from analyze to plan")
        return 1
    }

    code_state = run_agent_once(code_state, prompt)
    if agent_current_task(code_state) != "retrieve" {
        println("agent did not advance from plan to retrieve")
        return 1
    }

    string checkpoint_root = "/home/shuwen/shuwen/neurx/artifacts/checkpoints/run_20260518_001"
    agent_runtime_state model_state = new_default_agent_with_model(prompt, checkpoint_root)
    if !agent_tool_registry_has_enabled(model_state.tools, "infer") {
        println("infer tool should be enabled when checkpoint root is set")
        return 1
    }

    model_state = run_agent_once(model_state, prompt)
    model_state = run_agent_once(model_state, prompt)
    model_state = run_agent_once(model_state, prompt)
    if agent_route(model_state) != "code" {
        println("agent route should remain code when checkpoint model is available")
        return 1
    }
    if agent_current_task(model_state) != "infer" {
        println("agent did not advance to infer when checkpoint model is available")
        return 1
    }

    println("agent codex-style routing test passed")
    0
}
