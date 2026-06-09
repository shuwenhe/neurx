#pragma once

#include <QObject>
#include <QString>
#include <QMap>
#include <QSet>
#include <QVector>
#include <QDateTime>
#include <QJsonObject>

/**
 * @class IssueActivityMonitor
 * @brief Monitors GitHub issue activity and detects stale issues
 * 
 * Based on sweep.ts patterns. Tracks issue activity, identifies stale issues,
 * marks them with appropriate labels, and closes expired issues.
 */
class IssueActivityMonitor : public QObject {
    Q_OBJECT

public:
    explicit IssueActivityMonitor(QObject* parent = nullptr);
    ~IssueActivityMonitor();

    // Activity types
    enum ActivityType {
        Comment,
        Label,
        Reaction,
        StateChange,
        Assignment
    };

    // Activity event
    struct ActivityEvent {
        int issueNumber;
        ActivityType type;
        QDateTime timestamp;
        QString userId;
        QString details;
        bool isHumanActivity;  // Exclude bot comments
    };

    // Issue state tracking
    struct IssueState {
        int number;
        QString title;
        QString state;  // "open" or "closed"
        QString stateReason;
        QDateTime createdAt;
        QDateTime updatedAt;
        QDateTime lastActivityAt;
        int assigneeCount;
        int reactionCount;
        QSet<QString> labels;
        QVector<ActivityEvent> recentActivity;
        int upvoteCount;  // 👍 reactions
    };

    // Monitoring configuration
    struct MonitorConfig {
        int staleDays = 14;
        int closeExpirationDays = 7;
        int upvoteThresholdForPreservation = 10;
        bool scanOpenOnly = true;
        int maxIssuesPerPass = 100;
        int maxPages = 10;
        bool processAssignedIssues = false;
        bool processLockedIssues = false;
    };

    // Start monitoring
    void startMonitoring(const MonitorConfig& config);
    void stopMonitoring();
    void pauseMonitoring();
    void resumeMonitoring();

    // Mark stale issues
    int markStaleIssues(const MonitorConfig& config);
    
    // Close expired issues
    int closeExpiredIssues(const MonitorConfig& config);
    
    // Activity tracking
    void recordActivity(const ActivityEvent& event);
    QVector<ActivityEvent> getRecentActivity(int issueNumber, int maxDays = 7);
    
    // Stale detection
    bool isStaleIssue(const IssueState& issue, const MonitorConfig& config);
    bool shouldPreserveIssue(const IssueState& issue, const MonitorConfig& config);
    
    // Human activity check
    bool hasHumanActivitySince(int issueNumber, const QDateTime& sinceTime);
    
    // Issue state management
    IssueState getIssueState(int issueNumber);
    void updateIssueState(const IssueState& state);
    
    // Label management for stale issues
    void markAsStale(int issueNumber);
    void markForAutoclose(int issueNumber);
    void removeStaleLabel(int issueNumber);
    
    // Close operations
    void closeIssueAsNotPlanned(int issueNumber, const QString& reason);
    void postCloseMessage(int issueNumber, const QString& reason);
    
    // Upvote tracking
    int getUpvoteCount(int issueNumber);
    
    // Statistics and reporting
    QJsonObject getMonitoringStatistics() const;
    QVector<IssueState> getStaleIssues(const MonitorConfig& config);
    QVector<IssueState> getExpiredIssues(const MonitorConfig& config);
    
    // Batch operations
    int processIssuesPaginatedStale(const MonitorConfig& config);
    int processIssuesPaginatedExpired(const MonitorConfig& config);
    
    // Filtering helpers
    bool shouldSkipIssue(const IssueState& issue, const MonitorConfig& config);
    bool isAssignedOrLocked(const IssueState& issue, const MonitorConfig& config);
    
    // Activity detection
    QDateTime getLastActivityTime(int issueNumber);
    int getDaysSinceActivity(int issueNumber);

signals:
    void monitoringStarted();
    void monitoringStopped();
    void issuMarkedStale(int issueNumber);
    void issuMarkedForAutoClose(int issueNumber);
    void issueClosing(int issueNumber);
    void issueClosed(int issueNumber);
    void activityDetected(int issueNumber, const QString& activityType);
    void staleIssueFound(int issueNumber, const QString& title, int daysInactive);
    void expiredIssueFound(int issueNumber, const QString& title, int daysExpired);
    void monitoringProgress(int processed, int staleFound, int closed);
    void monitoringPaused();
    void monitoringResumed();
    void errorOccurred(const QString& error);

private:
    // Configuration
    MonitorConfig m_config;
    
    // State
    bool m_isMonitoring = false;
    bool m_isPaused = false;
    
    // Statistics
    int m_totalProcessed = 0;
    int m_totalMarkedStale = 0;
    int m_totalClosed = 0;
    
    // Issue state cache
    QMap<int, IssueState> m_issueStates;
    
    // Activity log
    QVector<ActivityEvent> m_activityLog;
    
    // Configuration defaults
    static const QVector<QString> DEFAULT_STALE_LABELS;
    static const QString STALE_LABEL;
    static const QString AUTOCLOSE_LABEL;

    // Helper methods
    void processStalePass();
    void processExpirePass();
    bool hasRecentHumanComment(int issueNumber, const QDateTime& sinceTime);
    QDateTime getIssueLastLabelTime(int issueNumber, const QString& label);
    void pruneOldActivityLogs();
    void logStatistics();
};
