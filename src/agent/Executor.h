#pragma once
#include "agent/AgentMessage.h"
#include "agent/AgentToolRegistry.h"
#include "agent/ToolSummarizer.h"

// ── Executor ─────────────────────────────────────────────────────────────────
//  Executes resolved tool calls against the registered tools.

class Executor {
public:
    Executor() = default;

    void setToolRegistry(AgentToolRegistry *registry);
    void setLLMProvider(LLMProvider *provider);
    ToolResult execute(const ToolCall &call) const;

private:
    AgentToolRegistry *m_registry{nullptr};
    ToolSummarizer m_summarizer;
};
