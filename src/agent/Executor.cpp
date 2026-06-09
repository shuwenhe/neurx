#include "agent/Executor.h"

void Executor::setToolRegistry(AgentToolRegistry *registry)
{
    m_registry = registry;
}

void Executor::setLLMProvider(LLMProvider *provider)
{
    m_summarizer = ToolSummarizer(provider);
}

ToolResult Executor::execute(const ToolCall &call) const
{
    BaseTool *tool = m_registry ? m_registry->tool(call.name) : nullptr;
    if (!tool) {
        return {call.id, call.name, true, "Unknown tool: " + call.name};
    }
    ToolResult result = tool->execute(call.id, call.arguments);

    // Summarize large output if it's not an error
    if (!result.isError && result.content.length() > 8000) {
        result.content = m_summarizer.summarize(call.name, result.content);
    }

    return result;
}
