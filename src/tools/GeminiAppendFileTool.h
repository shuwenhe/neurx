#ifndef GEMINIAPPENDFILETOOL_H
#define GEMINIAPPENDFILETOOL_H

#include "agent/AgentToolRegistry.h"
#include <QJsonObject>

class GeminiAppendFileTool : public BaseTool
{
    Q_OBJECT
public:
    explicit GeminiAppendFileTool(QObject *parent = nullptr);
    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

#endif // GEMINIAPPENDFILETOOL_H

