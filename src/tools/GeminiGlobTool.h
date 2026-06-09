#ifndef GEMINIGLOBTOOL_H
#define GEMINIGLOBTOOL_H

#include "agent/AgentToolRegistry.h"
#include <QJsonObject>

class GeminiGlobTool : public BaseTool
{
    Q_OBJECT
public:
    explicit GeminiGlobTool(QObject *parent = nullptr);

    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

#endif // GEMINIGLOBTOOL_H

