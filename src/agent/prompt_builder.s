package neurx.agent.prompt_builder
use neurx.agent.memory
use neurx.agent.tool_registry
use neurx.reasoning.reasoning

struct agent_prompt_builder_state {
    string system_role
    string goal
    string task
    string memory_summary
    string tools_summary
    string reasoning_chain
    string last_observation
    string extra
}

func new_agent_prompt_builder(string goal, string task) agent_prompt_builder_state {
    agent_prompt_builder_state {
        system_role: "You are a precise AI agent. Think step by step, use available tools, and complete the task.",
        goal: goal,
        task: task,
        memory_summary: "",
        tools_summary: "",
        reasoning_chain: "",
        last_observation: "",
        extra: "",
    }
}

func agent_prompt_with_system(agent_prompt_builder_state b, string role) agent_prompt_builder_state {
    agent_prompt_builder_state {
        system_role: role,
        goal: b.goal,
        task: b.task,
        memory_summary: b.memory_summary,
        tools_summary: b.tools_summary,
        reasoning_chain: b.reasoning_chain,
        last_observation: b.last_observation,
        extra: b.extra,
    }
}

func agent_prompt_with_memory(agent_prompt_builder_state b, agent_memory_state memory) agent_prompt_builder_state {
    agent_prompt_builder_state {
        system_role: b.system_role,
        goal: b.goal,
        task: b.task,
        memory_summary: agent_memory_export(memory),
        tools_summary: b.tools_summary,
        reasoning_chain: b.reasoning_chain,
        last_observation: b.last_observation,
        extra: b.extra,
    }
}

func agent_prompt_with_tools(agent_prompt_builder_state b, agent_tool_registry_state tools) agent_prompt_builder_state {
    agent_prompt_builder_state {
        system_role: b.system_role,
        goal: b.goal,
        task: b.task,
        memory_summary: b.memory_summary,
        tools_summary: agent_tool_registry_summary(tools),
        reasoning_chain: b.reasoning_chain,
        last_observation: b.last_observation,
        extra: b.extra,
    }
}

func agent_prompt_with_reasoning(agent_prompt_builder_state b, agent_reasoning_state reasoning) agent_prompt_builder_state {
    agent_prompt_builder_state {
        system_role: b.system_role,
        goal: b.goal,
        task: b.task,
        memory_summary: b.memory_summary,
        tools_summary: b.tools_summary,
        reasoning_chain: agent_reasoning_export(reasoning),
        last_observation: b.last_observation,
        extra: b.extra,
    }
}

func agent_prompt_with_observation(agent_prompt_builder_state b, string obs) agent_prompt_builder_state {
    agent_prompt_builder_state {
        system_role: b.system_role,
        goal: b.goal,
        task: b.task,
        memory_summary: b.memory_summary,
        tools_summary: b.tools_summary,
        reasoning_chain: b.reasoning_chain,
        last_observation: obs,
        extra: b.extra,
    }
}

func agent_prompt_with_extra(agent_prompt_builder_state b, string extra) agent_prompt_builder_state {
    agent_prompt_builder_state {
        system_role: b.system_role,
        goal: b.goal,
        task: b.task,
        memory_summary: b.memory_summary,
        tools_summary: b.tools_summary,
        reasoning_chain: b.reasoning_chain,
        last_observation: b.last_observation,
        extra: extra,
    }
}

func agent_prompt_build(agent_prompt_builder_state b) string {
    string out = "SYSTEM: " + b.system_role + "\n"
    out = out + "GOAL: " + b.goal + "\n"
    out = out + "TASK: " + b.task + "\n"
    if b.memory_summary != "" {
        out = out + "MEMORY:\n" + b.memory_summary + "\n"
    }
    if b.tools_summary != "" {
        out = out + "TOOLS:\n" + b.tools_summary + "\n"
    }
    if b.reasoning_chain != "" {
        out = out + "REASONING:\n" + b.reasoning_chain + "\n"
    }
    if b.last_observation != "" {
        out = out + "LAST_OBS: " + b.last_observation + "\n"
    }
    if b.extra != "" {
        out = out + b.extra + "\n"
    }
    out + "ACTION:"
}

func agent_prompt_build_system_only(agent_prompt_builder_state b) string {
    b.system_role
}

func agent_prompt_summary(agent_prompt_builder_state b) string {
    string has_mem = "no"
    if b.memory_summary != "" {
        has_mem = "yes"
    }
    string has_tools = "no"
    if b.tools_summary != "" {
        has_tools = "yes"
    }
    "prompt;goal=" + b.goal + ";task=" + b.task + ";has_memory=" + has_mem + ";has_tools=" + has_tools
}
