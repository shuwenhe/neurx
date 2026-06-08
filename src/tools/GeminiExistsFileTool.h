#ifndef GEMINIEXISTSFILETOOL_H
#define GEMINIEXISTSFILETOOL_H

#include "agent/AgentToolRegistry.h"
#include <QJsonObject>

class GeminiExistsFileTool : public BaseTool
{
    Q_OBJECT
public:
    explicit GeminiExistsFileTool(QObject *parent = nullptr);
    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

#endif // GEMINIEXISTSFILETOOL_H

