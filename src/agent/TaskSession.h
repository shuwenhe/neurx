#pragma once

#include <QList>
#include <QDateTime>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

#include "agent/AgentMessage.h"

struct TaskSessionSnapshot {
    QString sessionId;
    QString workspacePath;
    QString currentProvider;
    QString currentModel;
    QString currentFilePath;
    QDateTime updatedAt;
    QVariantList todoItems;
    QList<AgentMessage> messages;

    bool isValid() const { return !sessionId.trimmed().isEmpty(); }
};

class TaskSessionStore {
public:
    static TaskSessionSnapshot loadLatest();
    static TaskSessionSnapshot loadById(const QString &sessionId);
    static QList<QVariantMap> listSessions();
    static bool saveLatest(const TaskSessionSnapshot &snapshot);
    static QString defaultSessionId();
};
