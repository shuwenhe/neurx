#pragma once

#include <QString>
#include <QMap>
#include <QJsonObject>
#include <QDateTime>
#include <memory>
#include <QObject>

/**
 * @class ProgressTracker
 * @brief Tracks execution progress, milestones, and task completion
 *
 * Features:
 * - Multi-stage task tracking
 * - Progress percentage and ETA
 * - Milestone tracking
 * - Error logging
 * - Performance metrics
 * - Retry mechanism
 *
 * Usage:
 *   ProgressTracker tracker;
 *   QString taskId = tracker.startTask("compile");
 *   tracker.setProgress(taskId, 25, "Initializing...");
 *   tracker.recordMilestone(taskId, "phase_1_complete");
 */

class ProgressTracker : public QObject {
    Q_OBJECT

public:
    explicit ProgressTracker(QObject *parent = nullptr);
    ~ProgressTracker();

    enum class TaskState { Pending, Running, Completed, Failed, Cancelled };

    struct Progress {
        QString taskId;
        TaskState state = TaskState::Pending;
        int percentage = 0;
        QString currentStep;
        QDateTime startTime;
        QDateTime endTime;
        QStringList milestones;
        QStringList errors;
        int retries = 0;
        int maxRetries = 3;
        double estimatedTimeRemaining = -1;  // seconds
    };

    // Task management
    QString startTask(const QString &name, const QString &description = "");
    bool completeTask(const QString &taskId, bool success = true);
    bool cancelTask(const QString &taskId);
    bool retryTask(const QString &taskId);

    // Progress updates
    bool setProgress(const QString &taskId, int percentage, const QString &step);
    bool recordMilestone(const QString &taskId, const QString &milestone);
    bool recordError(const QString &taskId, const QString &error);
    bool updateEstimate(const QString &taskId, double remainingSeconds);

    // Queries
    const Progress *getProgress(const QString &taskId) const;
    QJsonObject getProgressJson(const QString &taskId) const;
    QStringList getAllTasks() const;
    QStringList getActiveTasks() const;

    // Statistics
    QJsonObject getStatistics() const;
    double getSuccessRate() const;
    int getTotalTasksCompleted() const;
    int getTotalTasksFailed() const;

    // Cleanup
    void clearTask(const QString &taskId);
    void clearCompletedTasks(int olderThanMinutes = 60);

signals:
    void taskStarted(const QString &taskId);
    void taskCompleted(const QString &taskId);
    void taskFailed(const QString &taskId);
    void progressUpdated(const QString &taskId);
    void milestoneReached(const QString &taskId, const QString &milestone);

private:
    QMap<QString, Progress> m_tasks;
    QMap<QString, int> m_successCounts;
    QMap<QString, int> m_failureCounts;

    QString _generateTaskId();
};
