#include "DefaultLoggingManager.h"
#include <QUuid>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <algorithm>

DefaultLoggingManager::DefaultLoggingManager(QObject *parent)
    : LoggingManager(parent) {
    
    // Initialize default configuration
    m_config.minimumLevel = LogLevel::Info;
    m_config.enableEventLogging = true;
    m_config.enableMetricsLogging = true;
    m_config.enablePerformanceLogging = true;
    m_config.maxLogSize = 1000000;
    m_config.maxLogFiles = 10;
    m_config.metricsSamplingRate = 100;
    m_config.eventsSamplingRate = 100;
    m_config.flushIntervalMs = 5000;
    
    // Enable core features
    m_enabledFeatures["logging"] = true;
    m_enabledFeatures["events"] = true;
    m_enabledFeatures["metrics"] = true;
    m_enabledFeatures["alerts"] = true;
    m_enabledFeatures["analytics"] = true;
    m_enabledFeatures["reports"] = true;
}

// ── Logging ──────────────────────────────────────────

void DefaultLoggingManager::log(LogLevel level, const QString &message,
                               const QString &category) {
    QMutexLocker locker(&m_mutex);
    
    if (level < m_config.minimumLevel || !m_enabledFeatures["logging"]) {
        return;
    }
    
    LogEntry entry;
    entry.logId = QUuid::createUuid().toString();
    entry.level = level;
    entry.message = message;
    entry.category = category;
    entry.timestamp = QDateTime::currentDateTime();
    
    if (!m_logs.isEmpty()) {
        entry.elapsedMs = m_logs.last().timestamp.msecsTo(entry.timestamp);
    }
    
    m_logs.append(entry);
    
    // Keep log size in check
    if (m_logs.size() > m_config.maxLogSize / 100) {
        m_logs.erase(m_logs.begin(), m_logs.begin() + m_logs.size() / 2);
    }
    
    emit logRecorded(entry);
}

void DefaultLoggingManager::logWithData(LogLevel level, const QString &message,
                                       const QString &category,
                                       const QVariantMap &data) {
    QMutexLocker locker(&m_mutex);
    
    if (level < m_config.minimumLevel || !m_enabledFeatures["logging"]) {
        return;
    }
    
    LogEntry entry;
    entry.logId = QUuid::createUuid().toString();
    entry.level = level;
    entry.message = message;
    entry.category = category;
    entry.data = data;
    entry.timestamp = QDateTime::currentDateTime();
    
    if (!m_logs.isEmpty()) {
        entry.elapsedMs = m_logs.last().timestamp.msecsTo(entry.timestamp);
    }
    
    m_logs.append(entry);
    
    if (m_logs.size() > m_config.maxLogSize / 100) {
        m_logs.erase(m_logs.begin(), m_logs.begin() + m_logs.size() / 2);
    }
    
    emit logRecorded(entry);
}

void DefaultLoggingManager::logError(const QString &message,
                                     const QString &context) {
    logWithData(LogLevel::Error, message, "error",
               {{"context", context}});
}

void DefaultLoggingManager::logWarning(const QString &message,
                                       const QString &context) {
    logWithData(LogLevel::Warning, message, "warning",
               {{"context", context}});
}

void DefaultLoggingManager::logInfo(const QString &message,
                                   const QString &context) {
    logWithData(LogLevel::Info, message, "info",
               {{"context", context}});
}

void DefaultLoggingManager::logDebug(const QString &message,
                                    const QString &context) {
    logWithData(LogLevel::Debug, message, "debug",
               {{"context", context}});
}

QVector<LogEntry> DefaultLoggingManager::getLogEntries(int limit) const {
    QMutexLocker locker(&m_mutex);
    
    int start = std::max(0, (int)m_logs.size() - limit);
    return QVector<LogEntry>(m_logs.begin() + start, m_logs.end());
}

QVector<LogEntry> DefaultLoggingManager::getLogsByLevel(LogLevel level, int limit) const {
    QMutexLocker locker(&m_mutex);
    
    QVector<LogEntry> result;
    for (int i = m_logs.size() - 1; i >= 0 && result.size() < limit; --i) {
        if (m_logs[i].level == level) {
            result.prepend(m_logs[i]);
        }
    }
    return result;
}

QVector<LogEntry> DefaultLoggingManager::getLogsByCategory(const QString &category,
                                                           int limit) const {
    QMutexLocker locker(&m_mutex);
    
    QVector<LogEntry> result;
    for (int i = m_logs.size() - 1; i >= 0 && result.size() < limit; --i) {
        if (m_logs[i].category == category) {
            result.prepend(m_logs[i]);
        }
    }
    return result;
}

QVector<LogEntry> DefaultLoggingManager::getLogsByTimeRange(const QDateTime &from,
                                                            const QDateTime &to) const {
    QMutexLocker locker(&m_mutex);
    
    QVector<LogEntry> result;
    for (const auto &log : m_logs) {
        if (log.timestamp >= from && log.timestamp <= to) {
            result.append(log);
        }
    }
    return result;
}

void DefaultLoggingManager::clearLogs(std::function<void(bool success)> callback) {
    QMutexLocker locker(&m_mutex);
    
    m_logs.clear();
    
    if (callback) {
        callback(true);
    }
}

// ── Events ───────────────────────────────────────────

QString DefaultLoggingManager::recordEvent(const Event &event,
                                          EventCallback callback) {
    QMutexLocker locker(&m_mutex);
    
    if (!m_enabledFeatures["events"]) {
        return "";
    }
    
    Event e = event;
    if (e.eventId.isEmpty()) {
        e.eventId = QUuid::createUuid().toString();
    }
    if (e.timestamp.isNull()) {
        e.timestamp = QDateTime::currentDateTime();
    }
    
    m_events.append(e);
    
    emit eventRecorded(e);
    
    if (callback) {
        callback(e);
    }
    
    return e.eventId;
}

QString DefaultLoggingManager::recordEventWithProperties(EventType type,
                                                        const QString &name,
                                                        const QVariantMap &properties,
                                                        EventCallback callback) {
    Event event;
    event.type = type;
    event.name = name;
    event.properties = properties;
    
    return recordEvent(event, callback);
}

QVector<Event> DefaultLoggingManager::getEvents(int limit) const {
    QMutexLocker locker(&m_mutex);
    
    int start = std::max(0, (int)m_events.size() - limit);
    return QVector<Event>(m_events.begin() + start, m_events.end());
}

QVector<Event> DefaultLoggingManager::getEventsByType(EventType type, int limit) const {
    QMutexLocker locker(&m_mutex);
    
    QVector<Event> result;
    for (int i = m_events.size() - 1; i >= 0 && result.size() < limit; --i) {
        if (m_events[i].type == type) {
            result.prepend(m_events[i]);
        }
    }
    return result;
}

QVector<Event> DefaultLoggingManager::getEventsByTimeRange(const QDateTime &from,
                                                           const QDateTime &to) const {
    QMutexLocker locker(&m_mutex);
    
    QVector<Event> result;
    for (const auto &event : m_events) {
        if (event.timestamp >= from && event.timestamp <= to) {
            result.append(event);
        }
    }
    return result;
}

QVector<Event> DefaultLoggingManager::getEventsByUser(const QString &userId, int limit) const {
    QMutexLocker locker(&m_mutex);
    
    QVector<Event> result;
    for (int i = m_events.size() - 1; i >= 0 && result.size() < limit; --i) {
        if (m_events[i].userId == userId) {
            result.prepend(m_events[i]);
        }
    }
    return result;
}

QVector<Event> DefaultLoggingManager::getEventsBySession(const QString &sessionId, int limit) const {
    QMutexLocker locker(&m_mutex);
    
    QVector<Event> result;
    for (int i = m_events.size() - 1; i >= 0 && result.size() < limit; --i) {
        if (m_events[i].sessionId == sessionId) {
            result.prepend(m_events[i]);
        }
    }
    return result;
}

void DefaultLoggingManager::clearEvents(std::function<void(bool success)> callback) {
    QMutexLocker locker(&m_mutex);
    
    m_events.clear();
    
    if (callback) {
        callback(true);
    }
}

// ── Metrics ──────────────────────────────────────────

void DefaultLoggingManager::recordMetric(const Metric &metric,
                                        std::function<void(bool success)> callback) {
    QMutexLocker locker(&m_mutex);
    
    if (!m_enabledFeatures["metrics"]) {
        if (callback) callback(false);
        return;
    }
    
    Metric m = metric;
    if (m.metricId.isEmpty()) {
        m.metricId = QUuid::createUuid().toString();
    }
    if (m.timestamp.isNull()) {
        m.timestamp = QDateTime::currentDateTime();
    }
    
    m_metrics.append(m);
    
    emit metricRecorded(m);
    
    if (callback) {
        callback(true);
    }
}

void DefaultLoggingManager::recordMetricValue(const QString &name, double value,
                                             const QString &unit,
                                             std::function<void(bool success)> callback) {
    Metric metric;
    metric.name = name;
    metric.value = value;
    metric.unit = unit;
    metric.timestamp = QDateTime::currentDateTime();
    
    recordMetric(metric, callback);
}

QVector<Metric> DefaultLoggingManager::getMetrics(int limit) const {
    QMutexLocker locker(&m_mutex);
    
    int start = std::max(0, (int)m_metrics.size() - limit);
    return QVector<Metric>(m_metrics.begin() + start, m_metrics.end());
}

QVector<Metric> DefaultLoggingManager::getMetricsByName(const QString &name, int limit) const {
    QMutexLocker locker(&m_mutex);
    
    QVector<Metric> result;
    for (int i = m_metrics.size() - 1; i >= 0 && result.size() < limit; --i) {
        if (m_metrics[i].name == name) {
            result.prepend(m_metrics[i]);
        }
    }
    return result;
}

MetricsAggregate DefaultLoggingManager::getAggregatedMetrics(const QString &metricName,
                                                             const QDateTime &from,
                                                             const QDateTime &to) const {
    QMutexLocker locker(&m_mutex);
    
    MetricsAggregate agg;
    agg.metricName = metricName;
    agg.periodStart = from;
    agg.periodEnd = to;
    
    QVector<double> values;
    for (const auto &metric : m_metrics) {
        if (metric.name == metricName && metric.timestamp >= from && metric.timestamp <= to) {
            values.append(metric.value);
            agg.sum += metric.value;
            
            if (values.size() == 1) {
                agg.min = metric.value;
                agg.max = metric.value;
            } else {
                agg.min = std::min(agg.min, metric.value);
                agg.max = std::max(agg.max, metric.value);
            }
        }
    }
    
    agg.count = values.size();
    if (agg.count > 0) {
        agg.average = agg.sum / agg.count;
        
        // Calculate median
        std::sort(values.begin(), values.end());
        if (values.size() % 2 == 0) {
            agg.median = (values[values.size() / 2 - 1] + values[values.size() / 2]) / 2.0;
        } else {
            agg.median = values[values.size() / 2];
        }
        
        // Calculate standard deviation
        double sumSqDiff = 0;
        for (double v : values) {
            sumSqDiff += (v - agg.average) * (v - agg.average);
        }
        agg.stdDev = std::sqrt(sumSqDiff / agg.count);
    }
    
    return agg;
}

// ── Performance Monitoring ───────────────────────────

QString DefaultLoggingManager::startPerformanceMeasurement() {
    QMutexLocker locker(&m_mutex);
    
    QString id = QUuid::createUuid().toString();
    m_performanceMeasurements[id] = QDateTime::currentDateTime();
    
    return id;
}

qint64 DefaultLoggingManager::endPerformanceMeasurement(const QString &measurementId) {
    QMutexLocker locker(&m_mutex);
    
    if (!m_performanceMeasurements.contains(measurementId)) {
        return -1;
    }
    
    QDateTime start = m_performanceMeasurements[measurementId];
    qint64 elapsed = start.msecsTo(QDateTime::currentDateTime());
    
    m_performanceMeasurements.remove(measurementId);
    
    return elapsed;
}

PerformanceMetrics DefaultLoggingManager::getPerformanceMetrics() const {
    QMutexLocker locker(&m_mutex);
    
    return m_perfMetrics;
}

void DefaultLoggingManager::recordExecutionTime(const QString &component, qint64 timeMs,
                                               std::function<void(bool success)> callback) {
    QMutexLocker locker(&m_mutex);
    
    m_executionTimes[component] = timeMs;
    
    m_perfMetrics.totalExecutions++;
    
    if (m_perfMetrics.totalExecutions == 1) {
        m_perfMetrics.minExecutionTime = timeMs;
        m_perfMetrics.maxExecutionTime = timeMs;
    } else {
        m_perfMetrics.minExecutionTime = std::min(m_perfMetrics.minExecutionTime, (float)timeMs);
        m_perfMetrics.maxExecutionTime = std::max(m_perfMetrics.maxExecutionTime, (float)timeMs);
    }
    
    float total = m_perfMetrics.averageExecutionTime * (m_perfMetrics.totalExecutions - 1) + timeMs;
    m_perfMetrics.averageExecutionTime = total / m_perfMetrics.totalExecutions;
    
    if (callback) {
        callback(true);
    }
}

// ── Alerts ───────────────────────────────────────────

QString DefaultLoggingManager::createAlert(const Alert &alert,
                                          AlertCallback callback) {
    QMutexLocker locker(&m_mutex);
    
    if (!m_enabledFeatures["alerts"]) {
        return "";
    }
    
    Alert a = alert;
    if (a.alertId.isEmpty()) {
        a.alertId = QUuid::createUuid().toString();
    }
    if (a.createdAt.isNull()) {
        a.createdAt = QDateTime::currentDateTime();
    }
    
    m_alerts.append(a);
    
    emit alertCreated(a);
    
    if (callback) {
        callback(a);
    }
    
    return a.alertId;
}

void DefaultLoggingManager::acknowledgeAlert(const QString &alertId, const QString &by,
                                            std::function<void(bool success)> callback) {
    QMutexLocker locker(&m_mutex);
    
    for (auto &alert : m_alerts) {
        if (alert.alertId == alertId) {
            alert.acknowledged = true;
            alert.acknowledgedBy = by;
            alert.acknowledgedAt = QDateTime::currentDateTime();
            
            if (callback) {
                callback(true);
            }
            return;
        }
    }
    
    if (callback) {
        callback(false);
    }
}

void DefaultLoggingManager::resolveAlert(const QString &alertId,
                                        std::function<void(bool success)> callback) {
    QMutexLocker locker(&m_mutex);
    
    for (auto &alert : m_alerts) {
        if (alert.alertId == alertId) {
            alert.resolvedAt = QDateTime::currentDateTime();
            
            emit alertResolved(alertId);
            
            if (callback) {
                callback(true);
            }
            return;
        }
    }
    
    if (callback) {
        callback(false);
    }
}

QVector<Alert> DefaultLoggingManager::getActiveAlerts() const {
    QMutexLocker locker(&m_mutex);
    
    QVector<Alert> result;
    for (const auto &alert : m_alerts) {
        if (alert.resolvedAt.isNull()) {
            result.append(alert);
        }
    }
    return result;
}

QVector<Alert> DefaultLoggingManager::getAlerts(int limit) const {
    QMutexLocker locker(&m_mutex);
    
    int start = std::max(0, (int)m_alerts.size() - limit);
    return QVector<Alert>(m_alerts.begin() + start, m_alerts.end());
}

QVector<Alert> DefaultLoggingManager::getAlertsBySeverity(AlertSeverity severity, int limit) const {
    QMutexLocker locker(&m_mutex);
    
    QVector<Alert> result;
    for (int i = m_alerts.size() - 1; i >= 0 && result.size() < limit; --i) {
        if (m_alerts[i].severity == severity) {
            result.prepend(m_alerts[i]);
        }
    }
    return result;
}

QVector<Alert> DefaultLoggingManager::getAlertsByComponent(const QString &component, int limit) const {
    QMutexLocker locker(&m_mutex);
    
    QVector<Alert> result;
    for (int i = m_alerts.size() - 1; i >= 0 && result.size() < limit; --i) {
        if (m_alerts[i].affectedComponent == component) {
            result.prepend(m_alerts[i]);
        }
    }
    return result;
}

// ── User Analytics ──────────────────────────────────

void DefaultLoggingManager::recordUserInteraction(const QString &userId,
                                                 std::function<void(bool success)> callback) {
    QMutexLocker locker(&m_mutex);
    
    if (!m_enabledFeatures["analytics"]) {
        if (callback) callback(false);
        return;
    }
    
    if (!m_userAnalytics.contains(userId)) {
        UserAnalytics ua;
        ua.userId = userId;
        ua.firstInteraction = QDateTime::currentDateTime();
        m_userAnalytics[userId] = ua;
    }
    
    m_userAnalytics[userId].totalInteractions++;
    m_userAnalytics[userId].lastInteraction = QDateTime::currentDateTime();
    
    if (callback) {
        callback(true);
    }
}

UserAnalytics DefaultLoggingManager::getUserAnalytics(const QString &userId) const {
    QMutexLocker locker(&m_mutex);
    
    if (m_userAnalytics.contains(userId)) {
        return m_userAnalytics[userId];
    }
    
    return UserAnalytics();
}

QVector<UserAnalytics> DefaultLoggingManager::getAllUserAnalytics() const {
    QMutexLocker locker(&m_mutex);
    
    return m_userAnalytics.values().toVector();
}

void DefaultLoggingManager::updateUserPreference(const QString &userId,
                                                const QString &key, const QVariant &value,
                                                std::function<void(bool success)> callback) {
    QMutexLocker locker(&m_mutex);
    
    if (m_userAnalytics.contains(userId)) {
        m_userAnalytics[userId].preferences[key] = value;
        
        if (callback) {
            callback(true);
        }
    } else if (callback) {
        callback(false);
    }
}

// ── Reports ─────────────────────────────────────────

QString DefaultLoggingManager::generateReport(ReportType type,
                                             std::function<void(const Report &)> callback) {
    QMutexLocker locker(&m_mutex);
    
    if (!m_enabledFeatures["reports"]) {
        return "";
    }
    
    QDateTime now = QDateTime::currentDateTime();
    QDateTime from;
    
    switch (type) {
        case ReportType::Daily:
            from = now.addDays(-1);
            break;
        case ReportType::Weekly:
            from = now.addDays(-7);
            break;
        case ReportType::Monthly:
            from = now.addMonths(-1);
            break;
        default:
            from = now.addDays(-1);
    }
    
    Report report = generateReportInternal(from, now);
    report.reportId = QUuid::createUuid().toString();
    report.type = type;
    report.generatedAt = now;
    report.coveragePeriodStart = from;
    report.coveragePeriodEnd = now;
    
    m_reports[report.reportId] = report;
    
    emit reportGenerated(report);
    
    if (callback) {
        callback(report);
    }
    
    return report.reportId;
}

QString DefaultLoggingManager::generateCustomReport(const QDateTime &from, const QDateTime &to,
                                                   std::function<void(const Report &)> callback) {
    QMutexLocker locker(&m_mutex);
    
    if (!m_enabledFeatures["reports"]) {
        return "";
    }
    
    Report report = generateReportInternal(from, to);
    report.reportId = QUuid::createUuid().toString();
    report.type = ReportType::Custom;
    report.generatedAt = QDateTime::currentDateTime();
    report.coveragePeriodStart = from;
    report.coveragePeriodEnd = to;
    
    m_reports[report.reportId] = report;
    
    emit reportGenerated(report);
    
    if (callback) {
        callback(report);
    }
    
    return report.reportId;
}

QVector<Report> DefaultLoggingManager::getReports(int limit) const {
    QMutexLocker locker(&m_mutex);
    
    return m_reports.values().toVector();
}

Report DefaultLoggingManager::getReport(const QString &reportId) const {
    QMutexLocker locker(&m_mutex);
    
    if (m_reports.contains(reportId)) {
        return m_reports[reportId];
    }
    
    return Report();
}

QByteArray DefaultLoggingManager::exportReport(const QString &reportId, const QString &format) {
    QMutexLocker locker(&m_mutex);
    
    if (!m_reports.contains(reportId)) {
        return QByteArray();
    }
    
    // Simple JSON export
    if (format == "json") {
        QJsonObject obj;
        obj["reportId"] = reportId;
        obj["generatedAt"] = m_reports[reportId].generatedAt.toString();
        
        QJsonDocument doc(obj);
        return doc.toJson();
    }
    
    return QByteArray();
}

// ── Dashboard ───────────────────────────────────────

DashboardData DefaultLoggingManager::getDashboardData() const {
    QMutexLocker locker(&m_mutex);
    
    DashboardData dashboard;
    dashboard.dashboardId = QUuid::createUuid().toString();
    dashboard.totalEvents = m_events.size();
    dashboard.totalAlerts = m_alerts.size();
    dashboard.activeAlerts = getActiveAlerts();
    
    return dashboard;
}

DashboardData DefaultLoggingManager::getDashboardDataForPeriod(const QDateTime &from,
                                                               const QDateTime &to) const {
    QMutexLocker locker(&m_mutex);
    
    DashboardData dashboard;
    dashboard.dashboardId = QUuid::createUuid().toString();
    
    int events = 0, errors = 0;
    for (const auto &event : m_events) {
        if (event.timestamp >= from && event.timestamp <= to) {
            events++;
            if (!event.errorMessage.isEmpty()) {
                errors++;
            }
        }
    }
    
    dashboard.totalEvents = events;
    dashboard.totalErrors = errors;
    dashboard.successRate = events > 0 ? (100.0f * (events - errors)) / events : 0.0f;
    
    return dashboard;
}

void DefaultLoggingManager::updateDashboard(const DashboardData &data,
                                           std::function<void(bool success)> callback) {
    QMutexLocker locker(&m_mutex);
    
    if (callback) {
        callback(true);
    }
}

// ── Configuration ───────────────────────────────────

void DefaultLoggingManager::setConfiguration(const LoggingConfiguration &config,
                                            std::function<void(bool success)> callback) {
    QMutexLocker locker(&m_mutex);
    
    m_config = config;
    
    if (callback) {
        callback(true);
    }
}

LoggingConfiguration DefaultLoggingManager::getConfiguration() const {
    QMutexLocker locker(&m_mutex);
    
    return m_config;
}

void DefaultLoggingManager::setLogLevel(LogLevel level) {
    QMutexLocker locker(&m_mutex);
    
    m_config.minimumLevel = level;
}

LogLevel DefaultLoggingManager::getLogLevel() const {
    QMutexLocker locker(&m_mutex);
    
    return m_config.minimumLevel;
}

void DefaultLoggingManager::enableFeature(const QString &feature, bool enable) {
    QMutexLocker locker(&m_mutex);
    
    m_enabledFeatures[feature] = enable;
}

bool DefaultLoggingManager::isFeatureEnabled(const QString &feature) const {
    QMutexLocker locker(&m_mutex);
    
    return m_enabledFeatures.value(feature, true);
}

// ── Storage & Export ────────────────────────────────

void DefaultLoggingManager::flush(std::function<void(bool success)> callback) {
    QMutexLocker locker(&m_mutex);
    
    // In real implementation, would write to disk
    
    if (callback) {
        callback(true);
    }
}

QByteArray DefaultLoggingManager::exportLogs(const QString &format) const {
    QMutexLocker locker(&m_mutex);
    
    if (format == "json") {
        QJsonArray arr;
        for (const auto &log : m_logs) {
            QJsonObject obj;
            obj["logId"] = log.logId;
            obj["message"] = log.message;
            obj["category"] = log.category;
            obj["timestamp"] = log.timestamp.toString();
            arr.append(obj);
        }
        
        QJsonDocument doc(arr);
        return doc.toJson();
    }
    
    return QByteArray();
}

QByteArray DefaultLoggingManager::exportEvents(const QString &format) const {
    QMutexLocker locker(&m_mutex);
    
    if (format == "json") {
        QJsonArray arr;
        for (const auto &event : m_events) {
            QJsonObject obj;
            obj["eventId"] = event.eventId;
            obj["name"] = event.name;
            obj["timestamp"] = event.timestamp.toString();
            arr.append(obj);
        }
        
        QJsonDocument doc(arr);
        return doc.toJson();
    }
    
    return QByteArray();
}

QByteArray DefaultLoggingManager::exportMetrics(const QString &format) const {
    QMutexLocker locker(&m_mutex);
    
    if (format == "csv") {
        QByteArray csv;
        csv.append("metricId,name,value,unit,timestamp\n");
        
        for (const auto &metric : m_metrics) {
            csv.append(metric.metricId).append(",");
            csv.append(metric.name).append(",");
            csv.append(QString::number(metric.value)).append(",");
            csv.append(metric.unit).append(",");
            csv.append(metric.timestamp.toString()).append("\n");
        }
        
        return csv;
    }
    
    return QByteArray();
}

void DefaultLoggingManager::archiveOldData(int daysToKeep,
                                         std::function<void(int archived)> callback) {
    QMutexLocker locker(&m_mutex);
    
    QDateTime cutoff = QDateTime::currentDateTime().addDays(-daysToKeep);
    
    int count = 0;
    
    // Archive old logs
    for (int i = 0; i < m_logs.size(); ) {
        if (m_logs[i].timestamp < cutoff) {
            m_logs.removeAt(i);
            count++;
        } else {
            ++i;
        }
    }
    
    // Archive old events
    for (int i = 0; i < m_events.size(); ) {
        if (m_events[i].timestamp < cutoff) {
            m_events.removeAt(i);
            count++;
        } else {
            ++i;
        }
    }
    
    if (callback) {
        callback(count);
    }
}

QVariantMap DefaultLoggingManager::getStorageStatistics() const {
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    stats["logsCount"] = m_logs.size();
    stats["eventsCount"] = m_events.size();
    stats["metricsCount"] = m_metrics.size();
    stats["alertsCount"] = m_alerts.size();
    stats["reportsCount"] = m_reports.size();
    
    return stats;
}

// ── Helper Methods ──────────────────────────────────

Report DefaultLoggingManager::generateReportInternal(const QDateTime &from,
                                                     const QDateTime &to) const {
    Report report;
    report.coveragePeriodStart = from;
    report.coveragePeriodEnd = to;
    report.generatedAt = QDateTime::currentDateTime();
    
    // Collect events and metrics in period
    for (const auto &event : m_events) {
        if (event.timestamp >= from && event.timestamp <= to) {
            report.events.append(event);
            report.totalEvents++;
        }
    }
    
    for (const auto &alert : m_alerts) {
        if (alert.createdAt >= from && alert.createdAt <= to) {
            report.alerts.append(alert);
            report.totalAlerts++;
        }
    }
    
    for (const auto &metric : m_metrics) {
        if (metric.timestamp >= from && metric.timestamp <= to) {
            report.metrics.append(metric);
        }
    }
    
    return report;
}
