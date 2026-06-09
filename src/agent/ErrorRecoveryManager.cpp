#include "agent/ErrorRecoveryManager.h"
#include <QUuid>
#include <QDateTime>

ErrorRecoveryManager::ErrorRecoveryManager(QObject *parent)
    : QObject(parent)
{
}

ErrorRecoveryManager::~ErrorRecoveryManager() = default;

QString ErrorRecoveryManager::createCheckpoint(const QString &taskId, const QString &description)
{
    QString checkpointId = _generateId();

    Checkpoint cp;
    cp.id = checkpointId;
    cp.taskId = taskId;
    cp.createdAt = QDateTime::currentDateTime();
    cp.description = description;

    m_checkpoints[checkpointId] = cp;
    emit checkpointCreated(checkpointId);

    return checkpointId;
}

bool ErrorRecoveryManager::rollback(const QString &checkpointId)
{
    auto it = m_checkpoints.find(checkpointId);
    if (it == m_checkpoints.end()) {
        return false;
    }

    // In a real implementation, would restore state
    // emit stateRestored(checkpointId);
    return true;
}

bool ErrorRecoveryManager::saveCheckpoint(const QString &checkpointId, const QJsonObject &state)
{
    auto it = m_checkpoints.find(checkpointId);
    if (it == m_checkpoints.end()) {
        return false;
    }

    it.value().state = state;
    return true;
}

QJsonObject ErrorRecoveryManager::getCheckpointState(const QString &checkpointId) const
{
    auto it = m_checkpoints.find(checkpointId);
    if (it != m_checkpoints.end()) {
        return it.value().state;
    }
    return {};
}

bool ErrorRecoveryManager::deleteCheckpoint(const QString &checkpointId)
{
    return m_checkpoints.remove(checkpointId) > 0;
}

QString ErrorRecoveryManager::recordError(const QString &taskId, ErrorType type, const QString &message,
                                         const QString &context)
{
    QString errorId = _generateId();

    ErrorInfo error;
    error.id = errorId;
    error.type = type;
    error.message = message;
    error.context = context;
    error.timestamp = QDateTime::currentDateTime();

    m_errors[errorId] = error;
    return errorId;
}

bool ErrorRecoveryManager::tryRecovery(const QString &errorId, RecoveryStrategy strategy)
{
    auto it = m_errors.find(errorId);
    if (it == m_errors.end()) {
        return false;
    }

    emit recoveryAttempted(errorId);

    if (it.value().retryCount < it.value().maxRetries) {
        it.value().retryCount++;
        emit recoverySucceeded(errorId);
        return true;
    } else {
        emit recoveryFailed(errorId);
        return false;
    }
}

bool ErrorRecoveryManager::isRecoverable(ErrorType type) const
{
    switch (type) {
    case ErrorType::Timeout:
    case ErrorType::Network:
        return true;
    case ErrorType::IO:
    case ErrorType::Parsing:
    case ErrorType::Validation:
        return false;
    default:
        return false;
    }
}

QJsonObject ErrorRecoveryManager::getErrorStatistics() const
{
    QJsonObject stats;
    stats["total_errors"] = (int)m_errors.size();

    QJsonObject byType;
    for (const auto &error : m_errors) {
        QString typeStr = error.type == ErrorType::IO ? "io"
                        : error.type == ErrorType::Network ? "network"
                        : error.type == ErrorType::Parsing ? "parsing"
                        : error.type == ErrorType::Validation ? "validation"
                        : error.type == ErrorType::Timeout ? "timeout"
                        : "unknown";
        byType[typeStr] = byType[typeStr].toInt() + 1;
    }
    stats["by_type"] = byType;

    return stats;
}

QJsonObject ErrorRecoveryManager::getErrorsByType() const
{
    return getErrorStatistics()["by_type"].toObject();
}

int ErrorRecoveryManager::getErrorCount(ErrorType type) const
{
    int count = 0;
    for (const auto &error : m_errors) {
        if (error.type == type) {
            count++;
        }
    }
    return count;
}

void ErrorRecoveryManager::clearOldCheckpoints(int minutesOld)
{
    auto now = QDateTime::currentDateTime();
    QStringList toRemove;

    for (auto it = m_checkpoints.begin(); it != m_checkpoints.end(); ++it) {
        if (it.value().createdAt.addSecs(minutesOld * 60) < now) {
            toRemove.append(it.key());
        }
    }

    for (const auto &id : toRemove) {
        m_checkpoints.remove(id);
    }
}

void ErrorRecoveryManager::clearErrors(int minutesOld)
{
    auto now = QDateTime::currentDateTime();
    QStringList toRemove;

    for (auto it = m_errors.begin(); it != m_errors.end(); ++it) {
        if (it.value().timestamp.addSecs(minutesOld * 60) < now) {
            toRemove.append(it.key());
        }
    }

    for (const auto &id : toRemove) {
        m_errors.remove(id);
    }
}

QString ErrorRecoveryManager::_generateId()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces).left(12);
}
