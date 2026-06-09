#ifndef NEURXSKILLCREATORTOOL_H
#define NEURXSKILLCREATORTOOL_H

#include "agent/AgentToolRegistry.h"
#include "skills/ClaudeSkillManager.h"

// ── NeurxSkillCreatorTool ────────────────────────────────────────────────────
// Ported from gemini-cli/packages/core/src/skills/builtin/skill-creator
// Allows the agent to initialize a new skill scaffolding in a neurx-code project.

class NeurxSkillCreatorTool : public BaseTool {
    Q_OBJECT
public:
    explicit NeurxSkillCreatorTool(ClaudeSkillManager *manager, const QString &workspaceRoot, QObject *parent = nullptr);

    QString name()        const override { return "init_skill"; }
    QString description() const override {
        return "Initialize a new skill scaffolding (SKILL.md, scripts/, references/, assets/) matching the standard engineering patterns.";
    }
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;

private:
    bool ensureDirectoryExists(const QString &dirPath);
    bool writeToFile(const QString &filePath, const QString &content);
    QString titleCase(const QString &name);

    ClaudeSkillManager *m_manager;
    QString m_workspaceRoot;
};

#endif // NEURXSKILLCREATORTOOL_H

