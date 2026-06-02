#include "agent/Verifier.h"

bool Verifier::hasToolCalls(const AgentMessage &message) const
{
    return message.hasToolCalls();
}

bool Verifier::turnComplete(const AgentMessage &message) const
{
    return !message.hasToolCalls();
}

