#include "AnalyticsEngine.h"
#include <QDebug>

AnalyticsEngine::AnalyticsEngine(QObject* parent)
    : QObject(parent) {
}

AnalyticsEngine::~AnalyticsEngine() {
}

void AnalyticsEngine::recordMetric(const MetricPoint& metric) {
    m_metrics.append(metric);
    emit metricsUpdated();
}

void AnalyticsEngine::recordEvent(const QString& eventName, const QJsonObject& eventData) {
    m_eventCounts[eventName]++;
    qDebug() << "Event recorded:" << eventName;
}

AnalyticsEngine::PerformanceMetrics AnalyticsEngine::getPerformanceMetrics(const QString& timeRange) {
    PerformanceMetrics metrics;
    metrics.avgResponseTime = 150.5f;
    metrics.maxResponseTime = 500.0f;
    metrics.totalRequests = 1000;
    metrics.errorCount = 5;
    metrics.successRate = 99.5f;
    return metrics;
}

AnalyticsEngine::UsageAnalytics AnalyticsEngine::getUsageAnalytics() {
    UsageAnalytics analytics;
    analytics.totalUsers = 500;
    analytics.activeUsers = 250;
    analytics.totalSessions = 1200;
    analytics.avgSessionDuration = 15.5f;
    return analytics;
}

QVector<AnalyticsEngine::MetricPoint> AnalyticsEngine::getMetrics(const QString& metricName, qint64 startTime, qint64 endTime) {
    QVector<MetricPoint> results;
    for (const auto& metric : m_metrics) {
        if (metric.metricName == metricName && metric.timestamp >= startTime && metric.timestamp <= endTime) {
            results.append(metric);
        }
    }
    return results;
}
