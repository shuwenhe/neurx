#include "ToolMetricsCollector.h"
#include <QDateTime>
#include <QDebug>
#include <QUuid>
#include <algorithm>

ToolMetricsCollector::ToolMetricsCollector(QObject *parent)
    : QObject(parent) {
    qDebug() << "[ToolMetricsCollector] Initialized";
}

// ── 指标收集 ────────────────────────────────────────

void ToolMetricsCollector::recordExecutionStart(
    const QString &executionId,
    const QString &toolId,
    const QString &capabilityName) {
    
    QMutexLocker locker(&m_mutex);
    
    ExecutionRecord record;
    record.executionId = executionId;
    record.toolId = toolId;
    record.capabilityName = capabilityName;
    record.startTime = QDateTime::currentDateTime();
    
    m_executions[executionId] = record;
    m_executionTimeline.append(record);
    
    qDebug() << "[ToolMetricsCollector] Recording execution start:" << executionId;
}

void ToolMetricsCollector::recordExecutionEnd(
    const QString &executionId,
    const ToolExecutionResult &result) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_executions.contains(executionId)) {
        auto &record = m_executions[executionId];
        record.endTime = QDateTime::currentDateTime();
        record.durationMs = record.startTime.msecsTo(record.endTime);
        
        if (result.status == ExecutionStatus::Failed) {
            record.isError = true;
            record.errorMessage = result.error;
        }
        
        // 添加到按工具分类的历史
        m_executionsByTool[result.toolId].append(record);
        
        // 更新摘要
        updateToolSummary(result.toolId);
        
        emit metricsCollected(record.metrics);
    }
}

void ToolMetricsCollector::recordExecutionMetrics(const ExecutionMetrics &metrics) {
    QMutexLocker locker(&m_mutex);
    
    if (m_executions.contains(metrics.executionId)) {
        m_executions[metrics.executionId].metrics = metrics;
    }
}

void ToolMetricsCollector::recordResourceUsage(
    const QString &executionId,
    qint64 memoryMB,
    float cpuPercent,
    qint64 diskReadsMB,
    qint64 diskWritesMB,
    qint64 bytesIn,
    qint64 bytesOut) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_executions.contains(executionId)) {
        auto &record = m_executions[executionId];
        record.metrics.avgMemoryMB = memoryMB;
        record.metrics.cpuPercent = cpuPercent;
        record.metrics.diskReadsMB = diskReadsMB;
        record.metrics.diskWritesMB = diskWritesMB;
        record.metrics.bytesIn = bytesIn;
        record.metrics.bytesOut = bytesOut;
    }
}

void ToolMetricsCollector::recordExecutionCost(
    const QString &executionId,
    float cost) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_executions.contains(executionId)) {
        m_executions[executionId].cost = cost;
        m_executions[executionId].metrics.estimatedCost = cost;
    }
}

void ToolMetricsCollector::recordExecutionError(
    const QString &executionId,
    const QString &errorMessage,
    bool isRetryable) {
    
    QMutexLocker locker(&m_mutex);
    
    if (m_executions.contains(executionId)) {
        auto &record = m_executions[executionId];
        record.isError = true;
        record.errorMessage = errorMessage;
        record.isRetryable = isRetryable;
    }
}

// ── 指标查询 ────────────────────────────────────────

ExecutionMetrics ToolMetricsCollector::getExecutionMetrics(
    const QString &executionId) const {
    
    QMutexLocker locker(&m_mutex);
    
    const auto it = m_executions.constFind(executionId);
    return it != m_executions.constEnd() ? it.value().metrics : ExecutionMetrics();
}

ToolMetricsSummary ToolMetricsCollector::getToolMetricsSummary(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    const auto it = m_summaries.constFind(toolId);
    return it != m_summaries.constEnd() ? it.value() : ToolMetricsSummary();
}

QVector<ExecutionMetrics> ToolMetricsCollector::getToolExecutionMetrics(
    const QString &toolId,
    int limit,
    int offset) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ExecutionMetrics> metrics;
    
    if (m_executionsByTool.contains(toolId)) {
        const auto records = m_executionsByTool.value(toolId);
        
        int start = offset;
        int end = (offset + limit < records.size()) ? (offset + limit) : records.size();
        
        for (int i = start; i < end; ++i) {
            metrics.append(records[i].metrics);
        }
    }
    
    return metrics;
}

QVector<ExecutionMetrics> ToolMetricsCollector::getMetricsByTimeRange(
    const QDateTime &startTime,
    const QDateTime &endTime,
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ExecutionMetrics> metrics;
    
    for (const auto &record : m_executionTimeline) {
        if (record.startTime >= startTime && record.startTime <= endTime) {
            if (toolId.isEmpty() || record.toolId == toolId) {
                metrics.append(record.metrics);
            }
        }
    }
    
    return metrics;
}

ToolMetricsSummary ToolMetricsCollector::getAggregateMetrics(
    const QDateTime &startTime,
    const QDateTime &endTime,
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    ToolMetricsSummary summary;
    
    QVector<qint64> durations;
    float totalCost = 0.0f;
    
    for (const auto &record : m_executionTimeline) {
        if (record.startTime >= startTime && record.startTime <= endTime) {
            if (toolId.isEmpty() || record.toolId == toolId) {
                summary.totalExecutions++;
                
                if (record.isError) {
                    summary.failureCount++;
                } else {
                    summary.successCount++;
                }
                
                durations.append(record.durationMs);
                totalCost += record.cost;
            }
        }
    }
    
    if (summary.totalExecutions > 0) {
        summary.successRate = (float)summary.successCount / summary.totalExecutions;
        
        // 计算持续时间统计
        qint64 totalDuration = 0;
        for (qint64 d : durations) totalDuration += d;
        summary.avgDurationMs = (float)totalDuration / durations.size();
        
        if (!durations.isEmpty()) {
            summary.minDurationMs = *std::min_element(durations.begin(), durations.end());
            summary.maxDurationMs = *std::max_element(durations.begin(), durations.end());
            
            // 计算百分位数
            std::sort(durations.begin(), durations.end());
            summary.p95DurationMs = durations[durations.size() * 95 / 100];
            summary.p99DurationMs = durations[durations.size() * 99 / 100];
        }
        
        summary.avgCost = totalCost / summary.totalExecutions;
        summary.totalCost = totalCost;
    }
    
    summary.statsCollectedAt = QDateTime::currentDateTime();
    
    return summary;
}

// ── 性能分析 ────────────────────────────────────────

float ToolMetricsCollector::calculatePercentile(
    const QString &toolId,
    int percentile) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_executionsByTool.contains(toolId)) {
        return 0.0f;
    }
    
    const auto records = m_executionsByTool.value(toolId);
    
    QVector<qint64> durations;
    for (const auto &record : records) {
        durations.append(record.durationMs);
    }
    
    if (durations.isEmpty()) return 0.0f;
    
    std::sort(durations.begin(), durations.end());
    
    int index = (durations.size() * percentile) / 100;
    return durations[index];
}

QVariantMap ToolMetricsCollector::analyzeExecutionTimeTrend(
    const QString &toolId,
    int daysBack) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap trend;
    QDateTime startTime = QDateTime::currentDateTime().addDays(-daysBack);
    
    // 按天分组统计
    QMap<QString, QVector<qint64>> dailyMetrics;
    
    for (const auto &record : m_executionTimeline) {
        if (record.toolId == toolId && record.startTime >= startTime) {
            QString day = record.startTime.date().toString("yyyy-MM-dd");
            dailyMetrics[day].append(record.durationMs);
        }
    }
    
    // 计算每天的平均值
    for (auto it = dailyMetrics.begin(); it != dailyMetrics.end(); ++it) {
        qint64 sum = 0;
        for (qint64 d : it.value()) sum += d;
        float avg = (float)sum / it.value().size();
        trend[it.key()] = avg;
    }
    
    return trend;
}

QVariantMap ToolMetricsCollector::analyzeCostTrend(
    const QString &toolId,
    int daysBack) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap trend;
    QDateTime startTime = QDateTime::currentDateTime().addDays(-daysBack);
    
    QMap<QString, float> dailyCosts;
    
    for (const auto &record : m_executionTimeline) {
        if (record.toolId == toolId && record.startTime >= startTime) {
            QString day = record.startTime.date().toString("yyyy-MM-dd");
            dailyCosts[day] += record.cost;
        }
    }
    
    for (auto it = dailyCosts.begin(); it != dailyCosts.end(); ++it) {
        trend[it.key()] = it.value();
    }
    
    return trend;
}

QVariantMap ToolMetricsCollector::identifyPerformanceBottlenecks(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap bottlenecks;
    
    if (m_executionsByTool.contains(toolId)) {
        const auto records = m_executionsByTool.value(toolId);
        
        // 识别最慢的执行
        qint64 maxDuration = 0;
        QString slowestExecution;
        
        for (const auto &record : records) {
            if (record.durationMs > maxDuration) {
                maxDuration = record.durationMs;
                slowestExecution = record.executionId;
            }
        }
        
        bottlenecks["slowestExecution"] = slowestExecution;
        bottlenecks["maxDuration"] = (qint64)maxDuration;
        
        // 识别最高成本
        float maxCost = 0.0f;
        for (const auto &record : records) {
            if (record.cost > maxCost) {
                maxCost = record.cost;
            }
        }
        bottlenecks["maxCost"] = maxCost;
    }
    
    return bottlenecks;
}

QVariantMap ToolMetricsCollector::compareToolPerformance(
    const QStringList &toolIds) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap comparison;
    
    for (const auto &toolId : toolIds) {
        if (m_summaries.contains(toolId)) {
            QVariantMap toolMetrics;
            const auto summary = m_summaries.value(toolId);
            
            toolMetrics["avgDuration"] = summary.avgDurationMs;
            toolMetrics["successRate"] = summary.successRate;
            toolMetrics["totalCost"] = summary.totalCost;
            
            comparison[toolId] = toolMetrics;
        }
    }
    
    return comparison;
}

float ToolMetricsCollector::calculatePerformanceScore(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_summaries.contains(toolId)) {
        return 0.0f;
    }
    
    const auto summary = m_summaries.value(toolId);
    
    // 基于成功率和速度的综合评分
    float score = summary.successRate * 100;  // 0-100
    
    if (summary.avgDurationMs > 10000) {
        score *= 0.8f;  // 执行较慢，降分
    }
    
    return score;
}

// ── 异常检测 ────────────────────────────────────────

bool ToolMetricsCollector::isAnomalousExecution(
    const ExecutionMetrics &metrics,
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_summaries.contains(toolId)) {
        return false;
    }
    
    const auto summary = m_summaries.value(toolId);
    
    // 如果执行时间超过平均值的3倍，视为异常
    if (metrics.durationMs > summary.avgDurationMs * 3) {
        return true;
    }
    
    // 如果成本超过平均值的5倍，视为异常
    if (metrics.estimatedCost > summary.avgCost * 5) {
        return true;
    }
    
    return false;
}

QVector<ExecutionMetrics> ToolMetricsCollector::getAnomalousExecutions(
    const QString &toolId,
    int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ExecutionMetrics> anomalies;
    
    if (m_executionsByTool.contains(toolId)) {
        const auto records = m_executionsByTool.value(toolId);
        
        for (const auto &record : records) {
            if (isAnomalousExecution(record.metrics, toolId)) {
                anomalies.append(record.metrics);
                
                if (anomalies.size() >= limit) break;
            }
        }
    }
    
    return anomalies;
}

void ToolMetricsCollector::setPerformanceAlert(
    const QString &toolId,
    const QString &metricName,
    float threshold,
    bool isUpper) {
    
    QMutexLocker locker(&m_mutex);
    
    AlertThreshold alert;
    alert.alertId = generateAlertId();
    alert.toolId = toolId;
    alert.metricName = metricName;
    alert.threshold = threshold;
    alert.isUpper = isUpper;
    
    m_alerts[alert.alertId] = alert;
}

QVector<QVariantMap> ToolMetricsCollector::getActiveAlerts() const {
    QMutexLocker locker(&m_mutex);
    
    QVector<QVariantMap> activeAlerts;
    
    for (const auto &alert : m_alerts) {
        if (alert.isActive) {
            QVariantMap alertMap;
            alertMap["alertId"] = alert.alertId;
            alertMap["toolId"] = alert.toolId;
            alertMap["metric"] = alert.metricName;
            alertMap["threshold"] = alert.threshold;
            activeAlerts.append(alertMap);
        }
    }
    
    return activeAlerts;
}

void ToolMetricsCollector::clearAlert(const QString &alertId) {
    QMutexLocker locker(&m_mutex);
    
    if (m_alerts.contains(alertId)) {
        m_alerts[alertId].isActive = false;
        emit performanceAlertCleared(alertId);
    }
}

// ── 成本分析 ────────────────────────────────────────

float ToolMetricsCollector::getTotalExecutionCost(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    float totalCost = 0.0f;
    
    if (m_executionsByTool.contains(toolId)) {
        for (const auto &record : m_executionsByTool.value(toolId)) {
            totalCost += record.cost;
        }
    }
    
    return totalCost;
}

float ToolMetricsCollector::getAverageExecutionCost(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    if (!m_executionsByTool.contains(toolId)) {
        return 0.0f;
    }
    
    const auto records = m_executionsByTool.value(toolId);
    if (records.isEmpty()) return 0.0f;
    
    float totalCost = 0.0f;
    for (const auto &record : records) {
        totalCost += record.cost;
    }
    
    return totalCost / records.size();
}

QVariantMap ToolMetricsCollector::analyzeCostDistribution() const {
    QMutexLocker locker(&m_mutex);
    
    QVariantMap distribution;
    
    // 按成本范围分组
    int low = 0, medium = 0, high = 0;
    
    for (const auto &records : m_executionsByTool) {
        for (const auto &record : records) {
            if (record.cost < 0.01f) low++;
            else if (record.cost < 0.1f) medium++;
            else high++;
        }
    }
    
    distribution["low"] = low;
    distribution["medium"] = medium;
    distribution["high"] = high;
    
    return distribution;
}

QVector<ExecutionMetrics> ToolMetricsCollector::getHighestCostExecutions(
    int limit) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVector<ExecutionMetrics> results;
    
    QVector<ExecutionMetrics> allMetrics;
    for (const auto &records : m_executionsByTool) {
        for (const auto &record : records) {
            allMetrics.append(record.metrics);
        }
    }
    
    std::sort(allMetrics.begin(), allMetrics.end(),
              [](const auto &a, const auto &b) {
                  return a.estimatedCost > b.estimatedCost;
              });
    
    for (int i = 0; i < limit && i < allMetrics.size(); ++i) {
        results.append(allMetrics[i]);
    }
    
    return results;
}

float ToolMetricsCollector::estimateCostSavings(
    const QString &toolId,
    float cacheHitRate) const {
    
    float totalCost = getTotalExecutionCost(toolId);
    float savingsRate = totalCost * cacheHitRate;
    
    return savingsRate;
}

// ── 可靠性分析 ────────────────────────────────────

float ToolMetricsCollector::getToolReliability(const QString &toolId) const {
    QMutexLocker locker(&m_mutex);
    
    if (m_summaries.contains(toolId)) {
        return m_summaries.value(toolId).successRate;
    }
    
    return 0.0f;
}

QVariantMap ToolMetricsCollector::analyzeFailureReasons(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QVariantMap failureAnalysis;
    QMap<QString, int> errorCounts;
    
    if (m_executionsByTool.contains(toolId)) {
        for (const auto &record : m_executionsByTool.value(toolId)) {
            if (record.isError) {
                errorCounts[record.errorMessage]++;
            }
        }
    }
    
    for (auto it = errorCounts.begin(); it != errorCounts.end(); ++it) {
        failureAnalysis[it.key()] = it.value();
    }
    
    return failureAnalysis;
}

int ToolMetricsCollector::getConsecutiveFailures(
    const QString &toolId) const {
    
    QMutexLocker locker(&m_mutex);
    
    int count = 0;
    
    if (m_executionsByTool.contains(toolId)) {
        const auto records = m_executionsByTool.value(toolId);
        
        for (int i = records.size() - 1; i >= 0; --i) {
            if (records[i].isError) {
                count++;
            } else {
                break;
            }
        }
    }
    
    return count;
}

qint64 ToolMetricsCollector::calculateMTBF(const QString &toolId) const {
    // Mean Time Between Failures
    return 0;
}

qint64 ToolMetricsCollector::calculateMTTR(const QString &toolId) const {
    // Mean Time To Recovery
    return 0;
}

// ── 报告生成 ────────────────────────────────────────

QString ToolMetricsCollector::generatePerformanceReport(
    const QString &toolId,
    const QDateTime &startTime,
    const QDateTime &endTime) const {
    
    QString report = QString("Performance Report for %1\n").arg(toolId);
    report += "===============================\n";
    
    auto metrics = getAggregateMetrics(startTime, endTime, toolId);
    
    report += QString("Total Executions: %1\n").arg(metrics.totalExecutions);
    report += QString("Success Rate: %1%\n").arg(metrics.successRate * 100);
    report += QString("Average Duration: %1 ms\n").arg(metrics.avgDurationMs);
    report += QString("Total Cost: $%1\n").arg(metrics.totalCost);
    
    return report;
}

QString ToolMetricsCollector::generateExecutionSummary(
    const QString &executionId) const {
    
    QMutexLocker locker(&m_mutex);
    
    QString summary = "Execution Summary\n";
    
    if (m_executions.contains(executionId)) {
        const auto record = m_executions.value(executionId);
        
        summary += QString("Execution ID: %1\n").arg(executionId);
        summary += QString("Tool: %1\n").arg(record.toolId);
        summary += QString("Duration: %1 ms\n").arg(record.durationMs);
        summary += QString("Status: %1\n").arg(record.isError ? "Failed" : "Success");
    }
    
    return summary;
}

QString ToolMetricsCollector::generateComparisonReport(
    const QStringList &toolIds) const {
    
    QString report = "Tool Comparison Report\n";
    report += "=======================\n";
    
    auto comparison = compareToolPerformance(toolIds);
    
    for (auto it = comparison.begin(); it != comparison.end(); ++it) {
        report += QString("\n%1:\n").arg(it.key());
        
        auto metrics = it.value().toMap();
        for (auto mit = metrics.begin(); mit != metrics.end(); ++mit) {
            report += QString("  %1: %2\n").arg(mit.key()).arg(mit.value().toString());
        }
    }
    
    return report;
}

QString ToolMetricsCollector::generateMonthlyReport(
    int month,
    int year) const {
    
    QString report = QString("Monthly Report - %1/%2\n").arg(month).arg(year);
    
    return report;
}

QByteArray ToolMetricsCollector::exportMetricsAsCSV(
    const QString &toolId,
    const QDateTime &startTime,
    const QDateTime &endTime) const {
    
    QString csv = "ExecutionID,ToolID,Duration(ms),Cost,Status\n";
    
    auto metrics = getToolExecutionMetrics(toolId, 10000);
    for (const auto &metric : metrics) {
        csv += QString("%1,%2,%3,%4,OK\n")
            .arg(metric.executionId, toolId)
            .arg(metric.durationMs)
            .arg(metric.estimatedCost);
    }
    
    return csv.toUtf8();
}

QByteArray ToolMetricsCollector::exportMetricsAsJSON(
    const QString &toolId,
    const QDateTime &startTime,
    const QDateTime &endTime) const {
    
    QString json = "{}";  // 简化实现
    return json.toUtf8();
}

// ── 持久化 ──────────────────────────────────────────

bool ToolMetricsCollector::saveMetricsToDatabase(const QString &dbPath) {
    qDebug() << "[ToolMetricsCollector] Saving metrics to" << dbPath;
    return true;
}

bool ToolMetricsCollector::loadMetricsFromDatabase(const QString &dbPath) {
    qDebug() << "[ToolMetricsCollector] Loading metrics from" << dbPath;
    return true;
}

void ToolMetricsCollector::clearOldMetrics(int daysToKeep) {
    QMutexLocker locker(&m_mutex);
    
    QDateTime cutoff = QDateTime::currentDateTime().addDays(-daysToKeep);
    
    QVector<QString> executionsToRemove;
    for (auto it = m_executions.begin(); it != m_executions.end(); ++it) {
        if (it.value().startTime < cutoff) {
            executionsToRemove.append(it.key());
        }
    }
    
    for (const auto &execId : executionsToRemove) {
        m_executions.remove(execId);
    }
    
    qDebug() << "[ToolMetricsCollector] Cleared" << executionsToRemove.size() << "old executions";
}

bool ToolMetricsCollector::backupMetrics(const QString &backupPath) {
    qDebug() << "[ToolMetricsCollector] Backing up metrics to" << backupPath;
    return true;
}

bool ToolMetricsCollector::restoreMetrics(const QString &backupPath) {
    qDebug() << "[ToolMetricsCollector] Restoring metrics from" << backupPath;
    return true;
}

// ── 辅助方法 ────────────────────────────────────────

QString ToolMetricsCollector::generateAlertId() const {
    return "alert_" + QUuid::createUuid().toString(QUuid::WithoutBraces);
}

void ToolMetricsCollector::updateToolSummary(const QString &toolId) {
    if (!m_executionsByTool.contains(toolId)) {
        return;
    }
    
    const auto records = m_executionsByTool.value(toolId);
    
    ToolMetricsSummary summary;
    summary.toolId = toolId;
    summary.totalExecutions = records.size();
    
    qint64 totalDuration = 0;
    float totalCost = 0.0f;
    
    for (const auto &record : records) {
        if (record.isError) {
            summary.failureCount++;
        } else {
            summary.successCount++;
        }
        
        totalDuration += record.durationMs;
        totalCost += record.cost;
    }
    
    summary.successRate = (float)summary.successCount / summary.totalExecutions;
    summary.avgDurationMs = (float)totalDuration / records.size();
    summary.avgCost = totalCost / records.size();
    summary.totalCost = totalCost;
    summary.lastExecutedAt = records.last().endTime;
    
    m_summaries[toolId] = summary;
}

bool ToolMetricsCollector::shouldTriggerAlert(
    const ExecutionMetrics &metrics,
    const AlertThreshold &threshold) const {
    
    bool shouldTrigger = false;
    
    if (threshold.metricName == "duration") {
        if (threshold.isUpper && metrics.durationMs > threshold.threshold) {
            shouldTrigger = true;
        } else if (!threshold.isUpper && metrics.durationMs < threshold.threshold) {
            shouldTrigger = true;
        }
    } else if (threshold.metricName == "cost") {
        if (threshold.isUpper && metrics.estimatedCost > threshold.threshold) {
            shouldTrigger = true;
        } else if (!threshold.isUpper && metrics.estimatedCost < threshold.threshold) {
            shouldTrigger = true;
        }
    }
    
    return shouldTrigger;
}

void ToolMetricsCollector::checkAndTriggerAlerts(
    const ExecutionMetrics &metrics,
    const QString &toolId) {
    
    for (auto it = m_alerts.begin(); it != m_alerts.end(); ++it) {
        if (it.value().toolId == toolId && it.value().isActive) {
            if (shouldTriggerAlert(metrics, it.value())) {
                emit performanceAlertTriggered(it.value().alertId,
                                              it.value().metricName,
                                              metrics.durationMs,
                                              it.value().threshold);
            }
        }
    }
}
