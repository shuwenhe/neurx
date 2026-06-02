#pragma once

#include <QString>
#include <QVector>
#include <QMap>
#include <QVariantMap>
#include <QDateTime>
#include <functional>

/**
 * Logging and analytics types for comprehensive agent monitoring
 */

// ── Log Levels ─────────────────────────────────────────

enum class LogLevel {
    Trace,      // Most verbose
    Debug,      // Debug info
    Info,       // General info
    Warning,    // Warning
    Error,      // Error
    Critical,   // Critical error
    Fatal       // Fatal error
};

// ── Event Types ────────────────────────────────────────

enum class EventType {
    // Lifecycle events
    AgentStarted,
    AgentStopped,
    AgentInitialized,
    
    // Execution events
    ExecutionStarted,
    ExecutionCompleted,
    ExecutionFailed,
    ExecutionRetry,
    
    // LLM events
    LLMRequest,
    LLMResponse,
    TokenUsage,
    
    // Tool events
    ToolLoaded,
    ToolExecuted,
    ToolFailed,
    
    // Memory events
    MemoryStored,
    MemoryRetrieved,
    MemoryCleared,
    
    // Performance events
    PerformanceAlert,
    ResourceAlert,
    
    // User events
    UserInteraction,
    UserInput,
    UserOutput,
    
    // System events
    SystemError,
    SystemWarning,
    ConfigurationChanged,
    
    // Business events
    GoalAchieved,
    SkillLearned,
    ConversationTurn,
    
    Custom  // Custom event type
};

// ── Log Entry ──────────────────────────────────────────

struct LogEntry {
    QString logId;
    LogLevel level;
    QString message;
    QString category;              // e.g., "execution", "llm", "tool"
    
    QString source;                // Where it came from
    QString context;               // Additional context
    
    QVariantMap data;              // Additional data
    
    QDateTime timestamp;
    qint64 elapsedMs = 0;          // Time since last log
    
    QString stackTrace;            // For errors
    QString threadId;              // Thread information
};

// ── Event ──────────────────────────────────────────────

struct Event {
    QString eventId;
    EventType type;
    QString name;
    QString description;
    
    QVariantMap properties;        // Event properties
    QVariantMap context;           // Context data
    
    QDateTime timestamp;
    qint64 durationMs = 0;         // Event duration
    
    bool success = true;           // Was it successful
    QString errorMessage;          // Error if any
    
    QString userId;                // User ID if applicable
    QString sessionId;             // Session ID
};

// ── Metrics ────────────────────────────────────────────

struct Metric {
    QString metricId;
    QString name;
    QString category;
    
    double value = 0.0;
    QString unit;                  // e.g., "ms", "tokens", "%"
    
    double minValue = 0.0;
    double maxValue = 100.0;
    double threshold = 80.0;       // Alert threshold
    
    QDateTime timestamp;
    QDateTime collectedAt;
    
    QVariantMap tags;              // Metric tags
};

/// Aggregated metrics over time period
struct MetricsAggregate {
    QString metricName;
    
    double sum = 0.0;
    double average = 0.0;
    double median = 0.0;
    double stdDev = 0.0;
    double min = 0.0;
    double max = 0.0;
    
    int count = 0;
    int samplingRate = 100;        // % of values sampled
    
    QDateTime periodStart;
    QDateTime periodEnd;
};

// ── Performance Metrics ────────────────────────────────

struct PerformanceMetrics {
    // Execution metrics
    int totalExecutions = 0;
    int successfulExecutions = 0;
    int failedExecutions = 0;
    float successRate = 0.0f;
    
    float averageExecutionTime = 0.0f;  // ms
    float maxExecutionTime = 0.0f;
    float minExecutionTime = 0.0f;
    
    // Resource metrics
    int peakMemoryUsage = 0;       // bytes
    float averageCpuUsage = 0.0f;  // percentage
    
    // LLM metrics
    int totalTokens = 0;
    float totalCost = 0.0f;
    float averageLatency = 0.0f;   // ms
    
    // Tool metrics
    int toolsLoaded = 0;
    int toolsActive = 0;
    
    QDateTime collectedAt;
};

// ── User Analytics ────────────────────────────────────

struct UserAnalytics {
    QString userId;
    
    int totalInteractions = 0;
    int totalConversations = 0;
    int totalTokensUsed = 0;
    
    QDateTime firstInteraction;
    QDateTime lastInteraction;
    
    float averageConversationLength = 0.0f;  // turns
    float averageResponseTime = 0.0f;        // ms
    
    QStringList skillsUsed;
    QStringList toolsUsed;
    
    QVariantMap preferences;
};

// ── Alert ──────────────────────────────────────────────

enum class AlertSeverity {
    Info,       // Informational
    Warning,    // Warning
    Error,      // Error
    Critical    // Critical
};

struct Alert {
    QString alertId;
    AlertSeverity severity;
    QString message;
    QString category;
    
    QString affectedComponent;     // Component affected
    
    double metricValue = 0.0;      // Metric that triggered alert
    double threshold = 0.0;
    
    bool acknowledged = false;
    QString acknowledgedBy;
    QDateTime acknowledgedAt;
    
    QDateTime createdAt;
    QDateTime resolvedAt;
};

// ── Report ─────────────────────────────────────────────

enum class ReportType {
    Daily,
    Weekly,
    Monthly,
    Custom
};

struct Report {
    QString reportId;
    ReportType type;
    QString title;
    QString description;
    
    QDateTime generatedAt;
    QDateTime coveragePeriodStart;
    QDateTime coveragePeriodEnd;
    
    QVariantMap summary;           // Summary statistics
    QVector<Metric> metrics;       // Detailed metrics
    QVector<Alert> alerts;         // Alerts in period
    QVector<Event> events;         // Events in period
    
    QVariantMap recommendations;   // Recommendations
    
    QString generatedBy;           // Who generated it
};

// ── Analytics Dashboard ────────────────────────────────

struct DashboardData {
    QString dashboardId;
    QString title;
    
    int totalEvents = 0;
    int totalErrors = 0;
    int totalAlerts = 0;
    
    float successRate = 0.0f;
    float averageLatency = 0.0f;
    float totalCost = 0.0f;
    
    QVector<Metric> topMetrics;    // Top 10 metrics
    QVector<Alert> activeAlerts;   // Active alerts
    QVector<Event> recentEvents;   // Recent events
    
    QVariantMap charts;            // Chart data for visualization
    
    QDateTime updatedAt;
};

// ── Sampling & Configuration ───────────────────────────

struct LoggingConfiguration {
    LogLevel minimumLevel = LogLevel::Info;  // Minimum to log
    
    bool enableEventLogging = true;
    bool enableMetricsLogging = true;
    bool enablePerformanceLogging = true;
    
    int maxLogSize = 1000000;      // Max size before rotation
    int maxLogFiles = 10;          // Number of rotated files
    
    int metricsSamplingRate = 100; // Percentage
    int eventsSamplingRate = 100;
    
    bool enableRemoteLogging = false;
    QString remoteEndpoint;        // Remote logging endpoint
    
    int flushIntervalMs = 5000;    // Flush logs every N ms
};

// ── Callbacks ──────────────────────────────────────────

using LogCallback = std::function<void(const LogEntry &)>;
using EventCallback = std::function<void(const Event &)>;
using AlertCallback = std::function<void(const Alert &)>;
using MetricsCallback = std::function<void(const QVector<Metric> &)>;
using ReportCallback = std::function<void(const Report &)>;

#endif // LOGGINGTYPES_H
