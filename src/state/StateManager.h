#pragma once

#include "StateTypes.h"
#include <QObject>
#include <memory>

/**
 * @class StateManager
 * @brief Agent state and context management
 * 
 * Handles:
 * - Context state tracking and persistence
 * - State change history and audit
 * - Transactions and rollback
 * - Conflict resolution
 * - State snapshots
 */
class StateManager : public QObject {
    Q_OBJECT
public:
    explicit StateManager(QObject *parent = nullptr) : QObject(parent) {}
    virtual ~StateManager() = default;
    
    // ── State Access ───────────────────────────────────────────
    
    /// Get current state
    virtual ContextState getCurrentState(StateScope scope = StateScope::Global) const = 0;
    
    /// Get variable
    virtual QVariant getVariable(const QString &key, const QVariant &defaultValue = QVariant()) = 0;
    
    /// Get all variables matching pattern
    virtual QVariantMap getVariables(const QString &pattern) const = 0;
    
    /// Check variable existence
    virtual bool hasVariable(const QString &key) const = 0;
    
    // ── State Modification ────────────────────────────────────
    
    /// Set variable
    virtual void setVariable(const QString &key, const QVariant &value,
                            const QString &reason = "") = 0;
    
    /// Set multiple variables
    virtual void setVariables(const QVariantMap &values,
                             const QString &reason = "") = 0;
    
    /// Increment numeric variable
    virtual void incrementVariable(const QString &key, double increment = 1.0) = 0;
    
    /// Append to list variable
    virtual void appendToList(const QString &key, const QVariant &value) = 0;
    
    /// Merge with existing variable
    virtual void mergeVariable(const QString &key, const QVariantMap &merge) = 0;
    
    /// Delete variable
    virtual void deleteVariable(const QString &key) = 0;
    
    /// Delete multiple variables
    virtual void deleteVariables(const QStringList &keys) = 0;
    
    // ── Transactions ───────────────────────────────────────────
    
    /// Begin transaction
    virtual QString beginTransaction(const QString &description = "") = 0;
    
    /// Commit transaction
    virtual void commitTransaction(const QString &transactionId,
                                  std::function<void(bool success)> callback) = 0;
    
    /// Rollback transaction
    virtual void rollbackTransaction(const QString &transactionId,
                                    std::function<void(bool success)> callback) = 0;
    
    /// Get transaction status
    virtual StateTransaction getTransaction(const QString &transactionId) const = 0;
    
    // ── History & Changes ──────────────────────────────────────
    
    /// Get state change history
    virtual QVector<StateChange> getChangeHistory(int limit = 100) const = 0;
    
    /// Get variable change history
    virtual QVector<StateChange> getVariableHistory(const QString &key,
                                                    int limit = 100) const = 0;
    
    /// Get changes since timestamp
    virtual QVector<StateChange> getChangesSince(const QDateTime &since) const = 0;
    
    /// Get last change for key
    virtual StateChange getLastChange(const QString &key) const = 0;
    
    // ── Snapshots ──────────────────────────────────────────────
    
    /// Create state snapshot
    virtual StateSnapshot createSnapshot(const QString &label = "",
                                        const QString &description = "") = 0;
    
    /// List snapshots
    virtual QVector<StateSnapshot> listSnapshots() const = 0;
    
    /// Restore from snapshot
    virtual void restoreSnapshot(const QString &snapshotId,
                               std::function<void(bool success)> callback) = 0;
    
    /// Delete snapshot
    virtual void deleteSnapshot(const QString &snapshotId,
                               std::function<void(bool success)> callback) = 0;
    
    // ── Conversation Turns ────────────────────────────────────
    
    /// Start conversation turn
    virtual QString startTurn(int turnNumber, const QString &userMessage) = 0;
    
    /// Complete conversation turn
    virtual void completeTurn(const QString &turnId,
                             const QString &agentResponse,
                             std::function<void(bool success)> callback) = 0;
    
    /// Get turn state
    virtual TurnState getTurnState(const QString &turnId) const = 0;
    
    /// Get turn history
    virtual QVector<TurnState> getTurnHistory(int limit = 50) const = 0;
    
    // ── Queries ────────────────────────────────────────────────
    
    /// Query variables
    virtual QVariantMap queryVariables(const StateQuery &query) const = 0;
    
    /// Search state
    virtual QVector<QPair<QString, QVariant>> searchState(const QString &searchText) const = 0;
    
    /// Get state diff
    virtual StateDiff getStateDiff(const ContextState &oldState,
                                  const ContextState &newState) const = 0;
    
    // ── Conflict Resolution ────────────────────────────────────
    
    /// Handle state conflict
    virtual void resolveConflict(const StateConflict &conflict,
                                StateConflictCallback callback) = 0;
    
    /// Get unresolved conflicts
    virtual QVector<StateConflict> getUnresolvedConflicts() const = 0;
    
    // ── Validation ─────────────────────────────────────────────
    
    /// Validate state consistency
    virtual bool validateStateConsistency(QString &errorMsg) = 0;
    
    /// Check state integrity
    virtual bool checkStateIntegrity(QString &errorMsg) = 0;
    
    // ── Persistence ────────────────────────────────────────────
    
    /// Save state
    virtual void saveState(const QString &context,
                          std::function<void(bool success)> callback) = 0;
    
    /// Load state
    virtual void loadState(const QString &context,
                          StateCallback callback) = 0;
    
    // ── Cleanup ────────────────────────────────────────────────
    
    /// Clear all state
    virtual void clearAllState(std::function<void(bool success)> callback) = 0;
    
    /// Clear state older than specified time
    virtual void clearOldState(const QDateTime &olderThan,
                              std::function<void(int removedCount)> callback) = 0;
    
    // ── Statistics ─────────────────────────────────────────────
    
    /// Get state statistics
    virtual QVariantMap getStateStats() const = 0;

signals:
    /// Variable changed signal
    void variableChanged(const StateChange &change);
    
    /// State changed signal
    void stateChanged(const ContextState &newState);
    
    /// Transaction committed signal
    void transactionCommitted(const QString &transactionId);
    
    /// Conflict detected signal
    void conflictDetected(const StateConflict &conflict);
    
    /// Snapshot created signal
    void snapshotCreated(const StateSnapshot &snapshot);
    
    /// Turn completed signal
    void turnCompleted(const TurnState &turn);
};

using StateManagerPtr = std::shared_ptr<StateManager>;
