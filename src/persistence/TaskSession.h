#pragma once

#include <QString>
#include <QVariantMap>
#include <QDateTime>
#include <QVector>
#include <QJsonObject>

/**
 * @brief TaskSession - 任务执行会话
 */
struct TaskSession {
    QString taskId;
    QString goal;
    QDateTime createdAt;
    QDateTime lastModifiedAt;

    // 执行状态
    enum class Status { InProgress, Completed, Failed, Cancelled, Paused };
    Status status = Status::InProgress;

    // 规划和执行
    QVector<QVariantMap> steps;          // 执行步骤
    int currentStepIndex = 0;
    QVector<QVariantMap> checkpoints;    // 检查点历史
    QVariantMap metadata;                // 元数据

    // 转换为JSON
    QJsonObject toJson() const;
    static TaskSession fromJson(const QJsonObject &json);
};

/**
 * @brief TaskPersistence - 任务持久化引擎
 */
class TaskPersistence {
public:
    explicit TaskPersistence(const QString &persistencePath = "./tasks");

    // 保存和加载
    bool saveSession(const QString &taskId, const TaskSession &session);
    TaskSession loadSession(const QString &taskId);
    bool sessionExists(const QString &taskId) const;

    // 列表操作
    QVector<QString> listSessions() const;
    bool deleteSession(const QString &taskId);

    // 检查点管理
    bool saveCheckpoint(const QString &taskId, const QVariantMap &checkpoint);
    QVector<QVariantMap> getCheckpointHistory(const QString &taskId) const;
    bool restoreFromCheckpoint(const QString &taskId, int checkpointIndex);

    // 自动保存
    void setAutoSaveInterval(int intervalMs);
    void startAutoSave(const QString &taskId, const TaskSession &session);
    void stopAutoSave();

private:
    QString m_persistencePath;
    QString getSessionPath(const QString &taskId) const;
    QString getCheckpointPath(const QString &taskId) const;
};
