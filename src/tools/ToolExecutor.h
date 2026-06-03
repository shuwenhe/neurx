#pragma once

#include "ToolSchemaTypes.h"
#include <QObject>
#include <memory>

/**
 * @class ToolExecutor
 * @brief Claude Code工具执行引擎
 * 
 * 功能：
 * - 工具执行
 * - 执行管理
 * - 执行缓存
 * - 工具链执行
 * - 执行监控
 */
class ToolExecutor : public QObject {
    Q_OBJECT
public:
    explicit ToolExecutor(QObject *parent = nullptr) : QObject(parent) {}
    virtual ~ToolExecutor() = default;
    
    // ── 工具执行 ───────────────────────────────────────
    
    /// 执行工具
    virtual QString executeTool(const ToolExecutionRequest &request,
                               ToolExecutionCallback callback = nullptr) = 0;
    
    /// 异步执行工具
    virtual void executeToolAsync(const ToolExecutionRequest &request,
                                 ToolExecutionCallback callback = nullptr) = 0;
    
    /// 执行工具能力
    virtual QString executeCapability(const QString &toolId,
                                     const QString &capabilityName,
                                     const QVariantMap &parameters,
                                     ToolExecutionCallback callback = nullptr) = 0;
    
    /// 执行工具链
    virtual void executeToolChain(const ToolChainDefinition &chain,
                                 const QVariantMap &globalParams,
                                 ToolChainCallback callback = nullptr) = 0;
    
    /// 执行工具链步骤
    virtual QString executeChainStep(const QString &chainId,
                                    int stepId,
                                    const QVariantMap &parameters,
                                    ToolExecutionCallback callback = nullptr) = 0;
    
    // ── 执行管理 ───────────────────────────────────────
    
    /// 获取执行状态
    virtual ExecutionStatus getExecutionStatus(const QString &executionId) const = 0;
    
    /// 获取执行结果
    virtual ToolExecutionResult getExecutionResult(const QString &executionId) const = 0;
    
    /// 获取执行进度
    virtual int getExecutionProgress(const QString &executionId) const = 0;
    
    /// 获取执行日志
    virtual QString getExecutionLog(const QString &executionId) const = 0;
    
    /// 取消执行
    virtual void cancelExecution(const QString &executionId,
                                std::function<void(bool success)> callback = nullptr) = 0;
    
    /// 暂停执行
    virtual void pauseExecution(const QString &executionId,
                               std::function<void(bool success)> callback = nullptr) = 0;
    
    /// 恢复执行
    virtual void resumeExecution(const QString &executionId,
                                std::function<void(bool success)> callback = nullptr) = 0;
    
    /// 重试执行
    virtual void retryExecution(const QString &executionId,
                               ToolExecutionCallback callback = nullptr) = 0;
    
    // ── 执行历史 ───────────────────────────────────────
    
    /// 获取工具执行历史
    virtual QVector<ToolExecutionResult> getToolExecutionHistory(const QString &toolId,
                                                                int limit = 100) const = 0;
    
    /// 获取用户执行历史
    virtual QVector<ToolExecutionResult> getUserExecutionHistory(const QString &userId,
                                                                int limit = 100) const = 0;
    
    /// 获取执行统计
    virtual QVariantMap getExecutionStatistics(const QString &toolId) const = 0;
    
    /// 获取工具执行时间统计
    virtual QVariantMap getExecutionTimeStats(const QString &toolId) const = 0;
    
    /// 获取失败率统计
    virtual QVariantMap getFailureStats(const QString &toolId) const = 0;
    
    // ── 执行缓存 ───────────────────────────────────────
    
    /// 启用执行缓存
    virtual void enableCache(bool enable) = 0;
    
    /// 设置缓存过期时间
    virtual void setCacheExpiry(int seconds) = 0;
    
    /// 获取缓存结果
    virtual QVariantMap getCachedResult(const QString &toolId,
                                       const QVariantMap &parameters) const = 0;
    
    /// 清除执行缓存
    virtual void clearCache(const QString &toolId = "") = 0;
    
    /// 获取缓存统计
    virtual QVariantMap getCacheStatistics() const = 0;
    
    // ── 工具链管理 ───────────────────────────────────────
    
    /// 创建工具链
    virtual QString createToolChain(const ToolChainDefinition &chain,
                                   std::function<void(bool success)> callback = nullptr) = 0;
    
    /// 获取工具链
    virtual ToolChainDefinition getToolChain(const QString &chainId) const = 0;
    
    /// 列出工具链
    virtual QVector<ToolChainDefinition> listToolChains() const = 0;
    
    /// 更新工具链
    virtual void updateToolChain(const ToolChainDefinition &chain,
                                std::function<void(bool success)> callback = nullptr) = 0;
    
    /// 删除工具链
    virtual void deleteToolChain(const QString &chainId,
                                std::function<void(bool success)> callback = nullptr) = 0;
    
    /// 验证工具链
    virtual bool validateToolChain(const ToolChainDefinition &chain,
                                  QString &errorMessage) = 0;
    
    /// 获取链执行历史
    virtual QVector<QVector<ToolExecutionResult>> getChainExecutionHistory(const QString &chainId,
                                                                          int limit = 50) const = 0;
    
    // ── 并发执行 ───────────────────────────────────────
    
    /// 并行执行多个工具
    virtual void executeToolsInParallel(const QVector<ToolExecutionRequest> &requests,
                                       ToolChainCallback callback = nullptr) = 0;
    
    /// 按优先级队列执行
    virtual QString queueExecution(const ToolExecutionRequest &request,
                                  ToolExecutionCallback callback = nullptr) = 0;
    
    /// 获取执行队列状态
    virtual QVector<ToolExecutionRequest> getExecutionQueue() const = 0;
    
    /// 获取活跃执行列表
    virtual QVector<QString> getActiveExecutions() const = 0;
    
    /// 获取最大并发数
    virtual int getMaxConcurrency() const = 0;
    
    /// 设置最大并发数
    virtual void setMaxConcurrency(int maxConcurrent) = 0;
    
    // ── 错误处理和重试 ──────────────────────────────────
    
    /// 设置重试策略
    virtual void setRetryPolicy(int maxRetries,
                               int delayMs,
                               float backoffMultiplier = 1.0f) = 0;
    
    /// 设置超时时间
    virtual void setExecutionTimeout(int timeoutMs) = 0;
    
    /// 获取失败的执行
    virtual QVector<ToolExecutionResult> getFailedExecutions(int limit = 100) const = 0;
    
    /// 分析失败原因
    virtual QString analyzeFailure(const QString &executionId) const = 0;
    
    // ── 性能监控 ───────────────────────────────────────
    
    /// 获取执行性能数据
    virtual QVariantMap getPerformanceMetrics(const QString &toolId) const = 0;
    
    /// 获取资源使用情况
    virtual QVariantMap getResourceUsage(const QString &executionId) const = 0;
    
    /// 获取成本估算
    virtual float getExecutionCost(const ToolExecutionRequest &request) const = 0;
    
    /// 获取总成本
    virtual float getTotalExecutionCost() const = 0;
    
    // ── 执行日志 ───────────────────────────────────────
    
    /// 启用详细日志
    virtual void enableDetailedLogging(bool enable) = 0;
    
    /// 导出执行报告
    virtual QString exportExecutionReport(const QString &executionId) const = 0;
    
    /// 导出性能报告
    virtual QString exportPerformanceReport(const QString &toolId) const = 0;

// ── 信号 ──────────────────────────────────────────────
signals:
    /// 执行已启动
    void executionStarted(const QString &executionId);
    
    /// 执行进度更新
    void executionProgress(const QString &executionId, int progress);
    
    /// 执行已完成
    void executionCompleted(const QString &executionId);
    
    /// 执行失败
    void executionFailed(const QString &executionId, const QString &error);
    
    /// 执行已取消
    void executionCancelled(const QString &executionId);
    
    /// 链执行完成
    void chainExecutionCompleted(const QString &chainId);
    
    /// 队列有变化
    void queueChanged();
};
