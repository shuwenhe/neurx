#pragma once

#include <QString>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class MetricsTrackingEngine
 * @brief Metrics tracking and KPI monitoring
 */

class MetricsTrackingEngine : public QObject {
    Q_OBJECT

public:
    struct Metric {
        QString name;
        float value;
        QString unit;
        qint64 timestamp;
        QString category;
    };

    struct KPI {
        QString name;
        QString target;
        QString current;
        QString status;  // on_track, at_risk, off_track
        float progress;
    };

    explicit MetricsTrackingEngine(QObject* parent = nullptr);
    ~MetricsTrackingEngine();

    void recordMetric(const Metric& metric);
    QVector<Metric> getMetricsForPeriod(const QString& metricName, qint64 startTime, qint64 endTime);
    float getLatestMetricValue(const QString& metricName);

    void defineKPI(const KPI& kpi);
    QVector<KPI> getAllKPIs();
    void updateKPIProgress(const QString& kpiName, float progress);

    struct MetricsReport {
        QVector<Metric> metrics;
        QVector<KPI> kpis;
        QMap<QString, float> trends;
    };
    MetricsReport generateReport(qint64 startTime, qint64 endTime);

signals:
    void metricRecorded(const QString& metricName);
    void kpiStatusChanged(const QString& kpiName, const QString& status);
    void alertTriggered(const QString& kpiName);

private:
    QVector<Metric> m_metrics;
    QMap<QString, KPI> m_kpis;
};
