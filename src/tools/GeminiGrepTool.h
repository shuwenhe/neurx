#ifndef GEMINIGREPTOOL_H
#define GEMINIGREPTOOL_H

#include "agent/AgentToolRegistry.h"
#include <QJsonObject>

class GeminiGrepTool : public BaseTool
{
    Q_OBJECT
public:
    explicit GeminiGrepTool(QObject *parent = nullptr);
    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

#endif // GEMINIGREPTOOL_H

