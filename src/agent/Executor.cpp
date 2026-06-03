#include "agent/Executor.h"

void Executor::setToolRegistry(AgentToolRegistry *registry)
{
    m_registry = registry;
}

ToolResult Executor::execute(const ToolCall &call) const
{
    BaseTool *tool = m_registry ? m_registry->tool(call.name) : nullptr;
    if (!tool) {
        return {call.id, call.name, true, "Unknown tool: " + call.name};
    }
    return tool->execute(call.id, call.arguments);
}

