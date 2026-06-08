#ifndef GEMINIRGTOOL_H
#define GEMINIRGTOOL_H

#include "agent/AgentToolRegistry.h"
#include <QJsonObject>

class GeminiRgTool : public BaseTool
{
    Q_OBJECT
public:
    explicit GeminiRgTool(QObject *parent = nullptr);
    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

#endif // GEMINIRGTOOL_H

