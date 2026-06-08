#ifndef GEMINILISTFILESTOOL_H
#define GEMINILISTFILESTOOL_H

#include "agent/AgentToolRegistry.h"
#include <QDir>
#include <QJsonObject>

#include <QJsonObject>

class GeminiListFilesTool : public BaseTool
{
    Q_OBJECT
public:
    explicit GeminiListFilesTool(QObject *parent = nullptr);
    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

#endif // GEMINILISTFILESTOOL_H

