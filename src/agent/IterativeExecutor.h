#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class IterativeExecutor
 * @brief Self-referential AI iteration loop for autonomous task completion
 * 
 * Features:
 * - Autonomous iteration loops (Ralph Wiggum pattern)
 * - Task completion verification
 * - Iterative refinement
 * - Loop state management
 * - Progress tracking
 * - Exit criteria checking
 * - Session management
 */

class IterativeExecutor : public QObject {
    Q_OBJECT

public:
    enum LoopState {
        Idle,
        Running,
        Paused,
        Completed,
        Failed,
        CancelledByUser
    };

    enum ExitCriterion {
        TaskCompleted,
        MaxIterationsReached,
        TimeoutReached,
        UserCancelled,
        ErrorOccurred
    };

    struct IterationState {
        int iteration;
        QString taskDescription;
        QString currentAction;
        float progressPercentage;
        QStringList previousActions;
        QStringList results;
        bool taskCompleted;
        int estimatedIterationsRemaining;
    };

    struct LoopConfiguration {
        int maxIterations;
        int maxTimeoutSeconds;
        float completionThreshold;
        bool autoValidateCompletion;
        bool enableUserInterrupts;
        int delayBetweenIterationMs;
        QStringList exitKeywords;
    };

    struct ExecutionStats {
        int totalIterations;
        int successfulIterations;
        int failedIterations;
        int totalTimeMs;
        float completionScore;
        QStringList appliedStrategies;
    };

    explicit IterativeExecutor(QObject* parent = nullptr);
    ~IterativeExecutor();

    // Loop management
    void startLoop(const QString& taskDescription);
    void pauseLoop();
    void resumeLoop();
    void cancelLoop(const QString& reason);
    void stopLoop();
    LoopState getLoopState() const;

    // Configuration
    void setMaxIterations(int max);
    void setMaxTimeout(int seconds);
    void setCompletionThreshold(float threshold);
    void configureLoop(const LoopConfiguration& config);
    LoopConfiguration getConfiguration() const;

    // Iteration management
    IterationState getCurrentIteration() const;
    QVector<IterationState> getIterationHistory();
    void recordIteration(const QString& action, const QString& result);
    void markIterationAsComplete();

    // Task completion
    bool isTaskComplete();
    float getCompletionScore();
    QString getCompletionReason();
    bool validateCompletion(const QString& output);

    // Progress tracking
    float getOverallProgress();
    int getCurrentIterationNumber() const;
    int getRemainingIterations();
    QString getProgressSummary();

    // Exit criteria
    ExitCriterion checkExitCriteria();
    bool shouldContinueLoop();
    QStringList getExitReasons();

    // Action management
    void suggestNextAction();
    QString getRecommendedAction();
    QStringList getPreviousActions();
    void learnFromPreviousAttempts();

    // Refinement strategies
    enum RefinementStrategy {
        Incremental,
        Recursive,
        Parallel,
        BacktrackAndRetry,
        AlternateApproach
    };
    void applyRefinementStrategy(RefinementStrategy strategy);
    RefinementStrategy selectBestStrategy();

    // State management
    void saveLoopState(const QString& filepath);
    void restoreLoopState(const QString& filepath);
    void resetLoop();

    // Validation
    bool validateLoopConfiguration();
    QStringList validateCurrentState();

    // Statistics
    ExecutionStats getStatistics() const;
    QString generateExecutionReport();

    // User interaction
    void onUserCancelRequest();
    void onUserFeedback(const QString& feedback);
    void requestUserValidation();
    bool getUserValidation();

    // Monitoring
    void enableDebugMode(bool enabled);
    QString getDebugInfo();
    QStringList getExecutionLog();

    // Advanced
    void setMaxConcurrentActions(int count);
    void enableAdaptiveLooping(bool enabled);
    void configureBackoffStrategy(int initialDelayMs, float backoffMultiplier);

signals:
    void loopStarted(const QString& taskDescription);
    void iterationStarted(int iterationNumber);
    void actionExecuted(const QString& action, const QString& result);
    void iterationCompleted(int iterationNumber);
    void progressUpdated(float percentage);
    void taskCompleted(const QString& reason);
    void loopPaused();
    void loopCancelled(const QString& reason);
    void userInterventionRequested();

private:
    LoopState m_state;
    IterationState m_currentIteration;
    LoopConfiguration m_config;
    ExecutionStats m_stats;
    QVector<IterationState> m_history;
    QString m_taskDescription;
    bool m_userValidationNeeded;
    bool m_debugMode;

    void executeIteration();
    void checkTaskCompletion();
    float calculateCompletionScore();
    QString selectNextAction();
    void updateProgress();
};
