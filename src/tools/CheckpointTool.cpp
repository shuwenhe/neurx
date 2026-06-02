#include "tools/CheckpointTool.h"
#include <QJsonArray>
#include <QJsonObject>

CheckpointTool::CheckpointTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent)
    , m_manager(workspaceRoot)
{
}

QString CheckpointTool::description() const
{
    return QStringLiteral(
        "Inspect and restore workspace checkpoints created before file mutations.\n"
        "Actions:\n"
        "  list     — show recent checkpoints with id, timestamp, and description.\n"
        "  rollback — restore files captured by a checkpoint. Requires `checkpoint_id`.\n"
        "Use this to undo a bad edit after write_file, move_file, delete_file, or apply_diff.");
}

QJsonObject CheckpointTool::parametersSchema() const
{
    return QJsonObject{
        {"type", "object"},
        {"properties", QJsonObject{
            {"action", QJsonObject{
                {"type", "string"},
                {"enum", QJsonArray{"list", "rollback"}},
            }},
            {"checkpoint_id", QJsonObject{
                {"type", "string"},
                {"description", "Checkpoint id to restore when action=rollback."},
            }},
        }},
        {"required", QJsonArray{"action"}},
    };
}

ToolResult CheckpointTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString action = args.value("action").toString().trimmed().toLower();
    if (action == "list")
        return list(callId);
    if (action == "rollback")
        return rollback(callId, args);
    return ToolResult{callId, name(), true, "Unknown action: " + action};
}

QString CheckpointTool::summary(const QJsonObject &args) const
{
    const QString action = args.value("action").toString().trimmed().toLower();
    if (action == "rollback")
        return QStringLiteral("checkpoint rollback %1").arg(args.value("checkpoint_id").toString());
    return QStringLiteral("checkpoint list");
}

QVariantList CheckpointTool::recentCheckpoints() const
{
    QVariantList items;
    const QList<QVariantMap> checkpoints = m_manager.listCheckpoints();
    for (const QVariantMap &item : checkpoints)
        items.append(item);
    return items;
}

QVariantList CheckpointTool::filesForCheckpoint(const QString &checkpointId, QString *error) const
{
    QVariantList items;
    const QStringList files = m_manager.filesForCheckpoint(checkpointId, error);
    for (const QString &file : files)
        items.append(file);
    return items;
}

ToolResult CheckpointTool::list(const QString &callId) const
{
    if (!m_manager.isAvailable())
        return ToolResult{callId, name(), true, "Git is not available; checkpoint listing is disabled."};

    const QList<QVariantMap> checkpoints = m_manager.listCheckpoints();
    if (checkpoints.isEmpty())
        return ToolResult{callId, name(), false, "No checkpoints available."};

    QStringList lines;
    for (const QVariantMap &item : checkpoints) {
        lines << QStringLiteral("[%1] %2  %3")
                     .arg(item.value("id").toString(),
                          item.value("timestamp").toString(),
                          item.value("description").toString());
    }
    return ToolResult{callId, name(), false, lines.join('\n')};
}

ToolResult CheckpointTool::rollback(const QString &callId, const QJsonObject &args)
{
    if (!m_manager.isAvailable())
        return ToolResult{callId, name(), true, "Git is not available; rollback is disabled."};

    const QString checkpointId = args.value("checkpoint_id").toString().trimmed();
    if (checkpointId.isEmpty())
        return ToolResult{callId, name(), true, "`checkpoint_id` is required for rollback."};

    QString error;
    if (!m_manager.rollback(checkpointId, error))
        return ToolResult{callId, name(), true, error};

    emit checkpointRolledBack(checkpointId);
    return ToolResult{callId, name(), false,
                      QStringLiteral("Rolled back workspace files from checkpoint %1.").arg(checkpointId)};
}
