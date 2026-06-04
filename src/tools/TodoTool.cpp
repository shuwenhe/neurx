#include "tools/TodoTool.h"
#include <QJsonArray>
#include <QJsonObject>

const QStringList TodoTool::kValidStatuses = {
    "pending", "in_progress", "completed", "cancelled", "blocked"
};

// ── ctor ─────────────────────────────────────────────────────────────────────
TodoTool::TodoTool(QObject *parent) : BaseTool(parent) {}

void TodoTool::setTodoItems(const QVariantList &items)
{
    if (m_items == items)
        return;
    m_items = items;
    emit todoItemsChanged();
}

// ── description / schema ─────────────────────────────────────────────────────
QString TodoTool::description() const
{
    return QStringLiteral(
        "Manage a task list for the current session. "
        "Use it to decompose complex requests, track progress, and stay focused.\n"
        "Actions:\n"
        "  write — replace the full todo list. Provide a `todos` array where each item has:\n"
        "          id (string), content (string), status (pending|in_progress|completed|cancelled|blocked).\n"
        "          Mark a task in_progress before starting it; mark it completed immediately after.\n"
        "          Only one task may be in_progress at a time.\n"
        "  read  — return the current list without modification.\n"
        "Call read first if unsure of the current state before writing.");
}

QJsonObject TodoTool::parametersSchema() const
{
    return QJsonObject{
        {"type", "object"},
        {"properties", QJsonObject{
            {"action", QJsonObject{
                {"type", "string"},
                {"enum", QJsonArray{"write","read"}},
            }},
            {"todos", QJsonObject{
                {"type", "array"},
                {"description", "Full replacement list (required for write)."},
                {"items", QJsonObject{
                    {"type", "object"},
                    {"properties", QJsonObject{
                        {"id",      QJsonObject{{"type","string"}}},
                        {"content", QJsonObject{{"type","string"}}},
                        {"status",  QJsonObject{{"type","string"},
                            {"enum", QJsonArray{"pending","in_progress",
                                                "completed","cancelled","blocked"}}}},
                    }},
                    {"required", QJsonArray{"id","content","status"}},
                }},
            }},
        }},
        {"required", QJsonArray{"action"}},
    };
}

// ── execute ──────────────────────────────────────────────────────────────────
ToolResult TodoTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString action = args.value("action").toString().trimmed().toLower();
    if (action == "write") return opWrite(callId, args);
    if (action == "read")  return opRead(callId);
    return ToolResult{ callId, name(), true, "Unknown action: " + action };
}

QString TodoTool::summary(const QJsonObject &args) const
{
    const QString a = args.value("action").toString();
    if (a == "write") {
        const int n = args.value("todos").toArray().size();
        return QStringLiteral("todo write (%1 items)").arg(n);
    }
    return QStringLiteral("todo read");
}

// ── private ───────────────────────────────────────────────────────────────────
ToolResult TodoTool::opWrite(const QString &callId, const QJsonObject &args)
{
    const QJsonArray todosJson = args.value("todos").toArray();
    if (todosJson.isEmpty())
        return ToolResult{ callId, name(), true, "`todos` array is required and must not be empty." };

    int inProgressCount = 0;
    QVariantList newItems;
    for (const QJsonValue &v : todosJson) {
        const QJsonObject obj = v.toObject();
        const QString id      = obj.value("id").toString().trimmed();
        const QString content = obj.value("content").toString().trimmed();
        const QString status  = obj.value("status").toString().trimmed().toLower();

        if (id.isEmpty() || content.isEmpty())
            return ToolResult{ callId, name(), true,
                "Each todo must have a non-empty id and content." };
        if (!kValidStatuses.contains(status))
            return ToolResult{ callId, name(), true,
                "Invalid status '" + status + "'. Must be one of: " + kValidStatuses.join(", ") };
        if (status == "in_progress") {
            ++inProgressCount;
            if (inProgressCount > 1)
                return ToolResult{ callId, name(), true,
                    "Only one todo may be in_progress at a time." };
        }
        newItems.append(QVariantMap{
            {"id",      id},
            {"content", content},
            {"status",  status},
        });
    }

    setTodoItems(newItems);

    // Build a readable summary for the agent context.
    QStringList lines;
    for (const QVariant &item : m_items) {
        const QVariantMap m = item.toMap();
        const QString statusIcon =
            m["status"] == "completed"  ? "✓" :
            m["status"] == "in_progress"? "▶" :
            m["status"] == "blocked"    ? "!" :
            m["status"] == "cancelled"  ? "✗" : "○";
        lines << QStringLiteral("  %1 [%2] %3")
                     .arg(statusIcon, m["id"].toString(), m["content"].toString());
    }
    return ToolResult{ callId, name(), false,
        QStringLiteral("Todo list updated (%1 items):\n%2")
            .arg(m_items.size()).arg(lines.join('\n')) };
}

ToolResult TodoTool::opRead(const QString &callId)
{
    if (m_items.isEmpty())
        return ToolResult{ callId, name(), false, "Todo list is empty." };

    QStringList lines;
    for (const QVariant &item : m_items) {
        const QVariantMap m = item.toMap();
        const QString statusIcon =
            m["status"] == "completed"  ? "✓" :
            m["status"] == "in_progress"? "▶" :
            m["status"] == "blocked"    ? "!" :
            m["status"] == "cancelled"  ? "✗" : "○";
        lines << QStringLiteral("  %1 [%2] %3")
                     .arg(statusIcon, m["id"].toString(), m["content"].toString());
    }
    return ToolResult{ callId, name(), false, lines.join('\n') };
}
