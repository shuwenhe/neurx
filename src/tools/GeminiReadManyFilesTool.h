#ifndef GEMINIREADMANYFILESTOOL_H
#define GEMINIREADMANYFILESTOOL_H

#include "agent/AgentToolRegistry.h"
#include <QJsonObject>

class GeminiReadManyFilesTool : public BaseTool
{
    Q_OBJECT
public:
    explicit GeminiReadManyFilesTool(QObject *parent = nullptr);

    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

#endif // GEMINIREADMANYFILESTOOL_H

