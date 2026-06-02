#pragma once

#include "LoggingManager.h"
#include <QMap>
#include <QMutex>

/**
 * @class DefaultLoggingManager
 * @brief Default logging and analytics implementation
 * 
 * Features:
 * - Comprehensive event logging
 * - Performance monitoring
 * - User analytics
 * - Alert management
 * - Report generation
 */
class DefaultLoggingManager : public LoggingManager {
    Q_OBJECT
public:
    explicit DefaultLoggingManager(QObject *parent = nullptr);
    ~DefaultLoggingManager() = default;
    
    // Logging
    void log(LogLevel level, const QString &message,
            const QString &category = "general") override;
    void logWithData(LogLevel level, const QString &message,
                    const QString &category,
                    const QVariantMap &data) override;
    void logError(const QString &message,
                 const QString &context = "") override;
    void logWarning(const QString &message,
                   const QString &context = "") override;
    void logInfo(const QString &message,
                const QString &context = "") override;
    void logDebug(const QString &message,
                 const QString &context = "") override;
    QVector<LogEntry> getLogEntries(int limit = 100) const override;
    QVector<LogEntry> getLogsByLevel(LogLevel level, int limit = 100) const override;
    QVector<LogEntry> getLogsByCategory(const QString &category, int limit = 100) const override;
    QVector<LogEntry> getLogsByTimeRange(const QDateTime &from,
                                        const QDateTime &to) const override;
    void clearLogs(std::function<void(bool success)> callback = nullptr) override;
    
    // Events
    QString recordEvent(const Event &event,
                       EventCallback callback = nullptr) override;
    QString recordEventWithProperties(EventType type, const QString &name,
                                     const QVariantMap &properties,
                                     EventCallback callback = nullptr) override;
    QVector<Event> getEvents(int limit = 100) const override;
    QVector<Event> getEventsByType(EventType type, int limit = 100) const override;
    QVector<Event> getEventsByTimeRange(const QDateTime &from,
                                       const QDateTime &to) const override;
    QVector<Event> getEventsByUser(const QString &userId, int limit = 100) const override;
    QVector<Event> getEventsBySession(const QString &sessionId, int limit = 100) const override;
    void clearEvents(std::function<void(bool success)> callback = nullptr) override;
    
    // Metrics
    void recordMetric(const Metric &metric,
                     std::function<void(bool success)> callback = nullptr) override;
    void recordMetricValue(const QString &name, double value,
                          const QString &unit = "",
                          std::function<void(bool success)> callback = nullptr) override;
    QVector<Metric> getMetrics(int limit = 100) const override;
    QVector<Metric> getMetricsByName(const QString &name, int limit = 100) const override;
    MetricsAggregate getAggregatedMetrics(const QString &metricName,
                                         const QDateTime &from,
                                         const QDateTime &to) const override;
    
    // Performance Monitoring
    QString startPerformanceMeasurement() override;
    qint64 endPerformanceMeasurement(const QString &measurementId) override;
    PerformanceMetrics getPerformanceMetrics() const override;
    void recordExecutionTime(const QString &component, qint64 timeMs,
                            std::function<void(bool success)> callback = nullptr) override;
    
    // Alerts
    QString createAlert(const Alert &alert,
                       AlertCallback callback = nullptr) override;
    void acknowledgeAlert(const QString &alertId, const QString &by = "",
                         std::function<void(bool success)> callback = nullptr) override;
    void resolveAlert(const QString &alertId,
                     std::function<void(bool success)> callback = nullptr) override;
    QVector<Alert> getActiveAlerts() const override;
    QVector<Alert> getAlerts(int limit = 100) const override;
    QVector<Alert> getAlertsBySeverity(AlertSeverity severity, int limit = 100) const override;
    QVector<Alert> getAlertsByComponent(const QString &component, int limit = 100) const override;
    
    // User Analytics
    void recordUserInteraction(const QString &userId,
                              std::function<void(bool success)> callback = nullptr) override;
    UserAnalytics getUserAnalytics(const QString &userId) const override;
    QVector<UserAnalytics> getAllUserAnalytics() const override;
    void updateUserPreference(const QString &userId,
                             const QString &key, const QVariant &value,
                             std::function<void(bool success)> callback = nullptr) override;
    
    // Reports
    QString generateReport(ReportType type,
                          std::function<void(const Report &)> callback = nullptr) override;
    QString generateCustomReport(const QDateTime &from, const QDateTime &to,
                                std::function<void(const Report &)> callback = nullptr) override;
    QVector<Report> getReports(int limit = 10) const override;
    Report getReport(const QString &reportId) const override;
    QByteArray exportReport(const QString &reportId, const QString &format = "pdf") override;
    
    // Dashboard
    DashboardData getDashboardData() const override;
    DashboardData getDashboardDataForPeriod(const QDateTime &from,
                                           const QDateTime &to) const override;
    void updateDashboard(const DashboardData &data,
                        std::function<void(bool success)> callback = nullptr) override;
    
    // Configuration
    void setConfiguration(const LoggingConfiguration &config,
                         std::function<void(bool success)> callback = nullptr) override;
    LoggingConfiguration getConfiguration() const override;
    void setLogLevel(LogLevel level) override;
    LogLevel getLogLevel() const override;
    void enableFeature(const QString &feature, bool enable) override;
    bool isFeatureEnabled(const QString &feature) const override;
    
    // Storage & Export
    void flush(std::function<void(bool success)> callback = nullptr) override;
    QByteArray exportLogs(const QString &format = "json") const override;
    QByteArray exportEvents(const QString &format = "json") const override;
    QByteArray exportMetrics(const QString &format = "csv") const override;
    void archiveOldData(int daysToKeep,
                       std::function<void(int archived)> callback = nullptr) override;
    QVariantMap getStorageStatistics() const override;

private:
    QVector<LogEntry> m_logs;
    QVector<Event> m_events;
    QVector<Metric> m_metrics;
    QVector<Alert> m_alerts;
    QMap<QString, UserAnalytics> m_userAnalytics;
    QMap<QString, Report> m_reports;
    QMap<QString, DashboardData> m_dashboards;
    
    QMap<QString, QDateTime> m_performanceMeasurements;
    QMap<QString, qint64> m_executionTimes;
    
    PerformanceMetrics m_perfMetrics;
    LoggingConfiguration m_config;
    
    QMap<QString, bool> m_enabledFeatures;
    
    mutable QMutex m_mutex;
    
    // Helper methods
    void updatePerformanceMetrics();
    bool matchesLogFilter(const LogEntry &entry, LogLevel level, const QString &category) const;
    Report generateReportInternal(const QDateTime &from, const QDateTime &to) const;
};

using DefaultLoggingManagerPtr = std::shared_ptr<DefaultLoggingManager>;
