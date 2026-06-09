#pragma once

#include <QString>
#include <QMap>
#include <QJsonObject>
#include <QDateTime>
#include <memory>
#include <QObject>

/**
 * @class ErrorRecoveryManager
 * @brief Handles error recovery, state rollback, and graceful degradation
 *
 * Features:
 * - State checkpoint/restore
 * - Error categorization
 * - Recovery strategies
 * - Rollback support
 * - Error statistics tracking
 *
 * Usage:
 *   ErrorRecoveryManager recovery;
 *   auto checkpoint = recovery.createCheckpoint("task-1");
 *   // ... do something ...
 *   if (failed) recovery.rollback(checkpoint);
 */

class ErrorRecoveryManager : public QObject {
    Q_OBJECT

public:
    enum class ErrorType { IO, Network, Parsing, Validation, Timeout, Unknown };
    enum class RecoveryStrategy { Retry, Rollback, SkipItem, Abort, UseDefault };

    explicit ErrorRecoveryManager(QObject *parent = nullptr);
    ~ErrorRecoveryManager();

    struct Checkpoint {
        QString id;
        QString taskId;
        QDateTime createdAt;
        QJsonObject state;
        QString description;
    };

    struct ErrorInfo {
        QString id;
        ErrorType type;
        QString message;
        QString context;
        QDateTime timestamp;
        int retryCount = 0;
        int maxRetries = 3;
        RecoveryStrategy strategy;
    };

    // Checkpoint management
    QString createCheckpoint(const QString &taskId, const QString &description = "");
    bool rollback(const QString &checkpointId);
    bool saveCheckpoint(const QString &checkpointId, const QJsonObject &state);
    QJsonObject getCheckpointState(const QString &checkpointId) const;
    bool deleteCheckpoint(const QString &checkpointId);

    // Error handling
    QString recordError(const QString &taskId, ErrorType type, const QString &message,
                        const QString &context = "");
    bool tryRecovery(const QString &errorId, RecoveryStrategy strategy);
    bool isRecoverable(ErrorType type) const;

    // Statistics
    QJsonObject getErrorStatistics() const;
    QJsonObject getErrorsByType() const;
    int getErrorCount(ErrorType type) const;

    // Cleanup
    void clearOldCheckpoints(int minutesOld = 60);
    void clearErrors(int minutesOld = 60);

signals:
    void checkpointCreated(const QString &checkpointId);
    void recoveryAttempted(const QString &errorId);
    void recoverySucceeded(const QString &errorId);
    void recoveryFailed(const QString &errorId);

private:
    QMap<QString, Checkpoint> m_checkpoints;
    QMap<QString, ErrorInfo> m_errors;

    QString _generateId();
};
