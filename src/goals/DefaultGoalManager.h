#pragma once

#include "GoalManager.h"
#include <QMap>
#include <QMutex>

/**
 * @class DefaultGoalManager
 * @brief Default goal manager implementation
 * 
 * Features:
 * - Thread-level goal storage
 * - State mutation tracking
 * - Dependency resolution
 * - Snapshot and rollback
 * - Progress tracking
 */
class DefaultGoalManager : public GoalManager {
    Q_OBJECT
public:
    explicit DefaultGoalManager(QObject *parent = nullptr);
    ~DefaultGoalManager() = default;
    
    // Creation & Management
    void createGoal(const QString &threadId,
                   const GoalMetadata &metadata,
                   GoalCallback callback) override;
    Goal getGoal(const QString &goalId) const override;
    QVector<Goal> getGoalsInThread(const QString &threadId) const override;
    void updateGoal(const Goal &goal,
                   GoalCallback callback) override;
    void deleteGoal(const QString &goalId,
                   std::function<void(bool success)> callback) override;
    
    // State Mutations
    void startGoal(const QString &goalId,
                  GoalProgressCallback callback) override;
    void pauseGoal(const QString &goalId,
                  GoalProgressCallback callback) override;
    void resumeGoal(const QString &goalId,
                   GoalProgressCallback callback) override;
    void completeGoal(const QString &goalId,
                     GoalProgressCallback callback) override;
    void failGoal(const QString &goalId,
                 const QString &reason,
                 GoalProgressCallback callback) override;
    void cancelGoal(const QString &goalId,
                   GoalProgressCallback callback) override;
    
    // Progress Tracking
    void updateProgress(const QString &goalId,
                       double percentage,
                       int estimatedHoursRemaining,
                       std::function<void(bool)> callback) override;
    void addCriterion(const QString &goalId,
                     const CompletionCriterion &criterion,
                     std::function<void(bool)> callback) override;
    void updateCriterionProgress(const QString &goalId,
                                const QString &criterionId,
                                const QVariantMap &progress,
                                std::function<void(bool)> callback) override;
    bool isGoalComplete(const QString &goalId) const override;
    
    // Steps
    void addStep(const QString &goalId,
                const GoalStep &step,
                std::function<void(bool)> callback) override;
    void updateStepStatus(const QString &goalId,
                         const QString &stepId,
                         const QString &status,
                         std::function<void(bool)> callback) override;
    QVector<GoalStep> getSteps(const QString &goalId) const override;
    
    // Dependencies
    void addDependency(const QString &goalId,
                      const GoalDependency &dependency,
                      std::function<void(bool)> callback) override;
    void removeDependency(const QString &goalId,
                         const QString &dependentGoalId,
                         std::function<void(bool)> callback) override;
    bool checkDependencies(const QString &goalId) const override;
    QStringList getDependentGoals(const QString &goalId) const override;
    
    // Snapshots & Rollback
    void createSnapshot(const QString &goalId,
                       std::function<void(const GoalSnapshot &)> callback) override;
    void restoreSnapshot(const GoalSnapshot &snapshot,
                        GoalCallback callback) override;
    void rollbackLastMutation(const QString &goalId,
                             GoalCallback callback) override;
    
    // Queries
    QVector<Goal> getActiveGoals(const QString &threadId) const override;
    QVector<Goal> getCompletedGoals(const QString &threadId) const override;
    QVector<Goal> getBlockedGoals(const QString &threadId) const override;
    QVector<Goal> searchGoals(const QString &threadId,
                             const QVariantMap &criteria) const override;
    
    // Notifications
    QVector<Goal> getOverdueGoals() const override;
    QVector<Goal> getUpcomingGoals(int daysAhead = 7) const override;
    
    // Statistics
    QVariantMap getThreadGoalStats(const QString &threadId) const override;
    QVariantMap getUserGoalStats(const QString &userId) const override;

private:
    struct GoalEntry {
        Goal goal;
        QVector<GoalSnapshot> snapshots;
        QVector<GoalStateMutation> mutations;
        QDateTime lastModified{QDateTime::currentDateTime()};
    };
    
    QMap<QString, GoalEntry> m_goals;           // goalId -> GoalEntry
    QMap<QString, QStringList> m_threadGoals;   // threadId -> [goalId, ...]
    mutable QMutex m_mutex;
    
    // State management
    void applyMutation(Goal &goal, const GoalStateMutation &mutation);
    GoalStateMutation createMutation(const QString &goalId,
                                    const QString &type,
                                    const QVariantMap &changes);
    
    // Helpers
    void recalculateProgress(Goal &goal);
    void checkBlockedDependencies(const QString &goalId);
};

using DefaultGoalManagerPtr = std::shared_ptr<DefaultGoalManager>;
