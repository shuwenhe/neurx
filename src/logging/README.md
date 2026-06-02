# Neurx Logging and Analytics System

The Logging and Analytics System provides comprehensive monitoring, tracking, and analysis of agent activities, performance, and user interactions.

## Overview

The logging and analytics system provides:
- Event logging and tracking
- Performance monitoring
- User analytics
- Alert management
- Report generation
- Dashboard visualization

## Core Components

### Log Levels

```cpp
enum class LogLevel {
    Trace,      // Most verbose
    Debug,      // Debug info
    Info,       // General info
    Warning,    // Warning
    Error,      // Error
    Critical,   // Critical error
    Fatal       // Fatal error
};
```

### Event Types

```cpp
enum class EventType {
    AgentStarted, AgentStopped, AgentInitialized,
    ExecutionStarted, ExecutionCompleted, ExecutionFailed, ExecutionRetry,
    LLMRequest, LLMResponse, TokenUsage,
    ToolLoaded, ToolExecuted, ToolFailed,
    MemoryStored, MemoryRetrieved, MemoryCleared,
    PerformanceAlert, ResourceAlert,
    UserInteraction, UserInput, UserOutput,
    SystemError, SystemWarning, ConfigurationChanged,
    GoalAchieved, SkillLearned, ConversationTurn,
    Custom
};
```

### Alert Severity

```cpp
enum class AlertSeverity {
    Info,       // Informational
    Warning,    // Warning
    Error,      // Error
    Critical    // Critical
};
```

## Usage Examples

### Basic Logging

```cpp
// Simple logging
logging->logInfo("Agent started successfully");

logging->logWarning("High memory usage detected", "performance");

logging->logError("Tool execution failed", "tool_error");

logging->logDebug("Processing request", "execution");

// Logging with additional data
logging->logWithData(LogLevel::Info, "Tool executed",
                    "tool_execution",
                    {{"toolName", "Calculator"},
                     {"duration", 150}});
```

### Getting Logs

```cpp
// Get recent logs
auto logs = logging->getLogEntries(100);

// Get logs by level
auto errors = logging->getLogsByLevel(LogLevel::Error, 50);

// Get logs by category
auto execution = logging->getLogsByCategory("execution", 100);

// Get logs by time range
QDateTime from = QDateTime::currentDateTime().addHours(-1);
QDateTime to = QDateTime::currentDateTime();
auto recentLogs = logging->getLogsByTimeRange(from, to);

// Clear logs
logging->clearLogs([](bool success) {
    qDebug() << "Logs cleared:" << success;
});
```

### Event Recording

```cpp
// Record event
Event event;
event.type = EventType::ExecutionCompleted;
event.name = "Task completed";
event.success = true;
event.durationMs = 5000;

QString eventId = logging->recordEvent(event, [](const Event &evt) {
    qDebug() << "Event recorded:" << evt.eventId;
});

// Record event with properties
auto id = logging->recordEventWithProperties(
    EventType::LLMRequest,
    "API call",
    {{"provider", "OpenAI"},
     {"model", "gpt-4"},
     {"tokens", 256}},
    [](const Event &event) {
        qDebug() << "LLM event:" << event.name;
    });

// Get events
auto events = logging->getEvents(100);

// Get events by type
auto llmEvents = logging->getEventsByType(EventType::LLMRequest, 50);

// Get events by time range
auto periodEvents = logging->getEventsByTimeRange(from, to);

// Get events by user
auto userEvents = logging->getEventsByUser("user123", 100);

// Get events by session
auto sessionEvents = logging->getEventsBySession("session456", 100);

// Clear events
logging->clearEvents([](bool success) {
    qDebug() << "Events cleared";
});
```

### Metrics Recording

```cpp
// Record metric
Metric metric;
metric.name = "execution_time";
metric.value = 150.5;
metric.unit = "ms";

logging->recordMetric(metric, [](bool success) {
    qDebug() << "Metric recorded";
});

// Record metric value directly
logging->recordMetricValue("memory_usage", 524288, "bytes");
logging->recordMetricValue("cpu_usage", 45.5, "%");

// Get metrics
auto metrics = logging->getMetrics(100);

// Get metrics by name
auto times = logging->getMetricsByName("execution_time", 50);

// Get aggregated metrics
auto agg = logging->getAggregatedMetrics("execution_time", from, to);
qDebug() << "Average:" << agg.average;
qDebug() << "Max:" << agg.max;
qDebug() << "StdDev:" << agg.stdDev;
```

### Performance Monitoring

```cpp
// Start measurement
QString measId = logging->startPerformanceMeasurement();

// ... do work ...

// End measurement
qint64 elapsed = logging->endPerformanceMeasurement(measId);
qDebug() << "Elapsed time:" << elapsed << "ms";

// Record execution time
logging->recordExecutionTime("tool_execution", 234,
    [](bool success) {
        qDebug() << "Execution time recorded";
    });

// Get performance metrics
auto perfMetrics = logging->getPerformanceMetrics();
qDebug() << "Total executions:" << perfMetrics.totalExecutions;
qDebug() << "Success rate:" << perfMetrics.successRate;
qDebug() << "Avg latency:" << perfMetrics.averageLatency << "ms";
```

### Alert Management

```cpp
// Create alert
Alert alert;
alert.severity = AlertSeverity::Warning;
alert.message = "High memory usage";
alert.affectedComponent = "execution_engine";
alert.threshold = 80.0;

auto alertId = logging->createAlert(alert, [](const Alert &a) {
    qDebug() << "Alert created:" << a.alertId;
});

// Acknowledge alert
logging->acknowledgeAlert(alertId, "admin", [](bool success) {
    qDebug() << "Alert acknowledged";
});

// Resolve alert
logging->resolveAlert(alertId, [](bool success) {
    qDebug() << "Alert resolved";
});

// Get active alerts
auto active = logging->getActiveAlerts();

// Get all alerts
auto allAlerts = logging->getAlerts(50);

// Get alerts by severity
auto critical = logging->getAlertsBySeverity(AlertSeverity::Critical, 10);

// Get alerts by component
auto execAlerts = logging->getAlertsByComponent("execution_engine", 20);
```

### User Analytics

```cpp
// Record user interaction
logging->recordUserInteraction("user123", [](bool success) {
    qDebug() << "Interaction recorded";
});

// Get user analytics
auto userAnalytics = logging->getUserAnalytics("user123");
qDebug() << "Total interactions:" << userAnalytics.totalInteractions;
qDebug() << "Last interaction:" << userAnalytics.lastInteraction.toString();
qDebug() << "Skills used:" << userAnalytics.skillsUsed;

// Get all user analytics
auto allAnalytics = logging->getAllUserAnalytics();

// Update user preference
logging->updateUserPreference("user123", "theme", "dark",
    [](bool success) {
        qDebug() << "Preference updated";
    });
```

### Report Generation

```cpp
// Generate daily report
auto reportId = logging->generateReport(ReportType::Daily,
    [](const Report &report) {
        qDebug() << "Report generated:" << report.reportId;
        qDebug() << "Total events:" << report.totalEvents;
        qDebug() << "Total alerts:" << report.totalAlerts;
    });

// Generate weekly report
logging->generateReport(ReportType::Weekly, [](const Report &report) {
    qDebug() << "Weekly report ready";
});

// Generate custom report
logging->generateCustomReport(from, to, [](const Report &report) {
    qDebug() << "Custom report generated";
    
    // Access report data
    for (const auto &event : report.events) {
        qDebug() << "Event:" << event.name;
    }
});

// Get reports
auto reports = logging->getReports(10);

// Get specific report
auto report = logging->getReport(reportId);

// Export report
auto pdfData = logging->exportReport(reportId, "pdf");
if (!pdfData.isEmpty()) {
    // Save or send the PDF
}
```

### Dashboard

```cpp
// Get dashboard data
auto dashboard = logging->getDashboardData();
qDebug() << "Total events:" << dashboard.totalEvents;
qDebug() << "Total alerts:" << dashboard.totalAlerts;
qDebug() << "Success rate:" << dashboard.successRate;

// Get dashboard for period
auto periodDash = logging->getDashboardDataForPeriod(from, to);

// Update dashboard
logging->updateDashboard(dashboard, [](bool success) {
    qDebug() << "Dashboard updated";
});
```

### Configuration

```cpp
// Set configuration
LoggingConfiguration config;
config.minimumLevel = LogLevel::Info;
config.enableEventLogging = true;
config.enableMetricsLogging = true;
config.maxLogSize = 1000000;
config.maxLogFiles = 10;

logging->setConfiguration(config, [](bool success) {
    qDebug() << "Configuration updated";
});

// Get configuration
auto cfg = logging->getConfiguration();

// Set log level
logging->setLogLevel(LogLevel::Debug);

// Get log level
auto level = logging->getLogLevel();

// Enable/disable features
logging->enableFeature("events", true);
logging->enableFeature("metrics", true);

// Check feature
if (logging->isFeatureEnabled("alerts")) {
    qDebug() << "Alerts enabled";
}
```

### Export and Storage

```cpp
// Flush logs
logging->flush([](bool success) {
    qDebug() << "Logs flushed to storage";
});

// Export logs as JSON
auto json = logging->exportLogs("json");

// Export events as JSON
auto eventJson = logging->exportEvents("json");

// Export metrics as CSV
auto csv = logging->exportMetrics("csv");

// Archive old data
logging->archiveOldData(30, [](int archived) {
    qDebug() << "Archived" << archived << "old entries";
});

// Get storage statistics
auto stats = logging->getStorageStatistics();
qDebug() << "Logs count:" << stats["logsCount"];
qDebug() << "Events count:" << stats["eventsCount"];
qDebug() << "Metrics count:" << stats["metricsCount"];
```

## Signals and Events

```cpp
// Log recorded
connect(logging.get(), &LoggingManager::logRecorded,
    [](const LogEntry &entry) {
        qDebug() << "Log:" << entry.message;
    });

// Event recorded
connect(logging.get(), &LoggingManager::eventRecorded,
    [](const Event &event) {
        qDebug() << "Event:" << event.name;
    });

// Alert created
connect(logging.get(), &LoggingManager::alertCreated,
    [](const Alert &alert) {
        qDebug() << "Alert:" << alert.message;
    });

// Alert resolved
connect(logging.get(), &LoggingManager::alertResolved,
    [](const QString &alertId) {
        qDebug() << "Alert resolved:" << alertId;
    });

// Metric recorded
connect(logging.get(), &LoggingManager::metricRecorded,
    [](const Metric &metric) {
        qDebug() << "Metric:" << metric.name << "=" << metric.value;
    });

// Report generated
connect(logging.get(), &LoggingManager::reportGenerated,
    [](const Report &report) {
        qDebug() << "Report ready:" << report.reportId;
    });
```

## Best Practices

1. **Use appropriate log levels** - Info for important events, Debug for development
2. **Categorize logs** - Use categories for filtering
3. **Monitor performance** - Record execution times for critical operations
4. **Set alert thresholds** - Define when alerts should trigger
5. **Archive old data** - Regularly clean up to manage storage
6. **Export reports** - Generate reports for analysis
7. **Track user analytics** - Understand user behavior
8. **Use sampling** - Reduce overhead with sampling for high-volume events
9. **Enable/disable features** - Control overhead by disabling unused features
10. **Flush regularly** - Ensure logs are persisted to storage

## Architecture

The logging system uses:
- **Event-driven design** - Signals for event notifications
- **Async callbacks** - Non-blocking operations
- **Thread safety** - QMutex protection
- **Time-based filtering** - Query by date ranges
- **Aggregation** - Compute statistics over periods
- **Multi-format export** - JSON, CSV, PDF support
- **Performance tracking** - Measure execution times
- **Alert management** - Track and manage system alerts
- **User analytics** - Track user interactions
- **Report generation** - Automated reporting

## Integration Points

- **ExecutionEngine** - Track execution events
- **LLMExtensions** - Log LLM requests and responses
- **MemoryManager** - Track memory operations
- **ToolRegistry** - Track tool execution
- **StateManager** - Record state changes
