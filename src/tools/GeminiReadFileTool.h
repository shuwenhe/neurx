#ifndef GEMINIREADFILETOOL_H
#define GEMINIREADFILETOOL_H

#include "agent/AgentToolRegistry.h"
#include <QJsonObject>

class GeminiReadFileTool : public BaseTool
{
    Q_OBJECT
public:
    explicit GeminiReadFileTool(const QString &workspaceRoot = QString(), QObject *parent = nullptr);

    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
private:
    QString m_workspaceRoot;
};

#endif // GEMINIREADFILETOOL_H
