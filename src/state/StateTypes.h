#pragma once

#include <QString>
#include <QVariantMap>
#include <QStringList>
#include <QDateTime>
#include <QStack>

/**
 * @class StateTypes
 * @brief Agent state management type definitions
 * 
 * Migrated from Codex state system:
 * - Context state tracking
 * - State persistence and recovery
 * - Transaction support
 * - State change history
 */

// ── State Scope ────────────────────────────────────────────────

enum class StateScope {
    Global,                             ///< Global agent state
    Thread,                             ///< Thread-specific state
    Conversation,                       ///< Conversation turn state
    Task,                               ///< Task-specific state
    Local                               ///< Local execution state
};

// ── State Change Type ──────────────────────────────────────────

enum class StateChangeType {
    Set,                                ///< Set variable
    Unset,                              ///< Unset variable
    Increment,                          ///< Increment numeric value
    Append,                             ///< Append to list
    Merge,                              ///< Merge object
    Replace,                            ///< Replace object
    Delete                              ///< Delete key
};

// ── Context State ──────────────────────────────────────────────

struct ContextState {
    QString id;                         ///< State ID
    StateScope scope{StateScope::Global};
    
    // Current values
    QVariantMap variables;              ///< Context variables
    QStringList conversationHistory;    ///< Turn history
    
    // Metadata
    QDateTime createdAt{QDateTime::currentDateTime()};
    QDateTime lastModifiedAt{QDateTime::currentDateTime()};
    QString lastModifiedBy;
    
    // References
    QString threadId;
    QString userId;
    QString taskId;
};

// ── State Change ───────────────────────────────────────────────

struct StateChange {
    QString changeId;
    StateChangeType type;
    QString key;                        ///< Variable key
    QVariant oldValue;
    QVariant newValue;
    
    QDateTime timestamp{QDateTime::currentDateTime()};
    QString changedBy;
    QString reason;
    
    bool canReverse{true};
};

// ── State Snapshot ────────────────────────────────────────────

struct StateSnapshot {
    QString snapshotId;
    QString stateId;
    ContextState state;
    
    QDateTime capturedAt{QDateTime::currentDateTime()};
    QString label;
    QString description;
};

// ── State Patch ────────────────────────────────────────────────

struct StatePatch {
    QStringList additions;              ///< New keys
    QStringList modifications;          ///< Modified keys
    QStringList deletions;              ///< Deleted keys
    
    QVariantMap changes;                ///< Actual changes
};

// ── State Query ────────────────────────────────────────────────

struct StateQuery {
    QString pattern;                    ///< Key pattern to match
    StateScope scope{StateScope::Global};
    
    bool includeHistory{false};
    int maxAge{0};                      ///< Max age in seconds (0 = any)
};

// ── State Transaction ──────────────────────────────────────────

struct StateTransaction {
    QString transactionId;
    
    QVector<StateChange> changes;
    bool committed{false};
    
    QDateTime startedAt{QDateTime::currentDateTime()};
    QDateTime committedAt;
    
    QString description;
};

// ── State Conflict ─────────────────────────────────────────────

struct StateConflict {
    QString stateKey;
    QVariant version1;
    QVariant version2;
    QString source1;
    QString source2;
    
    // Resolution
    QVariant resolved;
    QString resolutionStrategy;        ///< "first-write-wins", "last-write-wins", "manual"
};

// ── Conversation Turn State ────────────────────────────────────

struct TurnState {
    QString turnId;
    int turnNumber{0};
    
    QString userMessage;
    QString agentResponse;
    
    QVariantMap contextBefore;         ///< State before turn
    QVariantMap contextAfter;          ///< State after turn
    
    QVector<StateChange> changes;
    QDateTime completedAt{QDateTime::currentDateTime()};
};

// ── State Diff ────────────────────────────────────────────────

struct StateDiff {
    QVariantMap added;                 ///< New keys
    QVariantMap modified;              ///< Changed values
    QStringList removed;               ///< Deleted keys
};

// ── State Callbacks ────────────────────────────────────────────

using StateCallback = std::function<void(const ContextState &state)>;
using StateChangeCallback = std::function<void(const StateChange &change)>;
using StateConflictCallback = std::function<void(const StateConflict &conflict)>;
using StateDiffCallback = std::function<void(const StateDiff &diff)>;
