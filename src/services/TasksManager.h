#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QProcess>
#include <QJsonObject>
#include <functional>

/**
 * @class TasksManager
 * @brief VS Code-like task system
 * 
 * Features:
 * - Task execution
 * - Build tasks
 * - Custom tasks
 * - Task output capture
 * - Progress tracking
 */

struct Task {
    enum Type {
        Build,
        Test,
        Custom
    };
    
    QString id;
    QString label;
    QString type;
    QString command;
    QStringList args;
    QString cwd;
    QJsonObject options;
    Type taskType = Custom;
    bool isBackground = false;
    QString problemMatcher;  // For error parsing
};

struct TaskExecution {
    QString taskId;
    QString executionId;
    QProcess* process = nullptr;
    qint64 startTime = 0;
    qint64 endTime = 0;
    int exitCode = -1;
    QString output;
    bool isRunning = false;
};

class TasksManager : public QObject {
    Q_OBJECT

public:
    static TasksManager* instance();
    
    // Task management
    void registerTask(const Task& task);
    void unregisterTask(const QString& taskId);
    QList<Task> getTasks() const;
    Task getTask(const QString& taskId) const;
    
    // Task execution
    QString executeTask(const QString& taskId, const QString& cwd = QString());
    QString executeCustomTask(const QString& command, const QStringList& args,
                             const QString& cwd = QString());
    bool isTaskRunning(const QString& taskId) const;
    
    // Execution control
    bool terminateTask(const QString& executionId);
    bool cancelTask(const QString& executionId);
    
    // Results
    TaskExecution getExecution(const QString& executionId) const;
    QString getOutput(const QString& executionId) const;
    int getExitCode(const QString& executionId) const;
    
    // Build tasks (common shortcuts)
    QString runBuildTask();
    QString runTestTask();
    
    // Recent tasks
    QStringList getRecentTasks(int maxCount = 10);
    void addRecentTask(const QString& taskId);

signals:
    void taskStarted(const QString& executionId);
    void taskOutput(const QString& executionId, const QString& output);
    void taskFinished(const QString& executionId, int exitCode);
    void taskError(const QString& executionId, const QString& error);
    void taskTerminated(const QString& executionId);

private:
    TasksManager();
    ~TasksManager() override;
    
    class Impl;
    std::unique_ptr<class Impl> m_impl;
};
