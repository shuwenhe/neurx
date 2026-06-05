#include "TasksManager.h"
#include <QUuid>
#include <QDateTime>
#include <QDir>

class TasksManager::Impl {
public:
    QList<Task> tasks;
    QMap<QString, TaskExecution> executions;
    QStringList recentTasks;
    static constexpr int MAX_RECENT = 50;
    
    QString generateId() {
        return QUuid::createUuid().toString(QUuid::WithoutBraces);
    }
};

TasksManager* TasksManager::instance() {
    static TasksManager s_instance;
    return &s_instance;
}

TasksManager::TasksManager()
    : m_impl(std::make_unique<Impl>()) {
}

TasksManager::~TasksManager() = default;

void TasksManager::registerTask(const Task& task) {
    // Check if already exists
    for (auto& t : m_impl->tasks) {
        if (t.id == task.id) {
            t = task;
            return;
        }
    }
    
    m_impl->tasks.append(task);
}

void TasksManager::unregisterTask(const QString& taskId) {
    m_impl->tasks.erase(
        std::remove_if(m_impl->tasks.begin(), m_impl->tasks.end(),
                      [&taskId](const Task& t) { return t.id == taskId; }),
        m_impl->tasks.end()
    );
}

QList<Task> TasksManager::getTasks() const {
    return m_impl->tasks;
}

Task TasksManager::getTask(const QString& taskId) const {
    for (const auto& task : m_impl->tasks) {
        if (task.id == taskId) {
            return task;
        }
    }
    return Task();
}

QString TasksManager::executeTask(const QString& taskId, const QString& cwd) {
    auto task = getTask(taskId);
    if (task.id.isEmpty()) {
        return QString();
    }
    
    return executeCustomTask(task.command, task.args, 
                            cwd.isEmpty() ? task.cwd : cwd);
}

QString TasksManager::executeCustomTask(const QString& command, const QStringList& args,
                                        const QString& cwd) {
    QString executionId = m_impl->generateId();
    
    auto process = new QProcess();
    if (!cwd.isEmpty()) {
        process->setWorkingDirectory(cwd);
    }
    
    TaskExecution execution;
    execution.taskId = command;
    execution.executionId = executionId;
    execution.process = process;
    execution.startTime = QDateTime::currentMSecsSinceEpoch();
    execution.isRunning = true;
    
    m_impl->executions[executionId] = execution;
    
    // Connect signals
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, executionId](int exitCode, QProcess::ExitStatus exitStatus) {
        if (m_impl->executions.contains(executionId)) {
            auto& exec = m_impl->executions[executionId];
            exec.exitCode = exitCode;
            exec.endTime = QDateTime::currentMSecsSinceEpoch();
            exec.isRunning = false;
            emit taskFinished(executionId, exitCode);
        }
    });
    
    connect(process, &QProcess::readyReadStandardOutput,
            this, [this, executionId]() {
        if (m_impl->executions.contains(executionId)) {
            auto& exec = m_impl->executions[executionId];
            QString output = QString::fromUtf8(exec.process->readAllStandardOutput());
            exec.output.append(output);
            emit taskOutput(executionId, output);
        }
    });
    
    connect(process, &QProcess::readyReadStandardError,
            this, [this, executionId]() {
        if (m_impl->executions.contains(executionId)) {
            auto& exec = m_impl->executions[executionId];
            QString output = QString::fromUtf8(exec.process->readAllStandardError());
            exec.output.append(output);
            emit taskOutput(executionId, output);
        }
    });
    
    process->start(command, args);
    if (!process->waitForStarted()) {
        emit taskError(executionId, "Failed to start task");
        m_impl->executions.remove(executionId);
        delete process;
        return QString();
    }
    
    emit taskStarted(executionId);
    return executionId;
}

bool TasksManager::isTaskRunning(const QString& taskId) const {
    for (const auto& exec : m_impl->executions) {
        if (exec.taskId == taskId && exec.isRunning) {
            return true;
        }
    }
    return false;
}

bool TasksManager::terminateTask(const QString& executionId) {
    auto it = m_impl->executions.find(executionId);
    if (it == m_impl->executions.end() || !it->process) {
        return false;
    }
    
    it->process->terminate();
    if (!it->process->waitForFinished(3000)) {
        it->process->kill();
    }
    
    emit taskTerminated(executionId);
    return true;
}

bool TasksManager::cancelTask(const QString& executionId) {
    return terminateTask(executionId);
}

TaskExecution TasksManager::getExecution(const QString& executionId) const {
    return m_impl->executions.value(executionId);
}

QString TasksManager::getOutput(const QString& executionId) const {
    return m_impl->executions.value(executionId).output;
}

int TasksManager::getExitCode(const QString& executionId) const {
    return m_impl->executions.value(executionId).exitCode;
}

QString TasksManager::runBuildTask() {
    for (const auto& task : m_impl->tasks) {
        if (task.type == "build") {
            return executeTask(task.id);
        }
    }
    return QString();
}

QString TasksManager::runTestTask() {
    for (const auto& task : m_impl->tasks) {
        if (task.type == "test") {
            return executeTask(task.id);
        }
    }
    return QString();
}

QStringList TasksManager::getRecentTasks(int maxCount) {
    return m_impl->recentTasks.mid(
        qMax(0, m_impl->recentTasks.size() - maxCount)
    );
}

void TasksManager::addRecentTask(const QString& taskId) {
    m_impl->recentTasks.removeAll(taskId);
    m_impl->recentTasks.append(taskId);
    
    if (m_impl->recentTasks.size() > m_impl->MAX_RECENT) {
        m_impl->recentTasks.removeFirst();
    }
}
