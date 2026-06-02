#pragma once
#include "agent/AgentMessage.h"
#include "agent/ToolRegistry.h"

// ── Executor ─────────────────────────────────────────────────────────────────
//  Executes resolved tool calls against the registered tools.

class Executor {
public:
    Executor() = default;

    void setToolRegistry(ToolRegistry *registry);
    ToolResult execute(const ToolCall &call) const;

private:
    ToolRegistry *m_registry{nullptr};
};

