#pragma once

#include "agent/AgentToolRegistry.h"

class TodoTool;

class UpdatePlanTool : public BaseTool {
    Q_OBJECT
public:
    explicit UpdatePlanTool(TodoTool *todoTool, QObject *parent = nullptr);

    QString name() const override { return "update_plan"; }
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

private:
    TodoTool *m_todoTool{nullptr};
};
