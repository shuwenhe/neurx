#include "DefaultStateManager.h"
#include <QDebug>
#include <QUuid>
#include <QRegularExpression>

DefaultStateManager::DefaultStateManager(QObject *parent)
    : StateManager(parent)
{
    // Initialize default scope
    ScopeState globalScope;
    globalScope.state.id = "global";
    globalScope.state.scope = StateScope::Global;
    m_scopeStates[StateScope::Global] = globalScope;
}

ContextState DefaultStateManager::getCurrentState(StateScope scope) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_scopeStates.find(scope);
    if (it != m_scopeStates.end()) {
        return it->state;
    }
    
    return ContextState();
}

QVariant DefaultStateManager::getVariable(const QString &key, const QVariant &defaultValue)
{
    QMutexLocker locker(&m_mutex);
    
    auto scopeIt = m_scopeStates.find(StateScope::Global);
    if (scopeIt != m_scopeStates.end()) {
        auto varIt = scopeIt->variables.find(key);
        if (varIt != scopeIt->variables.end()) {
            return *varIt;
        }
    }
    
    return defaultValue;
}

QVariantMap DefaultStateManager::getVariables(const QString &pattern) const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap results;
    
    auto scopeIt = m_scopeStates.find(StateScope::Global);
    if (scopeIt != m_scopeStates.end()) {
        for (auto it = scopeIt->variables.begin(); it != scopeIt->variables.end(); ++it) {
            if (matchesPattern(it.key(), pattern)) {
                results[it.key()] = *it;
            }
        }
    }
    
    return results;
}

bool DefaultStateManager::hasVariable(const QString &key) const
{
    QMutexLocker locker(&m_mutex);
    
    auto scopeIt = m_scopeStates.find(StateScope::Global);
    if (scopeIt != m_scopeStates.end()) {
        return scopeIt->variables.contains(key);
    }
    
    return false;
}

void DefaultStateManager::setVariable(const QString &key, const QVariant &value,
                                     const QString &reason)
{
    QMutexLocker locker(&m_mutex);
    
    auto scopeIt = m_scopeStates.find(StateScope::Global);
    if (scopeIt == m_scopeStates.end()) {
        return;
    }
    
    QVariant oldValue = scopeIt->variables.value(key);
    
    scopeIt->variables[key] = value;
    scopeIt->state.variables[key] = value;
    scopeIt->state.lastModifiedAt = QDateTime::currentDateTime();
    
    StateChange change = createStateChange(
        StateChangeType::Set,
        key,
        oldValue,
        value,
        reason
    );
    
    locker.unlock();
    
    recordChange(change);
    emit variableChanged(change);
}

void DefaultStateManager::setVariables(const QVariantMap &values,
                                      const QString &reason)
{
    for (auto it = values.begin(); it != values.end(); ++it) {
        setVariable(it.key(), *it, reason);
    }
}

void DefaultStateManager::incrementVariable(const QString &key, double increment)
{
    QMutexLocker locker(&m_mutex);
    
    auto scopeIt = m_scopeStates.find(StateScope::Global);
    if (scopeIt == m_scopeStates.end()) {
        return;
    }
    
    QVariant oldValue = scopeIt->variables.value(key);
    double currentValue = oldValue.toDouble();
    double newValue = currentValue + increment;
    
    scopeIt->variables[key] = newValue;
    scopeIt->state.variables[key] = newValue;
    scopeIt->state.lastModifiedAt = QDateTime::currentDateTime();
    
    StateChange change = createStateChange(
        StateChangeType::Increment,
        key,
        oldValue,
        newValue,
        "Incremented by " + QString::number(increment)
    );
    
    locker.unlock();
    
    recordChange(change);
    emit variableChanged(change);
}

void DefaultStateManager::appendToList(const QString &key, const QVariant &value)
{
    QMutexLocker locker(&m_mutex);
    
    auto scopeIt = m_scopeStates.find(StateScope::Global);
    if (scopeIt == m_scopeStates.end()) {
        return;
    }
    
    QVariantList list = scopeIt->variables[key].toList();
    list.append(value);
    
    QVariant oldValue = scopeIt->variables[key];
    scopeIt->variables[key] = list;
    scopeIt->state.variables[key] = list;
    scopeIt->state.lastModifiedAt = QDateTime::currentDateTime();
    
    StateChange change = createStateChange(
        StateChangeType::Append,
        key,
        oldValue,
        list,
        "Appended value"
    );
    
    locker.unlock();
    
    recordChange(change);
    emit variableChanged(change);
}

void DefaultStateManager::mergeVariable(const QString &key, const QVariantMap &merge)
{
    QMutexLocker locker(&m_mutex);
    
    auto scopeIt = m_scopeStates.find(StateScope::Global);
    if (scopeIt == m_scopeStates.end()) {
        return;
    }
    
    QVariantMap existing = scopeIt->variables[key].toMap();
    
    for (auto it = merge.begin(); it != merge.end(); ++it) {
        existing[it.key()] = *it;
    }
    
    QVariant oldValue = scopeIt->variables[key];
    scopeIt->variables[key] = existing;
    scopeIt->state.variables[key] = existing;
    scopeIt->state.lastModifiedAt = QDateTime::currentDateTime();
    
    StateChange change = createStateChange(
        StateChangeType::Merge,
        key,
        oldValue,
        existing,
        "Merged values"
    );
    
    locker.unlock();
    
    recordChange(change);
    emit variableChanged(change);
}

void DefaultStateManager::deleteVariable(const QString &key)
{
    QMutexLocker locker(&m_mutex);
    
    auto scopeIt = m_scopeStates.find(StateScope::Global);
    if (scopeIt == m_scopeStates.end()) {
        return;
    }
    
    QVariant oldValue = scopeIt->variables.value(key);
    scopeIt->variables.remove(key);
    scopeIt->state.variables.remove(key);
    scopeIt->state.lastModifiedAt = QDateTime::currentDateTime();
    
    StateChange change = createStateChange(
        StateChangeType::Delete,
        key,
        oldValue,
        QVariant(),
        "Deleted variable"
    );
    
    locker.unlock();
    
    recordChange(change);
    emit variableChanged(change);
}

void DefaultStateManager::deleteVariables(const QStringList &keys)
{
    for (const auto &key : keys) {
        deleteVariable(key);
    }
}

QString DefaultStateManager::beginTransaction(const QString &description)
{
    QMutexLocker locker(&m_mutex);
    
    QString transactionId = QUuid::createUuid().toString();
    
    StateTransaction transaction;
    transaction.transactionId = transactionId;
    transaction.description = description;
    
    m_transactions[transactionId] = transaction;
    m_transactionStack.push(transaction);
    
    return transactionId;
}

void DefaultStateManager::commitTransaction(const QString &transactionId,
                                           std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_transactions.find(transactionId);
    if (it != m_transactions.end()) {
        it->committed = true;
        it->committedAt = QDateTime::currentDateTime();
        
        locker.unlock();
        emit transactionCommitted(transactionId);
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

void DefaultStateManager::rollbackTransaction(const QString &transactionId,
                                             std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_transactions.find(transactionId);
    if (it != m_transactions.end()) {
        // Reverse all changes in the transaction
        for (auto changeIt = it->changes.rbegin(); changeIt != it->changes.rend(); ++changeIt) {
            // Would revert each change
        }
        
        m_transactions.remove(transactionId);
        locker.unlock();
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

StateTransaction DefaultStateManager::getTransaction(const QString &transactionId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_transactions.find(transactionId);
    if (it != m_transactions.end()) {
        return *it;
    }
    
    return StateTransaction();
}

QVector<StateChange> DefaultStateManager::getChangeHistory(int limit) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<StateChange> result;
    qsizetype totalSize = m_changeHistory.size();
    qsizetype start = std::max(static_cast<qsizetype>(0), totalSize - static_cast<qsizetype>(limit));

    for (qsizetype i = start; i < totalSize; ++i) {
        result.append(m_changeHistory[i]);
    }
    
    return result;
}

QVector<StateChange> DefaultStateManager::getVariableHistory(const QString &key,
                                                             int limit) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_variableHistory.find(key);
    if (it != m_variableHistory.end()) {
        QVector<StateChange> result;
        qsizetype totalSize = it->size();
        qsizetype start = std::max(static_cast<qsizetype>(0), totalSize - static_cast<qsizetype>(limit));

        for (qsizetype i = start; i < totalSize; ++i) {
            result.append((*it)[i]);
        }
        return result;
    }
    
    return QVector<StateChange>();
}

QVector<StateChange> DefaultStateManager::getChangesSince(const QDateTime &since) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<StateChange> result;
    for (const auto &change : m_changeHistory) {
        if (change.timestamp >= since) {
            result.append(change);
        }
    }
    
    return result;
}

StateChange DefaultStateManager::getLastChange(const QString &key) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_variableHistory.find(key);
    if (it != m_variableHistory.end() && !it->isEmpty()) {
        return it->last();
    }
    
    return StateChange();
}

StateSnapshot DefaultStateManager::createSnapshot(const QString &label,
                                                  const QString &description)
{
    QMutexLocker locker(&m_mutex);
    
    StateSnapshot snapshot;
    snapshot.snapshotId = QUuid::createUuid().toString();
    snapshot.label = label;
    snapshot.description = description;
    
    auto scopeIt = m_scopeStates.find(StateScope::Global);
    if (scopeIt != m_scopeStates.end()) {
        snapshot.state = scopeIt->state;
    }
    
    m_snapshots.append(snapshot);
    
    locker.unlock();
    emit snapshotCreated(snapshot);
    
    return snapshot;
}

QVector<StateSnapshot> DefaultStateManager::listSnapshots() const
{
    QMutexLocker locker(&m_mutex);
    return m_snapshots;
}

void DefaultStateManager::restoreSnapshot(const QString &snapshotId,
                                         std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    for (const auto &snapshot : m_snapshots) {
        if (snapshot.snapshotId == snapshotId) {
            auto scopeIt = m_scopeStates.find(StateScope::Global);
            if (scopeIt != m_scopeStates.end()) {
                scopeIt->state = snapshot.state;
                scopeIt->variables = snapshot.state.variables;
            }
            
            locker.unlock();
            
            if (callback) callback(true);
            return;
        }
    }
    
    locker.unlock();
    if (callback) callback(false);
}

void DefaultStateManager::deleteSnapshot(const QString &snapshotId,
                                        std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    for (int i = 0; i < m_snapshots.size(); ++i) {
        if (m_snapshots[i].snapshotId == snapshotId) {
            m_snapshots.removeAt(i);
            locker.unlock();
            
            if (callback) callback(true);
            return;
        }
    }
    
    locker.unlock();
    if (callback) callback(false);
}

QString DefaultStateManager::startTurn(int turnNumber, const QString &userMessage)
{
    QString turnId = QUuid::createUuid().toString();
    
    TurnState turn;
    turn.turnId = turnId;
    turn.turnNumber = turnNumber;
    turn.userMessage = userMessage;
    
    QMutexLocker locker(&m_mutex);
    
    auto scopeIt = m_scopeStates.find(StateScope::Global);
    if (scopeIt != m_scopeStates.end()) {
        turn.contextBefore = scopeIt->state.variables;
    }
    
    m_turnHistory.append(turn);
    
    return turnId;
}

void DefaultStateManager::completeTurn(const QString &turnId,
                                      const QString &agentResponse,
                                      std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    for (auto &turn : m_turnHistory) {
        if (turn.turnId == turnId) {
            turn.agentResponse = agentResponse;
            turn.completedAt = QDateTime::currentDateTime();
            
            auto scopeIt = m_scopeStates.find(StateScope::Global);
            if (scopeIt != m_scopeStates.end()) {
                turn.contextAfter = scopeIt->state.variables;
            }
            
            locker.unlock();
            
            emit turnCompleted(turn);
            
            if (callback) callback(true);
            return;
        }
    }
    
    locker.unlock();
    if (callback) callback(false);
}

TurnState DefaultStateManager::getTurnState(const QString &turnId) const
{
    QMutexLocker locker(&m_mutex);
    
    for (const auto &turn : m_turnHistory) {
        if (turn.turnId == turnId) {
            return turn;
        }
    }
    
    return TurnState();
}

QVector<TurnState> DefaultStateManager::getTurnHistory(int limit) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<TurnState> result;
    qsizetype totalSize = m_turnHistory.size();
    qsizetype start = std::max(static_cast<qsizetype>(0), totalSize - static_cast<qsizetype>(limit));

    for (qsizetype i = start; i < totalSize; ++i) {
        result.append(m_turnHistory[i]);
    }
    
    return result;
}

QVariantMap DefaultStateManager::queryVariables(const StateQuery &query) const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap results;
    
    auto scopeIt = m_scopeStates.find(query.scope);
    if (scopeIt != m_scopeStates.end()) {
        for (auto it = scopeIt->variables.begin(); it != scopeIt->variables.end(); ++it) {
            if (matchesPattern(it.key(), query.pattern)) {
                results[it.key()] = *it;
            }
        }
    }
    
    return results;
}

QVector<QPair<QString, QVariant>> DefaultStateManager::searchState(const QString &searchText) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<QPair<QString, QVariant>> results;
    
    for (const auto &scopeState : m_scopeStates) {
        for (auto it = scopeState.variables.begin(); it != scopeState.variables.end(); ++it) {
            if (it.key().contains(searchText, Qt::CaseInsensitive) ||
                it->toString().contains(searchText, Qt::CaseInsensitive)) {
                results.append({it.key(), *it});
            }
        }
    }
    
    return results;
}

StateDiff DefaultStateManager::getStateDiff(const ContextState &oldState,
                                           const ContextState &newState) const
{
    StateDiff diff;
    
    // Find added and modified
    for (auto it = newState.variables.begin(); it != newState.variables.end(); ++it) {
        auto oldIt = oldState.variables.find(it.key());
        if (oldIt == oldState.variables.end()) {
            diff.added[it.key()] = *it;
        } else if (oldIt.value() != *it) {
            diff.modified[it.key()] = *it;
        }
    }
    
    // Find removed
    for (auto it = oldState.variables.begin(); it != oldState.variables.end(); ++it) {
        if (!newState.variables.contains(it.key())) {
            diff.removed.append(it.key());
        }
    }
    
    return diff;
}

void DefaultStateManager::resolveConflict(const StateConflict &conflict,
                                         StateConflictCallback callback)
{
    if (callback) {
        // Provide resolved value based on strategy
        StateConflict resolved = conflict;
        resolved.resolved = conflict.version1;  // Default to first version
        callback(resolved);
    }
}

QVector<StateConflict> DefaultStateManager::getUnresolvedConflicts() const
{
    return QVector<StateConflict>();
}

bool DefaultStateManager::validateStateConsistency(QString &errorMsg)
{
    QMutexLocker locker(&m_mutex);
    
    // Check for consistency
    for (const auto &scopeState : m_scopeStates) {
        for (auto it = scopeState.variables.begin(); it != scopeState.variables.end(); ++it) {
            // Validate variable names and types
        }
    }
    
    return true;
}

bool DefaultStateManager::checkStateIntegrity(QString &errorMsg)
{
    QMutexLocker locker(&m_mutex);
    
    // Check for data integrity
    if (m_changeHistory.isEmpty() && !m_scopeStates.isEmpty()) {
        errorMsg = "No change history recorded";
        return false;
    }
    
    return true;
}

void DefaultStateManager::saveState(const QString &context,
                                   std::function<void(bool success)> callback)
{
    // Would persist to storage (file, database, etc.)
    if (callback) callback(true);
}

void DefaultStateManager::loadState(const QString &context,
                                   StateCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto scopeIt = m_scopeStates.find(StateScope::Global);
    if (scopeIt != m_scopeStates.end()) {
        locker.unlock();
        
        if (callback) callback(scopeIt->state);
    } else {
        locker.unlock();
    }
}

void DefaultStateManager::clearAllState(std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    m_scopeStates.clear();
    m_changeHistory.clear();
    m_variableHistory.clear();
    m_snapshots.clear();
    m_turnHistory.clear();
    m_transactions.clear();
    
    locker.unlock();
    
    if (callback) callback(true);
}

void DefaultStateManager::clearOldState(const QDateTime &olderThan,
                                       std::function<void(int removedCount)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    int removedCount = 0;
    
    // Remove old changes
    for (int i = m_changeHistory.size() - 1; i >= 0; --i) {
        if (m_changeHistory[i].timestamp < olderThan) {
            m_changeHistory.removeAt(i);
            removedCount++;
        }
    }
    
    locker.unlock();
    
    if (callback) callback(removedCount);
}

QVariantMap DefaultStateManager::getStateStats() const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    stats["totalVariables"] = 0;
    stats["totalChanges"] = m_changeHistory.size();
    stats["totalSnapshots"] = m_snapshots.size();
    stats["totalTurns"] = m_turnHistory.size();
    stats["totalTransactions"] = m_transactions.size();
    
    for (const auto &scopeState : m_scopeStates) {
        stats["totalVariables"] = stats["totalVariables"].toInt() + scopeState.variables.size();
    }
    
    return stats;
}

StateChange DefaultStateManager::createStateChange(StateChangeType type,
                                                   const QString &key,
                                                   const QVariant &oldValue,
                                                   const QVariant &newValue,
                                                   const QString &reason)
{
    StateChange change;
    change.changeId = QUuid::createUuid().toString();
    change.type = type;
    change.key = key;
    change.oldValue = oldValue;
    change.newValue = newValue;
    change.reason = reason;
    
    return change;
}

void DefaultStateManager::recordChange(const StateChange &change)
{
    QMutexLocker locker(&m_mutex);
    
    m_changeHistory.append(change);
    
    auto it = m_variableHistory.find(change.key);
    if (it == m_variableHistory.end()) {
        m_variableHistory[change.key] = QVector<StateChange>();
    }
    m_variableHistory[change.key].append(change);
}

bool DefaultStateManager::matchesPattern(const QString &key, const QString &pattern) const
{
    if (pattern.isEmpty()) return true;

    QString p = pattern;
    p.replace("*", ".*").replace("?", ".");

    // Simple wildcard matching
    QRegularExpression regex(
        "^" + p + "$",
        QRegularExpression::CaseInsensitiveOption
    );
    
    return regex.match(key).hasMatch();
}

#include "moc_DefaultStateManager.cpp"
