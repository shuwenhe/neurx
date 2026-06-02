#include "TaskSession.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QFile>
#include <QDir>
#include <QDebug>
#include <QTimer>

// TaskSession 序列化

QJsonObject TaskSession::toJson() const {
    QJsonObject json;
    json["taskId"] = taskId;
    json["goal"] = goal;
    json["createdAt"] = createdAt.toString(Qt::ISODate);
    json["lastModifiedAt"] = lastModifiedAt.toString(Qt::ISODate);
    json["status"] = static_cast<int>(status);
    json["currentStepIndex"] = currentStepIndex;

    // 步骤转换
    QJsonArray stepsArray;
    for (const auto &step : steps) {
        stepsArray.append(QJsonValue::fromVariant(step));
    }
    json["steps"] = stepsArray;

    // 检查点转换
    QJsonArray checkpointsArray;
    for (const auto &cp : checkpoints) {
        checkpointsArray.append(QJsonValue::fromVariant(cp));
    }
    json["checkpoints"] = checkpointsArray;

    return json;
}

TaskSession TaskSession::fromJson(const QJsonObject &json) {
    TaskSession session;
    session.taskId = json["taskId"].toString();
    session.goal = json["goal"].toString();
    session.createdAt = QDateTime::fromString(json["createdAt"].toString(), Qt::ISODate);
    session.lastModifiedAt = QDateTime::fromString(json["lastModifiedAt"].toString(), Qt::ISODate);
    session.status = static_cast<Status>(json["status"].toInt());
    session.currentStepIndex = json["currentStepIndex"].toInt();

    // 步骤恢复
    for (const auto &step : json["steps"].toArray()) {
        session.steps.append(step.toVariant().toMap());
    }

    // 检查点恢复
    for (const auto &cp : json["checkpoints"].toArray()) {
        session.checkpoints.append(cp.toVariant().toMap());
    }

    return session;
}

// TaskPersistence 实现

TaskPersistence::TaskPersistence(const QString &persistencePath)
    : m_persistencePath(persistencePath) {

    QDir dir(m_persistencePath);
    if (!dir.exists()) {
        dir.mkpath(".");
    }
}

bool TaskPersistence::saveSession(const QString &taskId, const TaskSession &session) {
    QString filePath = getSessionPath(taskId);

    // 创建目录
    QDir dir(m_persistencePath);
    if (!dir.exists()) {
        dir.mkpath(".");
    }

    // 转换为JSON并保存
    auto sessionJson = const_cast<TaskSession&>(session).toJson();
    QJsonDocument doc(sessionJson);

    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "Failed to save session:" << filePath;
        return false;
    }

    file.write(doc.toJson());
    file.close();

    qDebug() << "Session saved:" << taskId;
    return true;
}

TaskSession TaskPersistence::loadSession(const QString &taskId) {
    QString filePath = getSessionPath(taskId);

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Failed to load session:" << filePath;
        return TaskSession();
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) {
        qWarning() << "Invalid JSON in session file:" << filePath;
        return TaskSession();
    }

    qDebug() << "Session loaded:" << taskId;
    return TaskSession::fromJson(doc.object());
}

bool TaskPersistence::sessionExists(const QString &taskId) const {
    return QFile::exists(getSessionPath(taskId));
}

QVector<QString> TaskPersistence::listSessions() const {
    QVector<QString> sessions;
    QDir dir(m_persistencePath);

    for (const auto &file : dir.entryList(QStringList() << "*.json")) {
        sessions.append(file.replace(".json", ""));
    }

    return sessions;
}

bool TaskPersistence::deleteSession(const QString &taskId) {
    QString filePath = getSessionPath(taskId);
    bool success = QFile::remove(filePath);

    if (success) {
        qDebug() << "Session deleted:" << taskId;
    } else {
        qWarning() << "Failed to delete session:" << taskId;
    }

    return success;
}

bool TaskPersistence::saveCheckpoint(const QString &taskId, const QVariantMap &checkpoint) {
    auto session = loadSession(taskId);

    // 限制检查点数量
    if (session.checkpoints.size() >= 50) {
        session.checkpoints.removeFirst();
    }

    session.checkpoints.append(checkpoint);
    return saveSession(taskId, session);
}

QVector<QVariantMap> TaskPersistence::getCheckpointHistory(const QString &taskId) const {
    auto session = const_cast<TaskPersistence*>(this)->loadSession(taskId);
    return session.checkpoints;
}

bool TaskPersistence::restoreFromCheckpoint(const QString &taskId, int checkpointIndex) {
    auto session = loadSession(taskId);

    if (checkpointIndex < 0 || checkpointIndex >= session.checkpoints.size()) {
        qWarning() << "Invalid checkpoint index:" << checkpointIndex;
        return false;
    }

    // 恢复到检查点
    auto checkpoint = session.checkpoints[checkpointIndex];
    session.currentStepIndex = checkpoint.value("stepIndex", 0).toInt();
    session.lastModifiedAt = QDateTime::currentDateTime();

    return saveSession(taskId, session);
}

void TaskPersistence::setAutoSaveInterval(int intervalMs) {
    // 简化实现 - 实际产品应使用QTimer定期保存
    Q_UNUSED(intervalMs);
}

void TaskPersistence::startAutoSave(const QString &taskId, const TaskSession &session) {
    Q_UNUSED(taskId);
    Q_UNUSED(session);
    // 启动后台自动保存
}

void TaskPersistence::stopAutoSave() {
    // 停止自动保存
}

QString TaskPersistence::getSessionPath(const QString &taskId) const {
    return QString("%1/%2.json").arg(m_persistencePath, taskId);
}

QString TaskPersistence::getCheckpointPath(const QString &taskId) const {
    return QString("%1/%2.checkpoints").arg(m_persistencePath, taskId);
}
