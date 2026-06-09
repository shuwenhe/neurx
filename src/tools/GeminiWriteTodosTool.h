#ifndef GEMINIWRITETODOSTOOL_H
#define GEMINIWRITETODOSTOOL_H

#include "agent/AgentToolRegistry.h"
#include <QJsonObject>
#include <QJsonArray>

class GeminiWriteTodosTool : public BaseTool
{
    Q_OBJECT
public:
    explicit GeminiWriteTodosTool(QObject *parent = nullptr);

    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;

signals:
    void todosUpdated(const QJsonArray &todos);
};

#endif // GEMINIWRITETODOSTOOL_H

