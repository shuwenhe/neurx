#pragma once

#include <QString>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class AnalyticsEngine
 * @brief Performance metrics and usage analytics
 */

class AnalyticsEngine : public QObject {
    Q_OBJECT

public:
    struct MetricPoint {
        QString metricName;
        float value;
        qint64 timestamp;
        QMap<QString, QString> tags;
    };

    struct PerformanceMetrics {
        float avgResponseTime;
        float maxResponseTime;
        int totalRequests;
        int errorCount;
        float successRate;
    };

    struct UsageAnalytics {
        int totalUsers;
        int activeUsers;
        int totalSessions;
        float avgSessionDuration;
        QMap<QString, int> featureUsage;
    };

    explicit AnalyticsEngine(QObject* parent = nullptr);
    ~AnalyticsEngine();

    void recordMetric(const MetricPoint& metric);
    void recordEvent(const QString& eventName, const QJsonObject& eventData);
    PerformanceMetrics getPerformanceMetrics(const QString& timeRange);
    UsageAnalytics getUsageAnalytics();
    QVector<MetricPoint> getMetrics(const QString& metricName, qint64 startTime, qint64 endTime);

signals:
    void metricsUpdated();
    void alertTriggered(const QString& alertName);

private:
    QVector<MetricPoint> m_metrics;
    QMap<QString, int> m_eventCounts;
};
