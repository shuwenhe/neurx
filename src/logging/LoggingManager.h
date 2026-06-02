#pragma once

#include "LoggingTypes.h"
#include <QObject>
#include <memory>

/**
 * @class LoggingManager
 * @brief Comprehensive logging and analytics system
 * 
 * Handles:
 * - Event logging
 * - Performance monitoring
 * - User analytics
 * - Alert management
 * - Report generation
 */
class LoggingManager : public QObject {
    Q_OBJECT
public:
    virtual ~LoggingManager() = default;
    
    // ── Logging ─────────────────────────────────────────
    
    /// Log message
    virtual void log(LogLevel level, const QString &message,
                    const QString &category = "general") = 0;
    
    /// Log with data
    virtual void logWithData(LogLevel level, const QString &message,
                            const QString &category,
                            const QVariantMap &data) = 0;
    
    /// Log error
    virtual void logError(const QString &message,
                         const QString &context = "") = 0;
    
    /// Log warning
    virtual void logWarning(const QString &message,
                           const QString &context = "") = 0;
    
    /// Log info
    virtual void logInfo(const QString &message,
                        const QString &context = "") = 0;
    
    /// Log debug
    virtual void logDebug(const QString &message,
                         const QString &context = "") = 0;
    
    /// Get log entries
    virtual QVector<LogEntry> getLogEntries(int limit = 100) const = 0;
    
    /// Get logs by level
    virtual QVector<LogEntry> getLogsByLevel(LogLevel level, int limit = 100) const = 0;
    
    /// Get logs by category
    virtual QVector<LogEntry> getLogsByCategory(const QString &category, int limit = 100) const = 0;
    
    /// Get logs by time range
    virtual QVector<LogEntry> getLogsByTimeRange(const QDateTime &from,
                                                 const QDateTime &to) const = 0;
    
    /// Clear logs
    virtual void clearLogs(std::function<void(bool success)> callback = nullptr) = 0;
    
    // ── Events ──────────────────────────────────────────
    
    /// Record event
    virtual QString recordEvent(const Event &event,
                               EventCallback callback = nullptr) = 0;
    
    /// Record event with properties
    virtual QString recordEventWithProperties(EventType type, const QString &name,
                                             const QVariantMap &properties,
                                             EventCallback callback = nullptr) = 0;
    
    /// Get events
    virtual QVector<Event> getEvents(int limit = 100) const = 0;
    
    /// Get events by type
    virtual QVector<Event> getEventsByType(EventType type, int limit = 100) const = 0;
    
    /// Get events by time range
    virtual QVector<Event> getEventsByTimeRange(const QDateTime &from,
                                               const QDateTime &to) const = 0;
    
    /// Get events by user
    virtual QVector<Event> getEventsByUser(const QString &userId, int limit = 100) const = 0;
    
    /// Get events by session
    virtual QVector<Event> getEventsBySession(const QString &sessionId, int limit = 100) const = 0;
    
    /// Clear events
    virtual void clearEvents(std::function<void(bool success)> callback = nullptr) = 0;
    
    // ── Metrics ─────────────────────────────────────────
    
    /// Record metric
    virtual void recordMetric(const Metric &metric,
                             std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Record metric value
    virtual void recordMetricValue(const QString &name, double value,
                                  const QString &unit = "",
                                  std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get metrics
    virtual QVector<Metric> getMetrics(int limit = 100) const = 0;
    
    /// Get metric by name
    virtual QVector<Metric> getMetricsByName(const QString &name, int limit = 100) const = 0;
    
    /// Get aggregated metrics
    virtual MetricsAggregate getAggregatedMetrics(const QString &metricName,
                                                 const QDateTime &from,
                                                 const QDateTime &to) const = 0;
    
    // ── Performance Monitoring ──────────────────────────
    
    /// Start performance measurement
    virtual QString startPerformanceMeasurement() = 0;
    
    /// End performance measurement
    virtual qint64 endPerformanceMeasurement(const QString &measurementId) = 0;
    
    /// Get performance metrics
    virtual PerformanceMetrics getPerformanceMetrics() const = 0;
    
    /// Record execution time
    virtual void recordExecutionTime(const QString &component, qint64 timeMs,
                                    std::function<void(bool success)> callback = nullptr) = 0;
    
    // ── Alerts ──────────────────────────────────────────
    
    /// Create alert
    virtual QString createAlert(const Alert &alert,
                               AlertCallback callback = nullptr) = 0;
    
    /// Acknowledge alert
    virtual void acknowledgeAlert(const QString &alertId, const QString &by = "",
                                 std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Resolve alert
    virtual void resolveAlert(const QString &alertId,
                             std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get active alerts
    virtual QVector<Alert> getActiveAlerts() const = 0;
    
    /// Get alerts
    virtual QVector<Alert> getAlerts(int limit = 100) const = 0;
    
    /// Get alerts by severity
    virtual QVector<Alert> getAlertsBySeverity(AlertSeverity severity, int limit = 100) const = 0;
    
    /// Get alerts by component
    virtual QVector<Alert> getAlertsByComponent(const QString &component, int limit = 100) const = 0;
    
    // ── User Analytics ─────────────────────────────────
    
    /// Record user interaction
    virtual void recordUserInteraction(const QString &userId,
                                      std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get user analytics
    virtual UserAnalytics getUserAnalytics(const QString &userId) const = 0;
    
    /// Get all user analytics
    virtual QVector<UserAnalytics> getAllUserAnalytics() const = 0;
    
    /// Update user preference
    virtual void updateUserPreference(const QString &userId,
                                     const QString &key, const QVariant &value,
                                     std::function<void(bool success)> callback = nullptr) = 0;
    
    // ── Reports ────────────────────────────────────────
    
    /// Generate report
    virtual QString generateReport(ReportType type,
                                  std::function<void(const Report &)> callback = nullptr) = 0;
    
    /// Generate custom report
    virtual QString generateCustomReport(const QDateTime &from, const QDateTime &to,
                                        std::function<void(const Report &)> callback = nullptr) = 0;
    
    /// Get reports
    virtual QVector<Report> getReports(int limit = 10) const = 0;
    
    /// Get report
    virtual Report getReport(const QString &reportId) const = 0;
    
    /// Export report
    virtual QByteArray exportReport(const QString &reportId, const QString &format = "pdf") = 0;
    
    // ── Dashboard ───────────────────────────────────────
    
    /// Get dashboard data
    virtual DashboardData getDashboardData() const = 0;
    
    /// Get dashboard data for period
    virtual DashboardData getDashboardDataForPeriod(const QDateTime &from,
                                                   const QDateTime &to) const = 0;
    
    /// Update dashboard
    virtual void updateDashboard(const DashboardData &data,
                                std::function<void(bool success)> callback = nullptr) = 0;
    
    // ── Configuration ───────────────────────────────────
    
    /// Set logging configuration
    virtual void setConfiguration(const LoggingConfiguration &config,
                                 std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get configuration
    virtual LoggingConfiguration getConfiguration() const = 0;
    
    /// Set log level
    virtual void setLogLevel(LogLevel level) = 0;
    
    /// Get log level
    virtual LogLevel getLogLevel() const = 0;
    
    /// Enable/disable feature
    virtual void enableFeature(const QString &feature, bool enable) = 0;
    
    /// Is feature enabled
    virtual bool isFeatureEnabled(const QString &feature) const = 0;
    
    // ── Storage & Export ────────────────────────────────
    
    /// Flush logs to storage
    virtual void flush(std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Export logs
    virtual QByteArray exportLogs(const QString &format = "json") const = 0;
    
    /// Export events
    virtual QByteArray exportEvents(const QString &format = "json") const = 0;
    
    /// Export metrics
    virtual QByteArray exportMetrics(const QString &format = "csv") const = 0;
    
    /// Archive old data
    virtual void archiveOldData(int daysToKeep,
                               std::function<void(int archived)> callback = nullptr) = 0;
    
    /// Get storage statistics
    virtual QVariantMap getStorageStatistics() const = 0;

signals:
    /// Log recorded signal
    void logRecorded(const LogEntry &entry);
    
    /// Event recorded signal
    void eventRecorded(const Event &event);
    
    /// Alert created signal
    void alertCreated(const Alert &alert);
    
    /// Alert resolved signal
    void alertResolved(const QString &alertId);
    
    /// Metric recorded signal
    void metricRecorded(const Metric &metric);
    
    /// Report generated signal
    void reportGenerated(const Report &report);
};

using LoggingManagerPtr = std::shared_ptr<LoggingManager>;
