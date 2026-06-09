#include "PlanModeTools.h"
#include <QJsonArray>

// ── EnterPlanModeTool ────────────────────────────────────────────────────────

EnterPlanModeTool::EnterPlanModeTool(QObject *parent) : BaseTool(parent) {}

QString EnterPlanModeTool::description() const {
    return "Switch to plan mode. In this mode, you should focus on designing a solution, "
           "creating todos, and discussing the approach with the user before making any changes. "
           "You cannot use implementation tools like write_file or run_command while in plan mode.";
}

QJsonObject EnterPlanModeTool::parametersSchema() const {
    QJsonObject schema;
    schema["type"] = "object";
    QJsonObject props;
    props["reason"] = QJsonObject{
        {"type", "string"},
        {"description", "The reason for entering plan mode (e.g., complex task, need for alignment)."}
    };
    schema["properties"] = props;
    return schema;
}

ToolResult EnterPlanModeTool::execute(const QString &callId, const QJsonObject &args) {
    QString reason = args.value("reason").toString();

    // In a real implementation, this would trigger a state change in the AgentEngine.
    emit eventOccurred(callId, {
        {"event", "plan_mode_entered"},
        {"reason", reason}
    });

    return {callId, name(), false, "Entered plan mode. Focus on design and alignment."};
}

// ── ExitPlanModeTool ─────────────────────────────────────────────────────────

ExitPlanModeTool::ExitPlanModeTool(QObject *parent) : BaseTool(parent) {}

QString ExitPlanModeTool::description() const {
    return "Exit plan mode and move to the implementation phase. Use this when you have "
           "a solid plan and are ready to execute it.";
}

QJsonObject ExitPlanModeTool::parametersSchema() const {
    QJsonObject schema;
    schema["type"] = "object";
    return schema;
}

ToolResult ExitPlanModeTool::execute(const QString &callId, const QJsonObject &args) {
    Q_UNUSED(args);

    emit eventOccurred(callId, {
        {"event", "plan_mode_exited"}
    });

    return {callId, name(), false, "Exited plan mode. Starting implementation."};
}

