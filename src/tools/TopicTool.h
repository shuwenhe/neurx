#pragma once
#include "agent/AgentToolRegistry.h"

/**
 * @class TopicTool
 * @brief Tool to update the conversation's topic and strategic intent.
 */
class TopicTool : public BaseTool {
    Q_OBJECT
public:
    explicit TopicTool(QObject *parent = nullptr);

    QString name() const override { return "update_topic"; }
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

