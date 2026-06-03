#pragma once
#include "agent/AgentToolRegistry.h"
#include "skills/ClaudeSkillManager.h"

// ── SkillTool ────────────────────────────────────────────────────────────────
//  Allows the agent to explicitly consult a specialized skill's instructions.
//  Matches Claude's progressive disclosure (Level 2).

class SkillTool : public BaseTool {
    Q_OBJECT
public:
    explicit SkillTool(ClaudeSkillManager *manager, QObject *parent = nullptr);

    QString name()        const override { return "use_skill"; }
    QString description() const override {
        return "Retrieve the full instructions and guidelines for a specific acquired skill. "
               "Use this when a task matches a skill's description to see detailed engineering patterns.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;

private:
    ClaudeSkillManager *m_manager;
};
