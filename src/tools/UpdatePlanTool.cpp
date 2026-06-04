#include "tools/UpdatePlanTool.h"

#include "tools/TodoTool.h"

#include <QJsonArray>
#include <QJsonObject>

namespace {

const QStringList kPlanStatuses = {
    QStringLiteral("pending"),
    QStringLiteral("in_progress"),
    QStringLiteral("completed"),
    QStringLiteral("blocked"),
};

QString statusIcon(const QString &status)
{
    if (status == QStringLiteral("completed"))
        return QStringLiteral("✓");
    if (status == QStringLiteral("in_progress"))
        return QStringLiteral("▶");
    if (status == QStringLiteral("blocked"))
        return QStringLiteral("!");
    return QStringLiteral("○");
}

} // namespace

UpdatePlanTool::UpdatePlanTool(TodoTool *todoTool, QObject *parent)
    : BaseTool(parent)
    , m_todoTool(todoTool)
{}

QString UpdatePlanTool::description() const
{
    return QStringLiteral(
        "Update the current task plan with explicit step statuses. "
        "Provide a `plan` array where each item has `step` and `status` "
        "(pending|in_progress|completed|blocked). "
        "At most one step may be in_progress at a time. "
        "Use this to keep the user-visible plan aligned with the agent's work.");
}

QJsonObject UpdatePlanTool::parametersSchema() const
{
    return QJsonObject{
        {QStringLiteral("type"), QStringLiteral("object")},
        {QStringLiteral("properties"), QJsonObject{
            {QStringLiteral("explanation"), QJsonObject{
                {QStringLiteral("type"), QStringLiteral("string")},
                {QStringLiteral("description"), QStringLiteral("Optional short note about what changed in the plan.")},
            }},
            {QStringLiteral("plan"), QJsonObject{
                {QStringLiteral("type"), QStringLiteral("array")},
                {QStringLiteral("description"), QStringLiteral("Full replacement list of plan steps.")},
                {QStringLiteral("items"), QJsonObject{
                    {QStringLiteral("type"), QStringLiteral("object")},
                    {QStringLiteral("properties"), QJsonObject{
                        {QStringLiteral("step"), QJsonObject{
                            {QStringLiteral("type"), QStringLiteral("string")},
                        }},
                        {QStringLiteral("status"), QJsonObject{
                            {QStringLiteral("type"), QStringLiteral("string")},
                            {QStringLiteral("enum"), QJsonArray{
                                QStringLiteral("pending"),
                                QStringLiteral("in_progress"),
                                QStringLiteral("completed"),
                                QStringLiteral("blocked"),
                            }},
                        }},
                    }},
                    {QStringLiteral("required"), QJsonArray{
                        QStringLiteral("step"),
                        QStringLiteral("status"),
                    }},
                }},
            }},
        }},
        {QStringLiteral("required"), QJsonArray{QStringLiteral("plan")}},
    };
}

ToolResult UpdatePlanTool::execute(const QString &callId, const QJsonObject &args)
{
    if (!m_todoTool)
        return {callId, name(), true, QStringLiteral("Todo tool is not available.")};

    const QJsonArray planJson = args.value(QStringLiteral("plan")).toArray();
    if (planJson.isEmpty())
        return {callId, name(), true, QStringLiteral("`plan` array is required and must not be empty.")};

    int inProgressCount = 0;
    QVariantList planItems;
    QStringList lines;

    for (int i = 0; i < planJson.size(); ++i) {
        const QJsonObject item = planJson.at(i).toObject();
        const QString step = item.value(QStringLiteral("step")).toString().trimmed();
        const QString status = item.value(QStringLiteral("status")).toString().trimmed().toLower();

        if (step.isEmpty())
            return {callId, name(), true, QStringLiteral("Plan item %1 has an empty `step`.").arg(i + 1)};
        if (!kPlanStatuses.contains(status))
            return {callId, name(), true,
                    QStringLiteral("Invalid status '%1'. Must be one of: %2")
                        .arg(status, kPlanStatuses.join(QStringLiteral(", ")))};
        if (status == QStringLiteral("in_progress")) {
            ++inProgressCount;
            if (inProgressCount > 1) {
                return {callId, name(), true,
                        QStringLiteral("Only one plan step may be in_progress at a time.")};
            }
        }

        const QString id = QStringLiteral("step_%1").arg(i + 1, 2, 10, QChar(u'0'));
        planItems.append(QVariantMap{
            {QStringLiteral("id"), id},
            {QStringLiteral("content"), step},
            {QStringLiteral("status"), status},
        });
        lines << QStringLiteral("  %1 [%2] %3").arg(statusIcon(status), id, step);
    }

    m_todoTool->setTodoItems(planItems);

    QString message = QStringLiteral("Plan updated (%1 steps)").arg(planItems.size());
    const QString explanation = args.value(QStringLiteral("explanation")).toString().trimmed();
    if (!explanation.isEmpty())
        message += QStringLiteral(": %1").arg(explanation);
    message += QStringLiteral("\n") + lines.join(QLatin1Char('\n'));
    return {callId, name(), false, message};
}

QString UpdatePlanTool::summary(const QJsonObject &args) const
{
    return QStringLiteral("update plan (%1 steps)")
        .arg(args.value(QStringLiteral("plan")).toArray().size());
}
