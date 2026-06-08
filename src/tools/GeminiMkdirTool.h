#ifndef GEMINIMKDIRTOOL_H
#define GEMINIMKDIRTOOL_H

#include "agent/AgentToolRegistry.h"
#include <QJsonObject>

class GeminiMkdirTool : public BaseTool
{
    Q_OBJECT
public:
    explicit GeminiMkdirTool(QObject *parent = nullptr);
    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

#endif // GEMINIMKDIRTOOL_H

