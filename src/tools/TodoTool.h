#pragma once
#include "agent/ToolRegistry.h"
#include <QJsonArray>
#include <QVariantList>

// ── TodoTool ──────────────────────────────────────────────────────────────────
//  In-session task list for decomposing complex tasks and tracking progress.
//  One TodoTool instance lives on the AgentController (one per session).
//  The QML side can bind to todoItems to display a live task panel.
//
//  Actions:
//    write  — replace the full todo list (provide `todos` array).
//    read   — return the current list.
//
//  Each item: { "id": string, "content": string, "status": "pending" |
//               "in_progress" | "completed" | "cancelled" }
//
//  Only one item may have status "in_progress" at a time (enforced on write).

class TodoTool : public BaseTool {
    Q_OBJECT
    Q_PROPERTY(QVariantList todoItems READ todoItems NOTIFY todoItemsChanged)

public:
    explicit TodoTool(QObject *parent = nullptr);

    QString     name()        const override { return "todo"; }
    QString     description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

    QVariantList todoItems() const { return m_items; }
    void setTodoItems(const QVariantList &items);

signals:
    void todoItemsChanged();

private:
    static const QStringList kValidStatuses;

    ToolResult opWrite(const QString &callId, const QJsonObject &args);
    ToolResult opRead (const QString &callId);

    QVariantList m_items;
};
