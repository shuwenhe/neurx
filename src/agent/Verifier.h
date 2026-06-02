#pragma once
#include "agent/AgentMessage.h"

// ── Verifier ─────────────────────────────────────────────────────────────────
//  Decides whether the current turn should continue after a model response.

class Verifier {
public:
    bool hasToolCalls(const AgentMessage &message) const;
    bool turnComplete(const AgentMessage &message) const;
};

