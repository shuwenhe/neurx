#include "agent/Planner.h"
#include <QJsonDocument>

void Planner::setSystemPrompt(const QString &prompt)
{
    m_systemPrompt = prompt;
}

void Planner::setMaxTokens(int tokens)
{
    m_maxTokens = tokens;
}

void Planner::setTemperature(float temperature)
{
    m_temperature = temperature;
}

QJsonArray Planner::buildTools(const QString &providerId, const AgentToolRegistry *registry) const
{
    if (!registry) {
        qWarning() << "[Planner] No registry provided, cannot build tools";
        return {};
    }
    
    // List all available tools
    auto tools_list = registry->allTools();
    qDebug() << "[Planner] Registry has" << tools_list.size() << "tools:";
    for (const auto *tool : tools_list) {
        qDebug() << "  -" << tool->name();
    }
    
    QJsonArray tools;
    if (providerId == "openai") {
        tools = registry->toOpenAISchema();
        qDebug() << "[Planner] Built OpenAI schema with" << tools.size() << "tools";
    } else if (providerId == "gemini") {
        tools = registry->toGeminiSchema();
        qDebug() << "[Planner] Built Gemini schema with" << tools.size() << "tools";
    } else if (providerId == "anthropic") {
        tools = registry->toAnthropicSchema();
        qDebug() << "[Planner] Built Anthropic schema with" << tools.size() << "tools";
    }
    
    qDebug() << "[Planner] Built" << tools.size() << "tools for provider:" << providerId;
    return tools;
}

// ── context budget helpers ────────────────────────────────────────────────────

int Planner::estimateTokens(const AgentMessage &msg)
{
    // Rough heuristic: 1 token ≈ 4 characters.
    int chars = msg.content.length();
    // Include tool call content in estimate.
    for (const auto &tc : msg.toolCalls)
        chars += tc.name.length()
               + QJsonDocument(tc.arguments).toJson(QJsonDocument::Compact).length();
    return chars / 4 + 4;  // +4 overhead per message.
}

// Keep the first message of the history and trim from the middle outward so
// that the total estimate stays within budgetTokens.
QList<AgentMessage> Planner::trimToContextBudget(
    const QList<AgentMessage> &history, int budgetTokens)
{
    if (history.isEmpty() || budgetTokens <= 0)
        return history;

    // Compute total cost.
    int total = 0;
    for (const auto &m : history) total += estimateTokens(m);
    if (total <= budgetTokens) return history;

    // Always keep the last N messages (most recent context) and the first message.
    // Drop messages from the older middle of the conversation.
    QList<AgentMessage> trimmed;
    trimmed.reserve(history.size());

    // Start by collecting tail messages until budget is full.
    int used = 0;
    int tail = history.size() - 1;

    // Reserve space for the first message.
    const int firstCost = estimateTokens(history.first());
    budgetTokens -= firstCost;

    // Walk backwards to find how many tail messages fit.
    while (tail >= 1) {
        const int cost = estimateTokens(history.at(tail));
        if (used + cost > budgetTokens) break;
        used += cost;
        --tail;
    }

    // The messages we keep: [0] + [tail+1 .. end]
    trimmed.append(history.first());
    if (tail + 1 < history.size() && tail >= 1) {
        // Add a placeholder so the model knows context was trimmed.
        AgentMessage placeholder;
        placeholder.role    = MessageRole::User;
        placeholder.content = QStringLiteral(
            "[%1 earlier messages omitted to stay within context window]")
            .arg(tail);
        trimmed.append(placeholder);
    }
    for (int i = qMax(1, tail + 1); i < history.size(); ++i)
        trimmed.append(history.at(i));

    return trimmed;
}

ProviderLLMRequest Planner::buildRequest(const QList<AgentMessage> &history,
                                         const QString &model,
                                         const QString &providerId,
                                         const AgentToolRegistry *registry) const
{
    ProviderLLMRequest req;
    req.model        = model;
    req.messages     = (m_contextBudget > 0)
                       ? trimToContextBudget(history, m_contextBudget)
                       : history;
    req.temperature  = m_temperature;
    req.maxTokens    = m_maxTokens;

    if (!m_systemPrompt.isEmpty()) {
        AgentMessage sys;
        sys.role    = MessageRole::System;
        sys.content = m_systemPrompt;
        req.messages.prepend(sys);
    }

    req.tools = buildTools(providerId, registry);
    return req;
}
