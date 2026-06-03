#pragma once

#include <QList>
#include <QDateTime>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

#include "agent/AgentMessage.h"

struct TaskSessionSnapshot {
    QString threadId;
    QString sessionId;
    QString parentThreadId;
    QString workspacePath;
    QString currentProvider;
    QString currentModel;
    QString currentFilePath;
    QDateTime updatedAt;
    QVariantList todoItems;
    QVariantList executionTimeline;
    QVariantMap approvalProfile;
    QList<AgentMessage> messages;

    bool isValid() const { return !threadId.trimmed().isEmpty() || !sessionId.trimmed().isEmpty(); }
    QString effectiveThreadId() const
    {
        const QString id = threadId.trimmed();
        if (!id.isEmpty())
            return id;
        return sessionId.trimmed();
    }
};

class TaskSessionStore {
public:
    static TaskSessionSnapshot loadLatest();
    static TaskSessionSnapshot loadById(const QString &sessionId);
    static QList<QVariantMap> listSessions();
    static bool saveLatest(const TaskSessionSnapshot &snapshot);
    static QString defaultSessionId();
};
