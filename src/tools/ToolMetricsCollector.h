#pragma once

#include <QObject>
#include <QMap>
#include <QVector>
#include <QMutex>
#include <QDateTime>
#include "ToolSchemaTypes.h"

/**
 * @class ToolMetricsCollector
 * @brief 工具执行性能指标收集器 - 记录、分析和优化工具性能
 * 
 * 功能：
 * - 实时性能监控（CPU、内存、I/O、网络）
 * - 执行指标收集和存储
 * - 性能分析和趋势识别
 * - 异常检测和告警
 * - 性能报告生成
 */
class ToolMetricsCollector : public QObject {
    Q_OBJECT

public:
    explicit ToolMetricsCollector(QObject *parent = nullptr);
    ~ToolMetricsCollector() = default;

    // ── 指标收集 ────────────────────────────────────────

    /// 记录执行开始
    void recordExecutionStart(const QString &executionId,
                             const QString &toolId,
                             const QString &capabilityName);

    /// 记录执行完成
    void recordExecutionEnd(const QString &executionId,
                           const ToolExecutionResult &result);

    /// 记录执行指标
    void recordExecutionMetrics(const ExecutionMetrics &metrics);

    /// 记录资源使用
    void recordResourceUsage(const QString &executionId,
                            qint64 memoryMB,
                            float cpuPercent,
                            qint64 diskReadsMB,
                            qint64 diskWritesMB,
                            qint64 bytesIn,
                            qint64 bytesOut);

    /// 记录执行成本
    void recordExecutionCost(const QString &executionId, float cost);

    /// 记录错误
    void recordExecutionError(const QString &executionId,
                             const QString &errorMessage,
                             bool isRetryable);

    // ── 指标查询 ────────────────────────────────────────

    /// 获取执行指标
    ExecutionMetrics getExecutionMetrics(const QString &executionId) const;

    /// 获取工具统计摘要
    ToolMetricsSummary getToolMetricsSummary(const QString &toolId) const;

    /// 获取工具执行历史
    QVector<ExecutionMetrics> getToolExecutionMetrics(const QString &toolId,
                                                      int limit = 100,
                                                      int offset = 0) const;

    /// 获取时间范围内的指标
    QVector<ExecutionMetrics> getMetricsByTimeRange(
        const QDateTime &startTime,
        const QDateTime &endTime,
        const QString &toolId = "") const;

    /// 获取特定时间段的聚合指标
    ToolMetricsSummary getAggregateMetrics(const QDateTime &startTime,
                                           const QDateTime &endTime,
                                           const QString &toolId = "") const;

    // ── 性能分析 ────────────────────────────────────────

    /// 计算百分位数
    float calculatePercentile(const QString &toolId, int percentile) const;

    /// 分析执行时间趋势
    QVariantMap analyzeExecutionTimeTrend(const QString &toolId,
                                         int daysBack = 7) const;

    /// 分析成本趋势
    QVariantMap analyzeCostTrend(const QString &toolId,
                                 int daysBack = 7) const;

    /// 识别性能瓶颈
    QVariantMap identifyPerformanceBottlenecks(const QString &toolId) const;

    /// 比较工具性能
    QVariantMap compareToolPerformance(const QStringList &toolIds) const;

    /// 计算性能评分
    float calculatePerformanceScore(const QString &toolId) const;

    // ── 异常检测 ────────────────────────────────────────

    /// 检测异常执行
    bool isAnomalousExecution(const ExecutionMetrics &metrics,
                             const QString &toolId) const;

    /// 获取异常执行列表
    QVector<ExecutionMetrics> getAnomalousExecutions(const QString &toolId,
                                                     int limit = 50) const;

    /// 设置性能告警阈值
    void setPerformanceAlert(const QString &toolId,
                            const QString &metricName,
                            float threshold,
                            bool isUpper = true);

    /// 获取活跃告警
    QVector<QVariantMap> getActiveAlerts() const;

    /// 清除告警
    void clearAlert(const QString &alertId);

    // ── 成本分析 ────────────────────────────────────────

    /// 获取工具总成本
    float getTotalExecutionCost(const QString &toolId) const;

    /// 获取平均执行成本
    float getAverageExecutionCost(const QString &toolId) const;

    /// 分析成本分布
    QVariantMap analyzeCostDistribution() const;

    /// 获取成本最高的执行
    QVector<ExecutionMetrics> getHighestCostExecutions(int limit = 10) const;

    /// 估算成本节省（通过缓存）
    float estimateCostSavings(const QString &toolId,
                             float cacheHitRate) const;

    // ── 可靠性分析 ────────────────────────────────────

    /// 获取工具可靠性
    float getToolReliability(const QString &toolId) const;

    /// 分析失败原因
    QVariantMap analyzeFailureReasons(const QString &toolId) const;

    /// 获取连续失败次数
    int getConsecutiveFailures(const QString &toolId) const;

    /// 计算MTBF(平均故障间隔时间)
    qint64 calculateMTBF(const QString &toolId) const;

    /// 计算MTTR(平均恢复时间)
    qint64 calculateMTTR(const QString &toolId) const;

    // ── 报告生成 ────────────────────────────────────────

    /// 生成性能报告
    QString generatePerformanceReport(const QString &toolId,
                                     const QDateTime &startTime,
                                     const QDateTime &endTime) const;

    /// 生成执行摘要
    QString generateExecutionSummary(const QString &executionId) const;

    /// 生成指标对比报告
    QString generateComparisonReport(const QStringList &toolIds) const;

    /// 生成月度报告
    QString generateMonthlyReport(int month, int year) const;

    /// 导出指标数据
    QByteArray exportMetricsAsCSV(const QString &toolId,
                                 const QDateTime &startTime,
                                 const QDateTime &endTime) const;

    /// 导出指标数据为JSON
    QByteArray exportMetricsAsJSON(const QString &toolId,
                                  const QDateTime &startTime,
                                  const QDateTime &endTime) const;

    // ── 持久化 ──────────────────────────────────────────

    /// 保存指标到数据库
    bool saveMetricsToDatabase(const QString &dbPath);

    /// 从数据库加载指标
    bool loadMetricsFromDatabase(const QString &dbPath);

    /// 清空历史指标（保留N天）
    void clearOldMetrics(int daysToKeep = 90);

    /// 备份指标
    bool backupMetrics(const QString &backupPath);

    /// 恢复指标
    bool restoreMetrics(const QString &backupPath);

public slots:
    // Public slots for signal connections if needed

signals:
    /// 收集到新指标
    void metricsCollected(const ExecutionMetrics &metrics);

    /// 检测到异常
    void anomalyDetected(const QString &toolId, const QString &anomalyType);

    /// 触发性能告警
    void performanceAlertTriggered(const QString &alertId,
                                  const QString &metricName,
                                  float value,
                                  float threshold);

    /// 清除性能告警
    void performanceAlertCleared(const QString &alertId);

    /// 生成报告完成
    void reportGenerated(const QString &reportPath);

    /// 指标分析完成
    void metricsAnalysisCompleted(const QString &toolId,
                                 const QVariantMap &analysisResult);

private:
    struct ExecutionRecord {
        QString executionId;
        QString toolId;
        QString capabilityName;
        
        QDateTime startTime;
        QDateTime endTime;
        qint64 durationMs = 0;
        
        ExecutionMetrics metrics;
        
        bool isError = false;
        QString errorMessage;
        bool isRetryable = false;
        
        float cost = 0.0f;
    };

    struct AlertThreshold {
        QString alertId;
        QString toolId;
        QString metricName;
        float threshold = 0.0f;
        bool isUpper = true;  // true: 上限, false: 下限
        bool isActive = true;
        QDateTime triggeredAt;
    };

    QMap<QString, ExecutionRecord> m_executions;
    QMap<QString, QVector<ExecutionRecord>> m_executionsByTool;
    QVector<ExecutionRecord> m_executionTimeline;
    
    QMap<QString, AlertThreshold> m_alerts;
    QMap<QString, ToolMetricsSummary> m_summaries;

    mutable QMutex m_mutex;

    // 辅助方法
    QString generateAlertId() const;
    void updateToolSummary(const QString &toolId);
    bool shouldTriggerAlert(const ExecutionMetrics &metrics,
                           const AlertThreshold &threshold) const;
    void checkAndTriggerAlerts(const ExecutionMetrics &metrics,
                              const QString &toolId);
};
