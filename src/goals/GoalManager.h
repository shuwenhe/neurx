#pragma once

#include "GoalTypes.h"
#include <QObject>
#include <memory>

// Forward declarations
class ThreadStore;

/**
 * @class GoalManager
 * @brief Goal management interface
 * 
 * Handles:
 * - Thread-level goal management
 * - Goal state mutations and rollback
 * - Progress tracking
 * - Dependency resolution
 * - Completion verification
 */
class GoalManager : public QObject {
    Q_OBJECT
public:
    explicit GoalManager(QObject *parent = nullptr) : QObject(parent) {}
    virtual ~GoalManager() = default;
    
    // ── Creation & Management ──────────────────────────────────
    
    /// Create new goal in thread
    virtual void createGoal(const QString &threadId,
                           const GoalMetadata &metadata,
                           GoalCallback callback) = 0;
    
    /// Get goal by ID
    virtual Goal getGoal(const QString &goalId) const = 0;
    
    /// Get goals in thread
    virtual QVector<Goal> getGoalsInThread(const QString &threadId) const = 0;
    
    /// Update goal metadata
    virtual void updateGoal(const Goal &goal,
                           GoalCallback callback) = 0;
    
    /// Delete goal
    virtual void deleteGoal(const QString &goalId,
                           std::function<void(bool success)> callback) = 0;
    
    // ── State Mutations ────────────────────────────────────────
    
    /// Start goal
    virtual void startGoal(const QString &goalId,
                          GoalProgressCallback callback) = 0;
    
    /// Pause goal
    virtual void pauseGoal(const QString &goalId,
                         GoalProgressCallback callback) = 0;
    
    /// Resume paused goal
    virtual void resumeGoal(const QString &goalId,
                           GoalProgressCallback callback) = 0;
    
    /// Mark goal as completed
    virtual void completeGoal(const QString &goalId,
                             GoalProgressCallback callback) = 0;
    
    /// Mark goal as failed
    virtual void failGoal(const QString &goalId,
                         const QString &reason,
                         GoalProgressCallback callback) = 0;
    
    /// Cancel goal
    virtual void cancelGoal(const QString &goalId,
                           GoalProgressCallback callback) = 0;
    
    // ── Progress Tracking ──────────────────────────────────────
    
    /// Update progress
    virtual void updateProgress(const QString &goalId,
                               double percentage,
                               int estimatedHoursRemaining,
                               std::function<void(bool)> callback) = 0;
    
    /// Add completion criterion
    virtual void addCriterion(const QString &goalId,
                             const CompletionCriterion &criterion,
                             std::function<void(bool)> callback) = 0;
    
    /// Update criterion progress
    virtual void updateCriterionProgress(const QString &goalId,
                                        const QString &criterionId,
                                        const QVariantMap &progress,
                                        std::function<void(bool)> callback) = 0;
    
    /// Check if goal is complete
    virtual bool isGoalComplete(const QString &goalId) const = 0;
    
    // ── Steps ──────────────────────────────────────────────────
    
    /// Add step
    virtual void addStep(const QString &goalId,
                        const GoalStep &step,
                        std::function<void(bool)> callback) = 0;
    
    /// Update step status
    virtual void updateStepStatus(const QString &goalId,
                                 const QString &stepId,
                                 const QString &status,
                                 std::function<void(bool)> callback) = 0;
    
    /// Get steps for goal
    virtual QVector<GoalStep> getSteps(const QString &goalId) const = 0;
    
    // ── Dependencies ────────────────────────────────────────────
    
    /// Add dependency
    virtual void addDependency(const QString &goalId,
                              const GoalDependency &dependency,
                              std::function<void(bool)> callback) = 0;
    
    /// Remove dependency
    virtual void removeDependency(const QString &goalId,
                                 const QString &dependentGoalId,
                                 std::function<void(bool)> callback) = 0;
    
    /// Check dependencies
    virtual bool checkDependencies(const QString &goalId) const = 0;
    
    /// Get dependent goals
    virtual QStringList getDependentGoals(const QString &goalId) const = 0;
    
    // ── Snapshots & Rollback ────────────────────────────────────
    
    /// Create snapshot of goal state
    virtual void createSnapshot(const QString &goalId,
                               std::function<void(const GoalSnapshot &)> callback) = 0;
    
    /// Restore from snapshot
    virtual void restoreSnapshot(const GoalSnapshot &snapshot,
                                GoalCallback callback) = 0;
    
    /// Rollback last mutation
    virtual void rollbackLastMutation(const QString &goalId,
                                     GoalCallback callback) = 0;
    
    // ── Queries ────────────────────────────────────────────────
    
    /// Get active goals in thread
    virtual QVector<Goal> getActiveGoals(const QString &threadId) const = 0;
    
    /// Get completed goals in thread
    virtual QVector<Goal> getCompletedGoals(const QString &threadId) const = 0;
    
    /// Get blocked goals (unmet dependencies)
    virtual QVector<Goal> getBlockedGoals(const QString &threadId) const = 0;
    
    /// Search goals
    virtual QVector<Goal> searchGoals(const QString &threadId,
                                     const QVariantMap &criteria) const = 0;
    
    // ── Notifications ──────────────────────────────────────────
    
    /// Get overdue goals
    virtual QVector<Goal> getOverdueGoals() const = 0;
    
    /// Get goals due soon
    virtual QVector<Goal> getUpcomingGoals(int daysAhead = 7) const = 0;
    
    // ── Statistics ─────────────────────────────────────────────
    
    /// Get goal statistics for thread
    virtual QVariantMap getThreadGoalStats(const QString &threadId) const = 0;
    
    /// Get goal statistics for user
    virtual QVariantMap getUserGoalStats(const QString &userId) const = 0;

signals:
    /// Goal created signal
    void goalCreated(const QString &threadId, const QString &goalId);
    
    /// Goal progress signal
    void goalProgress(const GoalProgressEvent &event);
    
    /// Goal completed signal
    void goalCompleted(const QString &goalId);
    
    /// Goal failed signal
    void goalFailed(const QString &goalId, const QString &reason);
    
    /// Dependency unblocked signal
    void dependencyUnblocked(const QString &goalId);
};

using GoalManagerPtr = std::shared_ptr<GoalManager>;
