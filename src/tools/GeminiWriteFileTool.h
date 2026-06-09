#ifndef GEMINIWRITEFILETOOL_H
#define GEMINIWRITEFILETOOL_H

#include "agent/AgentToolRegistry.h"
#include <QJsonObject>

class GeminiWriteFileTool : public BaseTool
{
    Q_OBJECT
public:
    explicit GeminiWriteFileTool(const QString &workspaceRoot = QString(), QObject *parent = nullptr);

    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
private:
    QString m_workspaceRoot;
};

#endif // GEMINIWRITEFILETOOL_H
