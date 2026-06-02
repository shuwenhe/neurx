#pragma once

#include "StateManager.h"
#include <QMap>
#include <QMutex>
#include <QStack>

/**
 * @class DefaultStateManager
 * @brief Default state management implementation
 * 
 * Features:
 * - In-memory and persistent state storage
 * - Transaction support with rollback
 * - Complete change history and audit
 * - Snapshot and recovery
 * - Conflict detection and resolution
 */
class DefaultStateManager : public StateManager {
    Q_OBJECT
public:
    explicit DefaultStateManager(QObject *parent = nullptr);
    ~DefaultStateManager() = default;
    
    // State Access
    ContextState getCurrentState(StateScope scope = StateScope::Global) const override;
    QVariant getVariable(const QString &key, const QVariant &defaultValue = QVariant()) override;
    QVariantMap getVariables(const QString &pattern) const override;
    bool hasVariable(const QString &key) const override;
    
    // State Modification
    void setVariable(const QString &key, const QVariant &value,
                    const QString &reason = "") override;
    void setVariables(const QVariantMap &values,
                     const QString &reason = "") override;
    void incrementVariable(const QString &key, double increment = 1.0) override;
    void appendToList(const QString &key, const QVariant &value) override;
    void mergeVariable(const QString &key, const QVariantMap &merge) override;
    void deleteVariable(const QString &key) override;
    void deleteVariables(const QStringList &keys) override;
    
    // Transactions
    QString beginTransaction(const QString &description = "") override;
    void commitTransaction(const QString &transactionId,
                          std::function<void(bool success)> callback) override;
    void rollbackTransaction(const QString &transactionId,
                            std::function<void(bool success)> callback) override;
    StateTransaction getTransaction(const QString &transactionId) const override;
    
    // History & Changes
    QVector<StateChange> getChangeHistory(int limit = 100) const override;
    QVector<StateChange> getVariableHistory(const QString &key,
                                            int limit = 100) const override;
    QVector<StateChange> getChangesSince(const QDateTime &since) const override;
    StateChange getLastChange(const QString &key) const override;
    
    // Snapshots
    StateSnapshot createSnapshot(const QString &label = "",
                                const QString &description = "") override;
    QVector<StateSnapshot> listSnapshots() const override;
    void restoreSnapshot(const QString &snapshotId,
                        std::function<void(bool success)> callback) override;
    void deleteSnapshot(const QString &snapshotId,
                       std::function<void(bool success)> callback) override;
    
    // Conversation Turns
    QString startTurn(int turnNumber, const QString &userMessage) override;
    void completeTurn(const QString &turnId,
                     const QString &agentResponse,
                     std::function<void(bool success)> callback) override;
    TurnState getTurnState(const QString &turnId) const override;
    QVector<TurnState> getTurnHistory(int limit = 50) const override;
    
    // Queries
    QVariantMap queryVariables(const StateQuery &query) const override;
    QVector<QPair<QString, QVariant>> searchState(const QString &searchText) const override;
    StateDiff getStateDiff(const ContextState &oldState,
                          const ContextState &newState) const override;
    
    // Conflict Resolution
    void resolveConflict(const StateConflict &conflict,
                        StateConflictCallback callback) override;
    QVector<StateConflict> getUnresolvedConflicts() const override;
    
    // Validation
    bool validateStateConsistency(QString &errorMsg) override;
    bool checkStateIntegrity(QString &errorMsg) override;
    
    // Persistence
    void saveState(const QString &context,
                  std::function<void(bool success)> callback) override;
    void loadState(const QString &context,
                  StateCallback callback) override;
    
    // Cleanup
    void clearAllState(std::function<void(bool success)> callback) override;
    void clearOldState(const QDateTime &olderThan,
                      std::function<void(int removedCount)> callback) override;
    
    // Statistics
    QVariantMap getStateStats() const override;

private:
    struct ScopeState {
        ContextState state;
        QVariantMap variables;
    };
    
    QMap<StateScope, ScopeState> m_scopeStates;
    QVector<StateChange> m_changeHistory;
    QMap<QString, QVector<StateChange>> m_variableHistory;
    
    QVector<StateSnapshot> m_snapshots;
    QVector<TurnState> m_turnHistory;
    QMap<QString, StateTransaction> m_transactions;
    QStack<StateTransaction> m_transactionStack;
    
    mutable QMutex m_mutex;
    
    // Helpers
    StateChange createStateChange(StateChangeType type, const QString &key,
                                 const QVariant &oldValue, const QVariant &newValue,
                                 const QString &reason);
    void recordChange(const StateChange &change);
    bool matchesPattern(const QString &key, const QString &pattern) const;
};

using DefaultStateManagerPtr = std::shared_ptr<DefaultStateManager>;
