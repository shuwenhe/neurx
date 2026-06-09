#include "agent/ProgressTracker.h"
#include <QUuid>
#include <QDateTime>
#include <QJsonArray>
#include <algorithm>

ProgressTracker::ProgressTracker(QObject *parent)
    : QObject(parent)
{
}

ProgressTracker::~ProgressTracker() = default;

QString ProgressTracker::startTask(const QString &name, const QString &description)
{
    QString taskId = _generateTaskId();

    Progress progress;
    progress.taskId = taskId;
    progress.state = TaskState::Running;
    progress.startTime = QDateTime::currentDateTime();
    progress.currentStep = name;

    m_tasks[taskId] = progress;
    emit taskStarted(taskId);

    return taskId;
}

bool ProgressTracker::completeTask(const QString &taskId, bool success)
{
    auto it = m_tasks.find(taskId);
    if (it == m_tasks.end()) {
        return false;
    }

    it.value().endTime = QDateTime::currentDateTime();
    it.value().state = success ? TaskState::Completed : TaskState::Failed;
    it.value().percentage = success ? 100 : it.value().percentage;

    if (success) {
        m_successCounts[taskId]++;
        emit taskCompleted(taskId);
    } else {
        m_failureCounts[taskId]++;
        emit taskFailed(taskId);
    }

    return true;
}

bool ProgressTracker::cancelTask(const QString &taskId)
{
    auto it = m_tasks.find(taskId);
    if (it == m_tasks.end()) {
        return false;
    }

    it.value().state = TaskState::Cancelled;
    it.value().endTime = QDateTime::currentDateTime();

    return true;
}

bool ProgressTracker::retryTask(const QString &taskId)
{
    auto it = m_tasks.find(taskId);
    if (it == m_tasks.end()) {
        return false;
    }

    if (it.value().retries >= it.value().maxRetries) {
        return false;
    }

    it.value().retries++;
    it.value().state = TaskState::Running;
    it.value().startTime = QDateTime::currentDateTime();
    it.value().endTime = QDateTime();

    emit taskStarted(taskId);
    return true;
}

bool ProgressTracker::setProgress(const QString &taskId, int percentage, const QString &step)
{
    auto it = m_tasks.find(taskId);
    if (it == m_tasks.end()) {
        return false;
    }

    it.value().percentage = qBound(0, percentage, 100);
    it.value().currentStep = step;

    emit progressUpdated(taskId);
    return true;
}

bool ProgressTracker::recordMilestone(const QString &taskId, const QString &milestone)
{
    auto it = m_tasks.find(taskId);
    if (it == m_tasks.end()) {
        return false;
    }

    it.value().milestones.append(milestone);
    emit milestoneReached(taskId, milestone);

    return true;
}

bool ProgressTracker::recordError(const QString &taskId, const QString &error)
{
    auto it = m_tasks.find(taskId);
    if (it == m_tasks.end()) {
        return false;
    }

    it.value().errors.append(error);
    return true;
}

bool ProgressTracker::updateEstimate(const QString &taskId, double remainingSeconds)
{
    auto it = m_tasks.find(taskId);
    if (it == m_tasks.end()) {
        return false;
    }

    it.value().estimatedTimeRemaining = remainingSeconds;
    return true;
}

const ProgressTracker::Progress *ProgressTracker::getProgress(const QString &taskId) const
{
    auto it = m_tasks.find(taskId);
    if (it != m_tasks.end()) {
        return &it.value();
    }
    return nullptr;
}

QJsonObject ProgressTracker::getProgressJson(const QString &taskId) const
{
    auto progress = getProgress(taskId);
    if (!progress) {
        return {};
    }

    QJsonObject obj;
    obj["task_id"] = progress->taskId;
    obj["state"] = int(progress->state);
    obj["percentage"] = progress->percentage;
    obj["current_step"] = progress->currentStep;
    obj["start_time"] = progress->startTime.toString(Qt::ISODate);
    obj["retries"] = progress->retries;
    obj["milestones"] = QJsonArray::fromStringList(progress->milestones);

    QJsonArray errorArray;
    for (const auto &err : progress->errors) {
        errorArray.append(err);
    }
    obj["errors"] = errorArray;

    return obj;
}

QStringList ProgressTracker::getAllTasks() const
{
    return m_tasks.keys();
}

QStringList ProgressTracker::getActiveTasks() const
{
    QStringList active;
    for (auto it = m_tasks.begin(); it != m_tasks.end(); ++it) {
        if (it.value().state == TaskState::Running) {
            active.append(it.key());
        }
    }
    return active;
}

QJsonObject ProgressTracker::getStatistics() const
{
    QJsonObject stats;

    stats["total_tasks"] = (int)m_tasks.size();

    int completed = 0, failed = 0, running = 0;
    for (const auto &progress : m_tasks) {
        if (progress.state == TaskState::Completed) completed++;
        else if (progress.state == TaskState::Failed) failed++;
        else if (progress.state == TaskState::Running) running++;
    }

    stats["completed"] = completed;
    stats["failed"] = failed;
    stats["running"] = running;
    stats["success_rate"] = getSuccessRate();

    return stats;
}

double ProgressTracker::getSuccessRate() const
{
    int total = getTotalTasksCompleted() + getTotalTasksFailed();
    if (total == 0) return 0.0;

    return (double)getTotalTasksCompleted() / total * 100.0;
}

int ProgressTracker::getTotalTasksCompleted() const
{
    int total = 0;
    for (const auto &count : m_successCounts) {
        total += count;
    }
    return total;
}

int ProgressTracker::getTotalTasksFailed() const
{
    int total = 0;
    for (const auto &count : m_failureCounts) {
        total += count;
    }
    return total;
}

void ProgressTracker::clearTask(const QString &taskId)
{
    m_tasks.remove(taskId);
    m_successCounts.remove(taskId);
    m_failureCounts.remove(taskId);
}

void ProgressTracker::clearCompletedTasks(int olderThanMinutes)
{
    auto now = QDateTime::currentDateTime();
    QStringList toRemove;

    for (auto it = m_tasks.begin(); it != m_tasks.end(); ++it) {
        if (it.value().state == TaskState::Completed || it.value().state == TaskState::Failed) {
            if (it.value().endTime.addSecs(olderThanMinutes * 60) < now) {
                toRemove.append(it.key());
            }
        }
    }

    for (const auto &taskId : toRemove) {
        clearTask(taskId);
    }
}

QString ProgressTracker::_generateTaskId()
{
    return "task-" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(12);
}
