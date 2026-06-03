#pragma once

#include "ToolExecutor.h"
#include <QMap>
#include <QQueue>
#include <QMutex>
#include <QDateTime>

/**
 * @class DefaultToolExecutor
 * @brief 工具执行引擎默认实现
 * 
 * 功能：
 * - 工具执行和管理
 * - 工具链执行
 * - 执行队列和并发
 * - 执行缓存
 * - 性能监控
 */
class DefaultToolExecutor : public ToolExecutor {
public:
    explicit DefaultToolExecutor(QObject *parent = nullptr);
    ~DefaultToolExecutor() = default;
    
    // ── 工具执行 ───────────────────────────────────────
    QString executeTool(const ToolExecutionRequest &request,
                       ToolExecutionCallback callback = nullptr) override;
    
    void executeToolAsync(const ToolExecutionRequest &request,
                         ToolExecutionCallback callback = nullptr) override;
    
    QString executeCapability(const QString &toolId,
                             const QString &capabilityName,
                             const QVariantMap &parameters,
                             ToolExecutionCallback callback = nullptr) override;
    
    void executeToolChain(const ToolChainDefinition &chain,
                         const QVariantMap &globalParams,
                         ToolChainCallback callback = nullptr) override;
    
    QString executeChainStep(const QString &chainId,
                            int stepId,
                            const QVariantMap &parameters,
                            ToolExecutionCallback callback = nullptr) override;
    
    // ── 执行管理 ───────────────────────────────────────
    ExecutionStatus getExecutionStatus(const QString &executionId) const override;
    
    ToolExecutionResult getExecutionResult(const QString &executionId) const override;
    
    int getExecutionProgress(const QString &executionId) const override;
    
    QString getExecutionLog(const QString &executionId) const override;
    
    void cancelExecution(const QString &executionId,
                        std::function<void(bool success)> callback = nullptr) override;
    
    void pauseExecution(const QString &executionId,
                       std::function<void(bool success)> callback = nullptr) override;
    
    void resumeExecution(const QString &executionId,
                        std::function<void(bool success)> callback = nullptr) override;
    
    void retryExecution(const QString &executionId,
                       ToolExecutionCallback callback = nullptr) override;
    
    // ── 执行历史 ───────────────────────────────────────
    QVector<ToolExecutionResult> getToolExecutionHistory(const QString &toolId,
                                                        int limit = 100) const override;
    
    QVector<ToolExecutionResult> getUserExecutionHistory(const QString &userId,
                                                        int limit = 100) const override;
    
    QVariantMap getExecutionStatistics(const QString &toolId) const override;
    
    QVariantMap getExecutionTimeStats(const QString &toolId) const override;
    
    QVariantMap getFailureStats(const QString &toolId) const override;
    
    // ── 执行缓存 ───────────────────────────────────────
    void enableCache(bool enable) override;
    
    void setCacheExpiry(int seconds) override;
    
    QVariantMap getCachedResult(const QString &toolId,
                               const QVariantMap &parameters) const override;
    
    void clearCache(const QString &toolId = "") override;
    
    QVariantMap getCacheStatistics() const override;
    
    // ── 工具链管理 ───────────────────────────────────────
    QString createToolChain(const ToolChainDefinition &chain,
                           std::function<void(bool success)> callback = nullptr) override;
    
    ToolChainDefinition getToolChain(const QString &chainId) const override;
    
    QVector<ToolChainDefinition> listToolChains() const override;
    
    void updateToolChain(const ToolChainDefinition &chain,
                        std::function<void(bool success)> callback = nullptr) override;
    
    void deleteToolChain(const QString &chainId,
                        std::function<void(bool success)> callback = nullptr) override;
    
    bool validateToolChain(const ToolChainDefinition &chain,
                          QString &errorMessage) override;
    
    QVector<QVector<ToolExecutionResult>> getChainExecutionHistory(
        const QString &chainId,
        int limit = 50) const override;
    
    // ── 并发执行 ───────────────────────────────────────
    void executeToolsInParallel(const QVector<ToolExecutionRequest> &requests,
                               ToolChainCallback callback = nullptr) override;
    
    QString queueExecution(const ToolExecutionRequest &request,
                          ToolExecutionCallback callback = nullptr) override;
    
    QVector<ToolExecutionRequest> getExecutionQueue() const override;
    
    QVector<QString> getActiveExecutions() const override;
    
    int getMaxConcurrency() const override;
    
    void setMaxConcurrency(int maxConcurrent) override;
    
    // ── 错误处理和重试 ──────────────────────────────────
    void setRetryPolicy(int maxRetries,
                       int delayMs,
                       float backoffMultiplier = 1.0f) override;
    
    void setExecutionTimeout(int timeoutMs) override;
    
    QVector<ToolExecutionResult> getFailedExecutions(int limit = 100) const override;
    
    QString analyzeFailure(const QString &executionId) const override;
    
    // ── 性能监控 ───────────────────────────────────────
    QVariantMap getPerformanceMetrics(const QString &toolId) const override;
    
    QVariantMap getResourceUsage(const QString &executionId) const override;
    
    float getExecutionCost(const ToolExecutionRequest &request) const override;
    
    float getTotalExecutionCost() const override;
    
    // ── 执行日志 ───────────────────────────────────────
    void enableDetailedLogging(bool enable) override;
    
    QString exportExecutionReport(const QString &executionId) const override;
    
    QString exportPerformanceReport(const QString &toolId) const override;

private:
    struct CacheEntry {
        QVariantMap result;
        QDateTime createdAt;
    };
    
    struct PerformanceData {
        int successCount;
        int failureCount;
        int totalExecutions;
        float avgDuration;
        float totalCost;
    };
    
    // 存储
    QMap<QString, ToolExecutionResult> m_executions;
    QMap<QString, ToolChainDefinition> m_chains;
    QQueue<ToolExecutionRequest> m_executionQueue;
    QVector<QString> m_activeExecutions;
    QMap<QString, QString> m_executionLogs;
    
    // 缓存
    QMap<QString, CacheEntry> m_cache;
    bool m_cacheEnabled;
    int m_cacheExpirySeconds;
    
    // 性能
    QMap<QString, PerformanceData> m_performanceData;
    QMap<QString, QVector<ToolExecutionResult>> m_executionHistory;
    float m_totalCost;
    
    // 重试策略
    int m_maxRetries;
    int m_retryDelayMs;
    float m_backoffMultiplier;
    int m_executionTimeoutMs;
    
    // 并发控制
    int m_maxConcurrency;
    
    bool m_detailedLogging;
    
    mutable QMutex m_mutex;
    
    // 辅助方法
    QString generateExecutionId();
    
    QString generateCacheKey(const QString &toolId,
                            const QVariantMap &parameters) const;
    
    ToolExecutionResult executeInternal(const ToolExecutionRequest &request);
    
    void recordExecution(const ToolExecutionResult &result);
    
    void updatePerformanceData(const QString &toolId,
                              const ToolExecutionResult &result);
};
