package neurx.test_agent_checkpoint_path

use neurx.agent.runtime
use neurx.agent.{new_default_agent_with_model, agent_model_path}
use neurx.agent.tool_registry.{agent_tool_registry_has_enabled}

func main() int {
    string checkpoint_root = "/home/shuwen/shuwen/neurx/artifacts/checkpoints/run_20260518_001"
    agent_runtime_state state = new_default_agent_with_model("inspect checkpoint", checkpoint_root)

    if agent_model_path(state) != checkpoint_root {
        println("agent did not preserve checkpoint root")
        return 1
    }
    if !agent_tool_registry_has_enabled(state.tools, "infer") {
        println("infer tool should be enabled when checkpoint root is set")
        return 1
    }

    println("agent checkpoint selection test passed")
    0
}
