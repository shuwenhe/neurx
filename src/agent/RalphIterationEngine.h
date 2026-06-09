#pragma once

#include <QObject>
#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QMap>
#include <memory>

/**
 * @class RalphIterationEngine
 * @brief Ralph迭代引擎 - 实现自迭代AI开发循环
 * 
 * Ralph是一个自引用反馈循环机制，实现连续改进的AI代理循环：
 * - 接收任务提示
 * - AI工作并修改文件
 * - 检查是否完成（completion promise）
 * - 如果未完成，重新注入提示
 * - 循环直到AI标记为完成
 */
class RalphIterationEngine : public QObject {
    Q_OBJECT

public:
    enum LoopStatus {
        Idle,
        Running,
        Paused,
        Completed,
        Failed,
        Cancelled
    };
    Q_ENUM(LoopStatus)

    struct RalphLoop {
        QString loopId;
        QString originalPrompt;
        QString completionPromise;
        int maxIterations = -1;              // -1 = unlimited
        int currentIteration = 0;
        LoopStatus status = Idle;
        QJsonArray iterationHistory;         // 每次迭代的状态
        QString workspaceRoot;
        QDateTime startTime;
        QDateTime lastIterationTime;
        int totalErrors = 0;
        QStringList modifiedFiles;           // 追踪修改的文件
    };

    struct IterationContext {
        int iterationNumber = 0;
        QString prompt;                      // 当前注入的提示
        QJsonObject filestateSnapshot;       // 文件状态快照
        QJsonObject gitHistorySnapshot;      // git历史快照
        bool completionPromiseFound = false; // 是否找到completion promise
        QString completionProof;             // 完成的证明
        QStringList errorLog;
    };

    explicit RalphIterationEngine(QObject *parent = nullptr);
    ~RalphIterationEngine();

    // 循环管理
    RalphLoop startRalphLoop(const QString &prompt,
                             const QString &completionPromise,
                             const QString &workspaceRoot,
                             int maxIterations = -1);
    void stopRalphLoop(const QString &loopId);
    void pauseRalphLoop(const QString &loopId);
    void resumeRalphLoop(const QString &loopId);
    void cancelRalphLoop(const QString &loopId);

    // 循环控制
    bool performIteration(const QString &loopId);
    bool checkCompletionPromise(const QString &loopId, QString &proof);
    QString injectPrompt(const QString &loopId);

    // 循环查询
    RalphLoop getLoopStatus(const QString &loopId);
    LoopStatus getCurrentStatus(const QString &loopId);
    int getCurrentIteration(const QString &loopId);
    QJsonArray getIterationHistory(const QString &loopId);

    // 文件追踪
    QStringList getModifiedFiles(const QString &loopId);
    QJsonObject getFileSnapshot(const QString &workspaceRoot);
    bool hasFilesChanged(const QString &loopId);

    // Git追踪
    QJsonObject getGitSnapshot(const QString &workspaceRoot);
    QString getGitDiff(const QString &loopId, int iteration);

    // 迭代分析
    IterationContext analyzeIteration(const QString &loopId, int iteration);
    QString identifyProgressDirection(const QString &loopId);
    bool detectInfiniteLoop(const QString &loopId);
    bool detectProgress(const QString &loopId);

    // 配置
    void setMaxIterationsGlobal(int max);
    int getMaxIterationsGlobal() const;
    void setIterationTimeout(int milliseconds);
    int getIterationTimeout() const;

    // 统计
    struct RalphStatistics {
        int totalLoops = 0;
        int completedLoops = 0;
        int failedLoops = 0;
        int totalIterations = 0;
        double averageIterationsPerLoop = 0.0;
        int maxIterationsSingleLoop = 0;
    };
    
    RalphStatistics getStatistics() const;

signals:
    void loopStarted(const QString &loopId, const QString &prompt);
    void iterationStarted(const QString &loopId, int iteration);
    void iterationCompleted(const QString &loopId, int iteration);
    void completionPromiseFound(const QString &loopId);
    void loopCompleted(const QString &loopId);
    void loopFailed(const QString &loopId, const QString &reason);
    void loopCancelled(const QString &loopId);
    void maxIterationsReached(const QString &loopId);
    void infiniteLoopDetected(const QString &loopId);
    void progressDetected(const QString &loopId, const QString &progress);
    void filePathModified(const QString &loopId, const QStringList &files);
    void statusChanged(const QString &loopId, LoopStatus status);

private:
    QMap<QString, RalphLoop> m_loops;
    int m_maxIterationsGlobal = 100;
    int m_iterationTimeout = 60000;  // 60 seconds
    RalphStatistics m_statistics;

    // 辅助方法
    QString generateLoopId();
    bool validateLoop(const QString &loopId);
    bool canContinueLoop(const RalphLoop &loop);
    void recordIteration(const QString &loopId, const IterationContext &context);
    void updateLoopStatus(const QString &loopId, LoopStatus status);
    bool checkForInfiniteLoop(const QString &loopId);
    QStringList detectModifiedFiles(const QString &workspaceRoot);
    QString scanCompletionProof(const QString &workspaceRoot, const QString &searchPhrase);
};
