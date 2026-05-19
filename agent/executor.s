package neurx.agent.executor

use neurx.agent.tool_registry
use neurx.agent.memory
use neurx.infer

struct agent_execute_result {
    agent_tool_registry_state tools
    agent_memory_state memory
    string action
    string observation
    bool ok
}

func agent_execute_step(agent_tool_registry_state tools, agent_memory_state memory, string task, string input, string model_path) agent_execute_result {
    string action = "noop"
    string observation = "tool_unavailable"
    bool ok = false

    if task == "finalize" {
        action = "finalize"
        observation = "done"
        ok = true
    } else if task == "retrieve" {
        if agent_tool_registry_has_enabled(tools, "retrieve") {
            action = "retrieve"
            observation = "retrieved"
            ok = true
        }
    } else if model_path != "" && agent_tool_registry_has_enabled(tools, "infer") {
        infer_pipeline_state pipeline = new_infer_pipeline_from_checkpoint(input, model_path, 512, 256, 32, 2048)
        action = "infer"
        observation = infer_pipeline_last_observation(pipeline)
        ok = true
    } else {
        if agent_tool_registry_has_enabled(tools, "search") {
            action = "search"
            observation = "analyzed"
            ok = true
        }
    }

    agent_memory_state next_memory = agent_memory_write_short(memory, "last_input", input)
    next_memory = agent_memory_write_short(next_memory, "last_action", action)
    next_memory = agent_memory_write_short(next_memory, "last_observation", observation)

    agent_execute_result {
        tools: tools,
        memory: next_memory,
        action: action,
        observation: observation,
        ok: ok,
    }
}

func agent_execute_result_state_dict(agent_execute_result result) agent_execute_result {
    result
}

func agent_execute_result_load_state_dict(agent_execute_result result, agent_execute_result other) agent_execute_result {
    other
}
