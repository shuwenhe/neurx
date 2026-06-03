#pragma once
#include "agent/AgentMessage.h"
#include "agent/AgentToolRegistry.h"

// ── Executor ─────────────────────────────────────────────────────────────────
//  Executes resolved tool calls against the registered tools.

class Executor {
public:
    Executor() = default;

    void setToolRegistry(AgentToolRegistry *registry);
    ToolResult execute(const ToolCall &call) const;

private:
    AgentToolRegistry *m_registry{nullptr};
};

