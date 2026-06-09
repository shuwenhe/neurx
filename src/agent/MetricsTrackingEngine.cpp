#include "MetricsTrackingEngine.h"
#include <QDebug>

MetricsTrackingEngine::MetricsTrackingEngine(QObject* parent)
    : QObject(parent) {
}

MetricsTrackingEngine::~MetricsTrackingEngine() {
}

void MetricsTrackingEngine::recordMetric(const Metric& metric) {
    m_metrics.append(metric);
    emit metricRecorded(metric.name);
}

QVector<MetricsTrackingEngine::Metric> MetricsTrackingEngine::getMetricsForPeriod(const QString& metricName, qint64 startTime, qint64 endTime) {
    QVector<Metric> results;
    for (const auto& metric : m_metrics) {
        if (metric.name == metricName && metric.timestamp >= startTime && metric.timestamp <= endTime) {
            results.append(metric);
        }
    }
    return results;
}

float MetricsTrackingEngine::getLatestMetricValue(const QString& metricName) {
    for (int i = m_metrics.size() - 1; i >= 0; --i) {
        if (m_metrics[i].name == metricName) {
            return m_metrics[i].value;
        }
    }
    return 0.0f;
}

void MetricsTrackingEngine::defineKPI(const KPI& kpi) {
    m_kpis[kpi.name] = kpi;
}

QVector<MetricsTrackingEngine::KPI> MetricsTrackingEngine::getAllKPIs() {
    return QVector<KPI>(m_kpis.values().begin(), m_kpis.values().end());
}

void MetricsTrackingEngine::updateKPIProgress(const QString& kpiName, float progress) {
    if (m_kpis.contains(kpiName)) {
        m_kpis[kpiName].progress = progress;
        emit kpiStatusChanged(kpiName, m_kpis[kpiName].status);
    }
}

MetricsTrackingEngine::MetricsReport MetricsTrackingEngine::generateReport(qint64 startTime, qint64 endTime) {
    MetricsReport report;
    for (const auto& metric : m_metrics) {
        if (metric.timestamp >= startTime && metric.timestamp <= endTime) {
            report.metrics.append(metric);
        }
    }
    report.kpis = getAllKPIs();
    return report;
}
