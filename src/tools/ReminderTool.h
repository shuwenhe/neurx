#pragma once
#include "agent/ToolRegistry.h"
#include <QDateTime>
#include <QTimer>
#include <QVariantList>

// ── ReminderTool ─────────────────────────────────────────────────────────────
//  Workspace-scoped scheduled reminders and recurring maintenance tasks.
//  Stored at <workspace>/.neurx/reminders.json.

class ReminderTool : public BaseTool {
    Q_OBJECT
public:
    explicit ReminderTool(const QString &workspaceRoot, QObject *parent = nullptr);

    QString     name()        const override { return QStringLiteral("schedule"); }
    QString     description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

    QVariantList reminders() const;
    bool createReminder(const QString &title, const QDateTime &dueAtUtc,
                        int repeatMinutes, QString *error = nullptr);
    bool cancelReminder(const QString &id, QString *error = nullptr);
    void setWorkspaceRoot(const QString &workspaceRoot);

signals:
    void remindersChanged();
    void reminderTriggered(const QVariantMap &reminder);

private slots:
    void checkDueReminders();

private:
    struct ReminderItem {
        QString id;
        QString title;
        QDateTime dueAtUtc;
        int repeatMinutes{0};
        QString status; // pending | triggered | cancelled
        QDateTime createdAtUtc;
        QDateTime triggeredAtUtc;
    };

    void load();
    void save() const;
    QVariantMap toVariantMap(const ReminderItem &item) const;
    ReminderItem fromVariantMap(const QVariantMap &map) const;
    ReminderItem *findReminder(const QString &id);
    const ReminderItem *findReminder(const QString &id) const;
    QString storePath() const;
    QString formatDue(const QDateTime &dt) const;

    QString m_workspaceRoot;
    QString m_storePath;
    QList<ReminderItem> m_items;
    QTimer m_timer;
};
