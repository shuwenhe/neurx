#ifndef GEMINIUPDATETOPICTOOL_H
#define GEMINIUPDATETOPICTOOL_H

#include "agent/AgentToolRegistry.h"
#include <QJsonObject>

class GeminiUpdateTopicTool : public BaseTool
{
    Q_OBJECT
public:
    explicit GeminiUpdateTopicTool(QObject *parent = nullptr);

    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;

signals:
    void topicUpdated(const QString &title, const QString &summary, const QString &strategicIntent);

private:
    QString m_currentTopic;
    QString m_currentIntent;
};

#endif // GEMINIUPDATETOPICTOOL_H

