#ifndef GEMINIASKUSERTOOL_H
#define GEMINIASKUSERTOOL_H

#include "agent/AgentToolRegistry.h"
#include <QJsonObject>
#include <QJsonArray>

class GeminiAskUserTool : public BaseTool
{
    Q_OBJECT
public:
    explicit GeminiAskUserTool(QObject *parent = nullptr);

    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;

signals:
    void questionsAsked(const QJsonArray &questions, const QString &callId);
};

#endif // GEMINIASKUSERTOOL_H

