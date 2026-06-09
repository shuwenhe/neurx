#ifndef GEMINICOMPLETETASKTOOL_H
#define GEMINICOMPLETETASKTOOL_H

#include "agent/AgentToolRegistry.h"

class GeminiCompleteTaskTool : public BaseTool
{
    Q_OBJECT
public:
    explicit GeminiCompleteTaskTool(QObject *parent = nullptr);

    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;

    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

#endif // GEMINICOMPLETETASKTOOL_H

