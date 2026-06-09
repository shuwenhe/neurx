#include "IterativeExecutor.h"
#include <QDateTime>
#include <QFile>
#include <QJsonDocument>
#include <QElapsedTimer>

IterativeExecutor::IterativeExecutor(QObject* parent)
    : QObject(parent), m_state(Idle), m_userValidationNeeded(false), m_debugMode(false) {
    
    m_config.maxIterations = 10;
    m_config.maxTimeoutSeconds = 300;
    m_config.completionThreshold = 0.9f;
    m_config.autoValidateCompletion = true;
    m_config.enableUserInterrupts = true;
    m_config.delayBetweenIterationMs = 100;
    
    m_stats = {0, 0, 0, 0, 0.0f, {}};
}

IterativeExecutor::~IterativeExecutor() {
    if (m_state == Running) {
        cancelLoop("Destructor called");
    }
}

void IterativeExecutor::startLoop(const QString& taskDescription) {
    m_taskDescription = taskDescription;
    m_state = Running;
    m_currentIteration.iteration = 1;
    m_currentIteration.taskDescription = taskDescription;
    m_currentIteration.progressPercentage = 0.0f;
    m_currentIteration.taskCompleted = false;
    m_history.clear();
    
    emit loopStarted(taskDescription);
    executeIteration();
}

void IterativeExecutor::pauseLoop() {
    if (m_state == Running) {
        m_state = Paused;
        emit loopPaused();
    }
}

void IterativeExecutor::resumeLoop() {
    if (m_state == Paused) {
        m_state = Running;
        executeIteration();
    }
}

void IterativeExecutor::cancelLoop(const QString& reason) {
    m_state = CancelledByUser;
    emit loopCancelled(reason);
}

void IterativeExecutor::stopLoop() {
    m_state = Idle;
}

IterativeExecutor::LoopState IterativeExecutor::getLoopState() const {
    return m_state;
}

void IterativeExecutor::setMaxIterations(int max) {
    m_config.maxIterations = max;
}

void IterativeExecutor::setMaxTimeout(int seconds) {
    m_config.maxTimeoutSeconds = seconds;
}

void IterativeExecutor::setCompletionThreshold(float threshold) {
    m_config.completionThreshold = threshold;
}

void IterativeExecutor::configureLoop(const LoopConfiguration& config) {
    m_config = config;
}

IterativeExecutor::LoopConfiguration IterativeExecutor::getConfiguration() const {
    return m_config;
}

IterativeExecutor::IterationState IterativeExecutor::getCurrentIteration() const {
    return m_currentIteration;
}

QVector<IterativeExecutor::IterationState> IterativeExecutor::getIterationHistory() {
    return m_history;
}

void IterativeExecutor::recordIteration(const QString& action, const QString& result) {
    m_currentIteration.currentAction = action;
    m_currentIteration.results.append(result);
    m_currentIteration.previousActions.append(action);
    
    m_stats.totalIterations++;
    m_stats.appliedStrategies << action;
    
    emit actionExecuted(action, result);
}

void IterativeExecutor::markIterationAsComplete() {
    m_history.append(m_currentIteration);
    m_currentIteration.iteration++;
    m_currentIteration.currentAction = "";
    m_currentIteration.results.clear();
    
    emit iterationCompleted(m_currentIteration.iteration - 1);
}

bool IterativeExecutor::isTaskComplete() {
    checkTaskCompletion();
    return m_currentIteration.taskCompleted;
}

float IterativeExecutor::getCompletionScore() {
    return calculateCompletionScore();
}

QString IterativeExecutor::getCompletionReason() {
    auto criteria = checkExitCriteria();
    switch (criteria) {
        case TaskCompleted: return "Task completed successfully";
        case MaxIterationsReached: return "Maximum iterations reached";
        case TimeoutReached: return "Timeout exceeded";
        case UserCancelled: return "Cancelled by user";
        case ErrorOccurred: return "Error occurred";
    }
    return "Unknown reason";
}

bool IterativeExecutor::validateCompletion(const QString& output) {
    return output.length() > 0 && !output.contains("error", Qt::CaseInsensitive);
}

float IterativeExecutor::getOverallProgress() {
    float progress = static_cast<float>(m_currentIteration.iteration) / m_config.maxIterations;
    progress *= m_currentIteration.progressPercentage / 100.0f;
    return progress * 100.0f;
}

int IterativeExecutor::getCurrentIterationNumber() const {
    return m_currentIteration.iteration;
}

int IterativeExecutor::getRemainingIterations() {
    return m_config.maxIterations - m_currentIteration.iteration + 1;
}

QString IterativeExecutor::getProgressSummary() {
    return QString("Iteration %1/%2 - Progress: %3% - Completed: %4")
        .arg(m_currentIteration.iteration)
        .arg(m_config.maxIterations)
        .arg(static_cast<int>(getOverallProgress()))
        .arg(m_currentIteration.taskCompleted ? "Yes" : "No");
}

IterativeExecutor::ExitCriterion IterativeExecutor::checkExitCriteria() {
    if (isTaskComplete()) {
        return TaskCompleted;
    }
    
    if (m_currentIteration.iteration >= m_config.maxIterations) {
        return MaxIterationsReached;
    }
    
    if (m_state == CancelledByUser) {
        return UserCancelled;
    }
    
    return TaskCompleted;
}

bool IterativeExecutor::shouldContinueLoop() {
    return m_state == Running && 
           m_currentIteration.iteration < m_config.maxIterations &&
           !isTaskComplete();
}

QStringList IterativeExecutor::getExitReasons() {
    QStringList reasons;
    if (isTaskComplete()) {
        reasons << "Task completed";
    }
    if (m_currentIteration.iteration >= m_config.maxIterations) {
        reasons << "Max iterations reached";
    }
    return reasons;
}

void IterativeExecutor::suggestNextAction() {
    if (m_currentIteration.previousActions.isEmpty()) {
        m_currentIteration.currentAction = "Analyze requirements";
    } else {
        m_currentIteration.currentAction = "Continue refinement";
    }
}

QString IterativeExecutor::getRecommendedAction() {
    return m_currentIteration.currentAction;
}

QStringList IterativeExecutor::getPreviousActions() {
    return m_currentIteration.previousActions;
}

void IterativeExecutor::learnFromPreviousAttempts() {
    // Analyze previous attempts to improve strategy
    if (m_history.size() > 1) {
        qDebug() << "Learning from" << m_history.size() << "previous iterations";
    }
}

void IterativeExecutor::applyRefinementStrategy(RefinementStrategy strategy) {
    switch (strategy) {
        case Incremental:
            m_currentIteration.currentAction = "Incrementally refine solution";
            break;
        case Recursive:
            m_currentIteration.currentAction = "Recursively decompose problem";
            break;
        case Parallel:
            m_currentIteration.currentAction = "Explore parallel solutions";
            break;
        case BacktrackAndRetry:
            m_currentIteration.currentAction = "Backtrack and retry";
            break;
        case AlternateApproach:
            m_currentIteration.currentAction = "Try alternate approach";
            break;
    }
}

IterativeExecutor::RefinementStrategy IterativeExecutor::selectBestStrategy() {
    return Incremental;
}

void IterativeExecutor::saveLoopState(const QString& filepath) {
    QJsonObject state;
    state["iteration"] = m_currentIteration.iteration;
    state["taskDescription"] = m_taskDescription;
    state["progress"] = m_currentIteration.progressPercentage;
    state["taskCompleted"] = m_currentIteration.taskCompleted;
    
    QJsonDocument doc(state);
    QFile file(filepath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson());
        file.close();
    }
}

void IterativeExecutor::restoreLoopState(const QString& filepath) {
    QFile file(filepath);
    if (file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        QJsonObject state = doc.object();
        
        m_currentIteration.iteration = state.value("iteration").toInt(1);
        m_taskDescription = state.value("taskDescription").toString();
        m_currentIteration.progressPercentage = state.value("progress").toDouble(0.0);
        m_currentIteration.taskCompleted = state.value("taskCompleted").toBool(false);
        
        file.close();
    }
}

void IterativeExecutor::resetLoop() {
    m_state = Idle;
    m_currentIteration = IterationState();
    m_history.clear();
    m_stats = {0, 0, 0, 0, 0.0f, {}};
}

bool IterativeExecutor::validateLoopConfiguration() {
    return m_config.maxIterations > 0 && 
           m_config.maxTimeoutSeconds > 0 &&
           m_config.completionThreshold >= 0.0f &&
           m_config.completionThreshold <= 1.0f;
}

QStringList IterativeExecutor::validateCurrentState() {
    QStringList issues;
    
    if (m_state != Running) {
        issues << "Loop not running";
    }
    if (m_currentIteration.taskCompleted && shouldContinueLoop()) {
        issues << "Task completed but loop continuing";
    }
    
    return issues;
}

IterativeExecutor::ExecutionStats IterativeExecutor::getStatistics() const {
    return m_stats;
}

QString IterativeExecutor::generateExecutionReport() {
    return QString("Execution Report\n"
                   "Total Iterations: %1\n"
                   "Successful: %2\n"
                   "Failed: %3\n"
                   "Total Time: %4ms\n"
                   "Completion Score: %5\n")
        .arg(m_stats.totalIterations)
        .arg(m_stats.successfulIterations)
        .arg(m_stats.failedIterations)
        .arg(m_stats.totalTimeMs)
        .arg(static_cast<int>(m_stats.completionScore * 100));
}

void IterativeExecutor::onUserCancelRequest() {
    cancelLoop("User requested cancellation");
}

void IterativeExecutor::onUserFeedback(const QString& feedback) {
    m_currentIteration.results.append("User feedback: " + feedback);
}

void IterativeExecutor::requestUserValidation() {
    m_userValidationNeeded = true;
    emit userInterventionRequested();
}

bool IterativeExecutor::getUserValidation() {
    return m_userValidationNeeded;
}

void IterativeExecutor::enableDebugMode(bool enabled) {
    m_debugMode = enabled;
}

QString IterativeExecutor::getDebugInfo() {
    return QString("Debug Info\nState: %1\nIteration: %2\nProgress: %3%")
        .arg(static_cast<int>(m_state))
        .arg(m_currentIteration.iteration)
        .arg(static_cast<int>(getOverallProgress()));
}

QStringList IterativeExecutor::getExecutionLog() {
    QStringList log;
    for (const auto& state : m_history) {
        log << QString("Iteration %1: %2").arg(state.iteration).arg(state.currentAction);
    }
    return log;
}

void IterativeExecutor::setMaxConcurrentActions(int count) {
    // Implementation for parallel execution
}

void IterativeExecutor::enableAdaptiveLooping(bool enabled) {
    // Enable adaptive iteration count based on progress
}

void IterativeExecutor::configureBackoffStrategy(int initialDelayMs, float backoffMultiplier) {
    m_config.delayBetweenIterationMs = initialDelayMs;
}

void IterativeExecutor::executeIteration() {
    if (m_state != Running) {
        return;
    }
    
    emit iterationStarted(m_currentIteration.iteration);
    
    suggestNextAction();
    recordIteration(m_currentIteration.currentAction, "Executing action");
    checkTaskCompletion();
    updateProgress();
    
    if (shouldContinueLoop()) {
        markIterationAsComplete();
    } else {
        m_state = Completed;
        emit taskCompleted(getCompletionReason());
    }
}

void IterativeExecutor::checkTaskCompletion() {
    if (getCompletionScore() >= m_config.completionThreshold) {
        m_currentIteration.taskCompleted = true;
        m_stats.successfulIterations++;
    }
}

float IterativeExecutor::calculateCompletionScore() {
    return static_cast<float>(m_currentIteration.results.size()) / 10.0f;
}

QString IterativeExecutor::selectNextAction() {
    if (m_currentIteration.previousActions.isEmpty()) {
        return "Analyze and plan";
    }
    return "Refine and improve";
}

void IterativeExecutor::updateProgress() {
    float progress = static_cast<float>(m_currentIteration.iteration) / m_config.maxIterations * 100.0f;
    m_currentIteration.progressPercentage = progress;
    emit progressUpdated(progress);
}
