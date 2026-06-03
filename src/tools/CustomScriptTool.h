#pragma once
#include "agent/AgentToolRegistry.h"
#include <QProcess>

// ── CustomScriptTool ──────────────────────────────────────────────────────────
//  Allows workspace-local scripts to be registered as tools.
//  The script must provide its own schema or we use a default one.

class CustomScriptTool : public BaseTool {
    Q_OBJECT
public:
    explicit CustomScriptTool(const QString &name, const QString &description,
                            const QString &scriptPath, const QJsonObject &schema,
                            QObject *parent = nullptr);

    QString name()        const override { return m_name; }
    QString description() const override { return m_description; }
    QJsonObject parametersSchema() const override { return m_schema; }
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;

private:
    QString m_name;
    QString m_description;
    QString m_scriptPath;
    QJsonObject m_schema;
};
