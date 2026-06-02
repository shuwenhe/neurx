#pragma once
#include "agent/ToolRegistry.h"
#include "agent/AgentEngine.h"

// ── DelegationTool ───────────────────────────────────────────────────────────
//  Allows the parent agent to spawn a recursive sub-agent for a specific task.
//  The sub-agent runs its own thought loop and returns a summary.

class DelegationTool : public BaseTool {
    Q_OBJECT
public:
    explicit DelegationTool(ToolRegistry *registry, LLMProvider *provider,
                           const QString &model, QObject *parent = nullptr);

    QString name()        const override { return "delegate_task"; }
    QString description() const override {
        return "Spawn a specialized sub-agent to handle a specific, well-defined sub-task. "
               "The sub-agent will use the same tools and model as the parent. "
               "Use this to offload tasks like 'write unit tests for file X' or 'fix lint errors'.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

private:
    ToolRegistry *m_registry;
    LLMProvider  *m_provider;
    QString       m_model;
};
