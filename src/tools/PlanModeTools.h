#pragma once
#include "agent/AgentToolRegistry.h"

/**
 * @class EnterPlanModeTool
 * @brief Tool to enter "Plan Mode", focusing the agent on design before implementation.
 */
class EnterPlanModeTool : public BaseTool {
    Q_OBJECT
public:
    explicit EnterPlanModeTool(QObject *parent = nullptr);

    QString name() const override { return "enter_plan_mode"; }
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

/**
 * @class ExitPlanModeTool
 * @brief Tool to exit "Plan Mode" and proceed to implementation.
 */
class ExitPlanModeTool : public BaseTool {
    Q_OBJECT
public:
    explicit ExitPlanModeTool(QObject *parent = nullptr);

    QString name() const override { return "exit_plan_mode"; }
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

