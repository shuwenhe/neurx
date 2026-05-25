package neurx.context.context_builder

use neurx.context.context_manager
use neurx.agent.memory

func agent_context_build_from_memory(agent_context_state context, agent_memory_state memory) agent_context_state {
    agent_context_state next = context

    agent_memory_lookup_result goal = agent_memory_lookup(memory, "goal")
    if goal.found && goal.value != "" {
        next = agent_context_append(next, "goal=" + goal.value)
    }

    agent_memory_lookup_result route = agent_memory_lookup(memory, "route")
    if route.found && route.value != "" {
        next = agent_context_append(next, "route=" + route.value)
    }

    agent_memory_lookup_result schema = agent_memory_lookup_long(memory, "last_action_schema")
    if schema.found && schema.value != "" {
        next = agent_context_append(next, "action_schema=" + schema.value)
    }

    agent_memory_lookup_result retrieved = agent_memory_lookup_long(memory, "retrieved")
    if retrieved.found && retrieved.value != "" {
        next = agent_context_append(next, "retrieved=" + retrieved.value)
    }

    agent_memory_lookup_result search = agent_memory_lookup_long(memory, "search_result")
    if search.found && search.value != "" {
        next = agent_context_append(next, "search=" + search.value)
    }

    agent_context_maybe_compress(next)
}

func agent_context_build_summary(agent_context_state context) string {
    "context_builder:" + agent_context_summary(context)
}
