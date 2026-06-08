#ifndef GEMINISTATFILETOOL_H
#define GEMINISTATFILETOOL_H

#include "agent/AgentToolRegistry.h"
#include <QJsonObject>

class GeminiStatFileTool : public BaseTool
{
    Q_OBJECT
public:
    explicit GeminiStatFileTool(QObject *parent = nullptr);
    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

#endif // GEMINISTATFILETOOL_H

