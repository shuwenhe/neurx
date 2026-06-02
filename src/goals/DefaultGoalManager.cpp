#include "DefaultGoalManager.h"
#include <QDebug>
#include <QUuid>

DefaultGoalManager::DefaultGoalManager(QObject *parent)
    : GoalManager(parent)
{
}

void DefaultGoalManager::createGoal(const QString &threadId,
                                   const GoalMetadata &metadata,
                                   GoalCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    Goal goal;
    goal.metadata = metadata;
    goal.metadata.id = QUuid::createUuid().toString();
    goal.metadata.status = GoalStatus::Created;
    
    GoalEntry entry;
    entry.goal = goal;
    
    m_goals[goal.metadata.id] = entry;
    
    if (!m_threadGoals.contains(threadId)) {
        m_threadGoals[threadId] = QStringList();
    }
    m_threadGoals[threadId].append(goal.metadata.id);
    
    Goal result = goal;
    locker.unlock();
    
    emit goalCreated(threadId, goal.metadata.id);
    
    if (callback) callback(true, result);
}

Goal DefaultGoalManager::getGoal(const QString &goalId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it != m_goals.end()) {
        return it->goal;
    }
    
    return Goal();
}

QVector<Goal> DefaultGoalManager::getGoalsInThread(const QString &threadId) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<Goal> goals;
    
    auto it = m_threadGoals.find(threadId);
    if (it != m_threadGoals.end()) {
        for (const auto &goalId : it.value()) {
            auto goalIt = m_goals.find(goalId);
            if (goalIt != m_goals.end()) {
                goals.append(goalIt->goal);
            }
        }
    }
    
    return goals;
}

void DefaultGoalManager::updateGoal(const Goal &goal,
                                   GoalCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goal.metadata.id);
    if (it != m_goals.end()) {
        it->goal = goal;
        it->goal.metadata.lastModifiedAt = QDateTime::currentDateTime();
        it->lastModified = QDateTime::currentDateTime();
        
        Goal result = goal;
        locker.unlock();
        
        if (callback) callback(true, result);
    } else {
        locker.unlock();
        if (callback) callback(false, Goal());
    }
}

void DefaultGoalManager::deleteGoal(const QString &goalId,
                                   std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    // Remove from thread goals
    for (auto threadIt = m_threadGoals.begin(); threadIt != m_threadGoals.end(); ++threadIt) {
        threadIt->removeAll(goalId);
    }
    
    m_goals.erase(m_goals.find(goalId));
    locker.unlock();
    
    if (callback) callback(true);
}

void DefaultGoalManager::startGoal(const QString &goalId,
                                  GoalProgressCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it == m_goals.end()) {
        locker.unlock();
        return;
    }
    
    GoalStatus oldStatus = it->goal.metadata.status;
    it->goal.metadata.status = GoalStatus::Active;
    it->goal.metadata.startedAt = QDateTime::currentDateTime();
    
    GoalProgressEvent event;
    event.goalId = goalId;
    event.oldStatus = oldStatus;
    event.newStatus = GoalStatus::Active;
    event.progressPercentage = it->goal.progressPercentage;
    event.message = "Goal started";
    
    locker.unlock();
    
    emit goalProgress(event);
    
    if (callback) callback(event);
}

void DefaultGoalManager::pauseGoal(const QString &goalId,
                                  GoalProgressCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it == m_goals.end()) {
        locker.unlock();
        return;
    }
    
    GoalStatus oldStatus = it->goal.metadata.status;
    it->goal.metadata.status = GoalStatus::Paused;
    
    GoalProgressEvent event;
    event.goalId = goalId;
    event.oldStatus = oldStatus;
    event.newStatus = GoalStatus::Paused;
    event.message = "Goal paused";
    
    locker.unlock();
    
    emit goalProgress(event);
    
    if (callback) callback(event);
}

void DefaultGoalManager::resumeGoal(const QString &goalId,
                                   GoalProgressCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it == m_goals.end()) {
        locker.unlock();
        return;
    }
    
    GoalStatus oldStatus = it->goal.metadata.status;
    it->goal.metadata.status = GoalStatus::Active;
    
    GoalProgressEvent event;
    event.goalId = goalId;
    event.oldStatus = oldStatus;
    event.newStatus = GoalStatus::Active;
    event.message = "Goal resumed";
    
    locker.unlock();
    
    emit goalProgress(event);
    
    if (callback) callback(event);
}

void DefaultGoalManager::completeGoal(const QString &goalId,
                                     GoalProgressCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it == m_goals.end()) {
        locker.unlock();
        return;
    }
    
    GoalStatus oldStatus = it->goal.metadata.status;
    it->goal.metadata.status = GoalStatus::Completed;
    it->goal.metadata.completedAt = QDateTime::currentDateTime();
    it->goal.progressPercentage = 100.0;
    
    GoalProgressEvent event;
    event.goalId = goalId;
    event.oldStatus = oldStatus;
    event.newStatus = GoalStatus::Completed;
    event.progressPercentage = 100.0;
    event.message = "Goal completed";
    
    locker.unlock();
    
    emit goalCompleted(goalId);
    emit goalProgress(event);
    
    if (callback) callback(event);
}

void DefaultGoalManager::failGoal(const QString &goalId,
                                 const QString &reason,
                                 GoalProgressCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it == m_goals.end()) {
        locker.unlock();
        return;
    }
    
    GoalStatus oldStatus = it->goal.metadata.status;
    it->goal.metadata.status = GoalStatus::Failed;
    it->goal.metadata.completedAt = QDateTime::currentDateTime();
    
    GoalProgressEvent event;
    event.goalId = goalId;
    event.oldStatus = oldStatus;
    event.newStatus = GoalStatus::Failed;
    event.message = "Goal failed: " + reason;
    
    locker.unlock();
    
    emit goalFailed(goalId, reason);
    emit goalProgress(event);
    
    if (callback) callback(event);
}

void DefaultGoalManager::cancelGoal(const QString &goalId,
                                   GoalProgressCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it == m_goals.end()) {
        locker.unlock();
        return;
    }
    
    GoalStatus oldStatus = it->goal.metadata.status;
    it->goal.metadata.status = GoalStatus::Cancelled;
    
    GoalProgressEvent event;
    event.goalId = goalId;
    event.oldStatus = oldStatus;
    event.newStatus = GoalStatus::Cancelled;
    event.message = "Goal cancelled";
    
    locker.unlock();
    
    emit goalProgress(event);
    
    if (callback) callback(event);
}

void DefaultGoalManager::updateProgress(const QString &goalId,
                                       double percentage,
                                       int estimatedHoursRemaining,
                                       std::function<void(bool)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it != m_goals.end()) {
        it->goal.progressPercentage = percentage;
        it->goal.estimatedHoursRemaining = estimatedHoursRemaining;
        locker.unlock();
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

void DefaultGoalManager::addCriterion(const QString &goalId,
                                     const CompletionCriterion &criterion,
                                     std::function<void(bool)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it != m_goals.end()) {
        it->goal.criteria.append(criterion);
        locker.unlock();
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

void DefaultGoalManager::updateCriterionProgress(const QString &goalId,
                                                const QString &criterionId,
                                                const QVariantMap &progress,
                                                std::function<void(bool)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it != m_goals.end()) {
        for (auto &criterion : it->goal.criteria) {
            if (criterion.id == criterionId) {
                if (criterion.type == "metric") {
                    criterion.currentValue = progress["currentValue"].toDouble();
                } else if (criterion.type == "checklist") {
                    criterion.itemsCompleted = progress["itemsCompleted"].toInt();
                } else if (criterion.type == "approval") {
                    criterion.approvalReceived = progress["approvalReceived"].toBool();
                }
                break;
            }
        }
        
        recalculateProgress(it->goal);
        locker.unlock();
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

bool DefaultGoalManager::isGoalComplete(const QString &goalId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it != m_goals.end()) {
        for (const auto &criterion : it->goal.criteria) {
            if (!criterion.isMet()) {
                return false;
            }
        }
        return true;
    }
    
    return false;
}

void DefaultGoalManager::addStep(const QString &goalId,
                                const GoalStep &step,
                                std::function<void(bool)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it != m_goals.end()) {
        it->goal.steps.append(step);
        locker.unlock();
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

void DefaultGoalManager::updateStepStatus(const QString &goalId,
                                         const QString &stepId,
                                         const QString &status,
                                         std::function<void(bool)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it != m_goals.end()) {
        for (auto &step : it->goal.steps) {
            if (step.id == stepId) {
                step.status = status;
                if (status == "in_progress") {
                    step.startedAt = QDateTime::currentDateTime();
                } else if (status == "completed") {
                    step.completedAt = QDateTime::currentDateTime();
                }
                break;
            }
        }
        locker.unlock();
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

QVector<GoalStep> DefaultGoalManager::getSteps(const QString &goalId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it != m_goals.end()) {
        return it->goal.steps;
    }
    
    return QVector<GoalStep>();
}

void DefaultGoalManager::addDependency(const QString &goalId,
                                      const GoalDependency &dependency,
                                      std::function<void(bool)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it != m_goals.end()) {
        it->goal.dependencies.append(dependency);
        
        if (dependency.blocking) {
            it->goal.metadata.status = GoalStatus::Blocked;
        }
        
        locker.unlock();
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

void DefaultGoalManager::removeDependency(const QString &goalId,
                                         const QString &dependentGoalId,
                                         std::function<void(bool)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it != m_goals.end()) {
        it->goal.dependencies.erase(
            std::remove_if(it->goal.dependencies.begin(),
                          it->goal.dependencies.end(),
                          [&](const GoalDependency &dep) {
                              return dep.goalId == dependentGoalId;
                          }),
            it->goal.dependencies.end()
        );
        
        checkBlockedDependencies(goalId);
        locker.unlock();
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

bool DefaultGoalManager::checkDependencies(const QString &goalId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it != m_goals.end()) {
        for (const auto &dep : it->goal.dependencies) {
            auto depIt = m_goals.find(dep.goalId);
            if (depIt != m_goals.end()) {
                if (depIt->goal.metadata.status != GoalStatus::Completed) {
                    if (dep.blocking) {
                        return false;
                    }
                }
            } else if (!dep.optional) {
                return false;
            }
        }
        return true;
    }
    
    return false;
}

QStringList DefaultGoalManager::getDependentGoals(const QString &goalId) const
{
    QMutexLocker locker(&m_mutex);
    
    QStringList dependents;
    
    for (const auto &entry : m_goals) {
        for (const auto &dep : entry.goal.dependencies) {
            if (dep.goalId == goalId) {
                dependents.append(entry.goal.metadata.id);
                break;
            }
        }
    }
    
    return dependents;
}

void DefaultGoalManager::createSnapshot(const QString &goalId,
                                       std::function<void(const GoalSnapshot &)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it != m_goals.end()) {
        GoalSnapshot snapshot;
        snapshot.goalId = goalId;
        snapshot.snapshotId = QUuid::createUuid().toString();
        snapshot.goal = it->goal;
        
        it->snapshots.append(snapshot);
        
        locker.unlock();
        
        if (callback) callback(snapshot);
    } else {
        locker.unlock();
    }
}

void DefaultGoalManager::restoreSnapshot(const GoalSnapshot &snapshot,
                                        GoalCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(snapshot.goalId);
    if (it != m_goals.end()) {
        it->goal = snapshot.goal;
        locker.unlock();
        
        if (callback) callback(true, snapshot.goal);
    } else {
        locker.unlock();
        if (callback) callback(false, Goal());
    }
}

void DefaultGoalManager::rollbackLastMutation(const QString &goalId,
                                             GoalCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_goals.find(goalId);
    if (it != m_goals.end() && !it->mutations.isEmpty()) {
        auto lastMutation = it->mutations.last();
        
        if (lastMutation.reversible) {
            // Restore previous state
            Goal result = it->goal;
            it->mutations.pop_back();
            locker.unlock();
            
            if (callback) callback(true, result);
        } else {
            locker.unlock();
            if (callback) callback(false, it->goal);
        }
    } else {
        locker.unlock();
        if (callback) callback(false, Goal());
    }
}

QVector<Goal> DefaultGoalManager::getActiveGoals(const QString &threadId) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<Goal> active;
    
    auto it = m_threadGoals.find(threadId);
    if (it != m_threadGoals.end()) {
        for (const auto &goalId : it.value()) {
            auto goalIt = m_goals.find(goalId);
            if (goalIt != m_goals.end() && goalIt->goal.metadata.status == GoalStatus::Active) {
                active.append(goalIt->goal);
            }
        }
    }
    
    return active;
}

QVector<Goal> DefaultGoalManager::getCompletedGoals(const QString &threadId) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<Goal> completed;
    
    auto it = m_threadGoals.find(threadId);
    if (it != m_threadGoals.end()) {
        for (const auto &goalId : it.value()) {
            auto goalIt = m_goals.find(goalId);
            if (goalIt != m_goals.end() && goalIt->goal.metadata.status == GoalStatus::Completed) {
                completed.append(goalIt->goal);
            }
        }
    }
    
    return completed;
}

QVector<Goal> DefaultGoalManager::getBlockedGoals(const QString &threadId) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<Goal> blocked;
    
    auto it = m_threadGoals.find(threadId);
    if (it != m_threadGoals.end()) {
        for (const auto &goalId : it.value()) {
            auto goalIt = m_goals.find(goalId);
            if (goalIt != m_goals.end() && goalIt->goal.metadata.status == GoalStatus::Blocked) {
                blocked.append(goalIt->goal);
            }
        }
    }
    
    return blocked;
}

QVector<Goal> DefaultGoalManager::searchGoals(const QString &threadId,
                                             const QVariantMap &criteria) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<Goal> results;
    
    auto it = m_threadGoals.find(threadId);
    if (it != m_threadGoals.end()) {
        for (const auto &goalId : it.value()) {
            auto goalIt = m_goals.find(goalId);
            if (goalIt != m_goals.end()) {
                // Apply search criteria
                bool matches = true;
                
                if (criteria.contains("title")) {
                    if (!goalIt->goal.metadata.title.contains(criteria["title"].toString())) {
                        matches = false;
                    }
                }
                
                if (criteria.contains("status")) {
                    if (static_cast<int>(goalIt->goal.metadata.status) != criteria["status"].toInt()) {
                        matches = false;
                    }
                }
                
                if (matches) {
                    results.append(goalIt->goal);
                }
            }
        }
    }
    
    return results;
}

QVector<Goal> DefaultGoalManager::getOverdueGoals() const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<Goal> overdue;
    QDateTime now = QDateTime::currentDateTime();
    
    for (const auto &entry : m_goals) {
        if (!entry.goal.metadata.dueDate.isNull() &&
            entry.goal.metadata.dueDate < now &&
            entry.goal.metadata.status != GoalStatus::Completed &&
            entry.goal.metadata.status != GoalStatus::Cancelled) {
            overdue.append(entry.goal);
        }
    }
    
    return overdue;
}

QVector<Goal> DefaultGoalManager::getUpcomingGoals(int daysAhead) const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<Goal> upcoming;
    QDateTime now = QDateTime::currentDateTime();
    QDateTime future = now.addDays(daysAhead);
    
    for (const auto &entry : m_goals) {
        if (!entry.goal.metadata.dueDate.isNull() &&
            entry.goal.metadata.dueDate > now &&
            entry.goal.metadata.dueDate <= future &&
            entry.goal.metadata.status != GoalStatus::Completed) {
            upcoming.append(entry.goal);
        }
    }
    
    return upcoming;
}

QVariantMap DefaultGoalManager::getThreadGoalStats(const QString &threadId) const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    auto goals = getGoalsInThread(threadId);
    
    stats["totalGoals"] = goals.size();
    stats["activeGoals"] = 0;
    stats["completedGoals"] = 0;
    stats["failedGoals"] = 0;
    stats["blockedGoals"] = 0;
    stats["averageProgress"] = 0.0;
    
    double totalProgress = 0.0;
    
    for (const auto &goal : goals) {
        switch (goal.metadata.status) {
            case GoalStatus::Active: stats["activeGoals"] = stats["activeGoals"].toInt() + 1; break;
            case GoalStatus::Completed: stats["completedGoals"] = stats["completedGoals"].toInt() + 1; break;
            case GoalStatus::Failed: stats["failedGoals"] = stats["failedGoals"].toInt() + 1; break;
            case GoalStatus::Blocked: stats["blockedGoals"] = stats["blockedGoals"].toInt() + 1; break;
            default: break;
        }
        totalProgress += goal.progressPercentage;
    }
    
    if (goals.size() > 0) {
        stats["averageProgress"] = totalProgress / goals.size();
    }
    
    return stats;
}

QVariantMap DefaultGoalManager::getUserGoalStats(const QString &userId) const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    int totalGoals = 0;
    int completedGoals = 0;
    
    for (const auto &entry : m_goals) {
        if (entry.goal.metadata.ownerId == userId) {
            totalGoals++;
            if (entry.goal.metadata.status == GoalStatus::Completed) {
                completedGoals++;
            }
        }
    }
    
    stats["totalGoals"] = totalGoals;
    stats["completedGoals"] = completedGoals;
    stats["completionRate"] = totalGoals > 0 ? (completedGoals * 100.0 / totalGoals) : 0.0;
    
    return stats;
}

void DefaultGoalManager::recalculateProgress(Goal &goal)
{
    if (goal.criteria.isEmpty()) {
        return;
    }
    
    double totalProgress = 0.0;
    int metCriteria = 0;
    
    for (const auto &criterion : goal.criteria) {
        if (criterion.isMet()) {
            metCriteria++;
        }
    }
    
    goal.progressPercentage = (metCriteria * 100.0) / goal.criteria.size();
}

void DefaultGoalManager::checkBlockedDependencies(const QString &goalId)
{
    auto it = m_goals.find(goalId);
    if (it != m_goals.end() && it->goal.metadata.status == GoalStatus::Completed) {
        // Notify dependent goals
        auto dependents = getDependentGoals(goalId);
        for (const auto &dependent : dependents) {
            emit dependencyUnblocked(dependent);
        }
    }
}

#include "moc_DefaultGoalManager.cpp"
