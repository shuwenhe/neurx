#pragma once

#include <QString>
#include <QVariantMap>
#include <QStringList>
#include <QDateTime>

/**
 * @class GoalTypes
 * @brief Goal and objective type definitions
 * 
 * Migrated from Codex goals system:
 * - Thread-level goal persistence
 * - Goal state tracking and mutations
 * - Completion criteria and dependencies
 * - Progress monitoring
 */

// ── Goal Priority ──────────────────────────────────────────────

enum class GoalPriority {
    Low = 0,
    Normal = 1,
    High = 2,
    Critical = 3
};

// ── Goal Status ────────────────────────────────────────────────

enum class GoalStatus {
    Created,         ///< Just created, not yet started
    Active,          ///< Currently being pursued
    Paused,          ///< Temporarily paused
    Blocked,         ///< Waiting for dependencies
    Completed,       ///< Successfully completed
    Failed,          ///< Could not be completed
    Abandoned,       ///< User abandoned the goal
    Cancelled        ///< Administratively cancelled
};

// ── Completion Criterion ──────────────────────────────────────

struct CompletionCriterion {
    QString id;
    QString description;                ///< What defines completion
    QString type;                       ///< "checklist", "metric", "approval", "state"
    
    // Checklist
    QStringList items;
    int itemsCompleted{0};
    
    // Metric
    double targetValue{0.0};
    double currentValue{0.0};
    QString unit;
    
    // Approval
    bool requiresApproval{false};
    bool approvalReceived{false};
    
    bool isMet() const {
        if (type == "checklist") {
            return itemsCompleted == items.size() && items.size() > 0;
        }
        if (type == "metric") {
            return currentValue >= targetValue;
        }
        if (type == "approval") {
            return approvalReceived;
        }
        return true;
    }
};

// ── Goal Dependency ────────────────────────────────────────────

struct GoalDependency {
    QString goalId;
    bool optional{false};               ///< Optional dependency
    bool blocking{true};                ///< Blocks goal if not met
};

// ── Goal Step ──────────────────────────────────────────────────

struct GoalStep {
    QString id;
    QString description;
    QString status;                     ///< "pending", "in_progress", "completed"
    QString notes;
    QDateTime startedAt;
    QDateTime completedAt;
    int order{0};                       ///< Execution order
};

// ── Goal Metadata ──────────────────────────────────────────────

struct GoalMetadata {
    QString id;
    QString title;
    QString description;
    QString context;                    ///< Context/reason for goal
    
    GoalPriority priority{GoalPriority::Normal};
    GoalStatus status{GoalStatus::Created};
    
    // Assignment
    QString ownerId;                    ///< User/agent responsible
    QStringList participants;
    
    // Timeline
    QDateTime createdAt{QDateTime::currentDateTime()};
    QDateTime startedAt;
    QDateTime dueDate;
    QDateTime completedAt;
    
    // Tracking
    QDateTime lastModifiedAt{QDateTime::currentDateTime()};
    QString lastModifiedBy;
};

// ── Goal Definition ────────────────────────────────────────────

struct Goal {
    GoalMetadata metadata;
    
    // Criteria
    QVector<CompletionCriterion> criteria;
    
    // Dependencies
    QVector<GoalDependency> dependencies;
    
    // Steps
    QVector<GoalStep> steps;
    
    // Progress
    double progressPercentage{0.0};
    int estimatedHoursRemaining{0};
    
    // Tags and categorization
    QStringList tags;
    QString category;
    
    // Notes and history
    QString notes;
    QStringList history;                ///< State change history
};

// ── Goal Progress Event ────────────────────────────────────────

struct GoalProgressEvent {
    QString goalId;
    GoalStatus newStatus;
    GoalStatus oldStatus;
    double progressPercentage;
    QString message;
    QDateTime timestamp{QDateTime::currentDateTime()};
};

// ── Goal State Mutation ────────────────────────────────────────

struct GoalStateMutation {
    QString goalId;
    QString threadId;                  ///< Associated thread
    
    QString mutation;                  ///< Type: "start", "pause", "resume", "complete", "fail", "cancel"
    QVariantMap changes;
    
    QDateTime appliedAt{QDateTime::currentDateTime()};
    QString appliedBy;
    
    // Rollback capability
    bool reversible{true};
    QVariantMap previousState;         ///< State before mutation
};

// ── Goal Snapshot (checkpoint) ─────────────────────────────────

struct GoalSnapshot {
    QString goalId;
    QString snapshotId;
    Goal goal;                         ///< Frozen state
    QDateTime capturedAt{QDateTime::currentDateTime()};
};

// ── Goal Callbacks ─────────────────────────────────────────────

using GoalCallback = std::function<void(bool success, const Goal &goal)>;
using GoalsListCallback = std::function<void(const QVector<Goal> &goals)>;
using GoalProgressCallback = std::function<void(const GoalProgressEvent &event)>;
