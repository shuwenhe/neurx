#pragma once
#include <QString>
#include "agent/AgentMessage.h"
#include "agent/AgentToolRegistry.h"
#include "llm/LLMProvider.h"

struct AgentEngineConfig;

// ── Planner ──────────────────────────────────────────────────────────────────
//  Builds provider-specific LLM requests for one agent turn.

class Planner {
public:
    Planner() = default;

    void setSystemPrompt(const QString &prompt);
    void setMaxTokens(int tokens);
    void setTemperature(float temperature);
    // Token budget for the context window (history trimming).
    // A value ≤ 0 disables trimming. Default: 100000 tokens.
    void setContextBudget(int tokens) { m_contextBudget = tokens; }

    LLMRequest buildRequest(const QList<AgentMessage> &history,
                            const QString &model,
                            const QString &providerId,
                            const AgentToolRegistry *registry) const;

private:
    QJsonArray buildTools(const QString &providerId, const AgentToolRegistry *registry) const;

    // Returns a trimmed copy of history that fits within budgetTokens.
    // Always keeps the first user message and trims from the middle.
    static QList<AgentMessage> trimToContextBudget(
        const QList<AgentMessage> &history, int budgetTokens);
    static int estimateTokens(const AgentMessage &msg);

    QString m_systemPrompt;
    int     m_maxTokens{8192};
    int     m_contextBudget{100000};
    float   m_temperature{0.0f};
};
