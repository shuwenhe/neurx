#pragma once

#include <QObject>
#include <QString>
#include <QMap>
#include <QVector>
#include <QJsonObject>
#include <QDateTime>
/**
 * @class DuplicateDetectionBackfill
 * @brief Backfill duplicate detection comments on historical issues
 * 
 * Processes closed and old issues to trigger duplicate detection workflows.
 * Uses pagination to handle large issue sets efficiently.
 */
class DuplicateDetectionBackfill : public QObject {
    Q_OBJECT

public:
    explicit DuplicateDetectionBackfill(QObject* parent = nullptr);
    ~DuplicateDetectionBackfill();

    // Issue state structure
    struct IssueData {
        int number;
        QString title;
        QString state;
        QString stateReason;  // e.g., "duplicate", "not_planned"
        int userId;
        QDateTime createdAt;
        QDateTime closedAt;
        int commentCount;
        bool isDuplicate;
    };

    // Detection status
    struct DetectionStatus {
        int issueNumber;
        bool hasDuplicateComment;
        QDateTime commentDetectedAt;
        QString detectionDetails;
        bool workflowTriggered;
    };

    // Backfill configuration
    struct BackfillConfig {
        int minIssueNumber = 1;
        int maxIssueNumber = 4050;
        bool dryRunMode = true;
        bool skipWithExistingComments = true;
        int delayBetweenRequests = 1000;  // milliseconds
        int maxPages = 200;
        int perPage = 100;
        bool processOpenOnly = false;
    };

    // Process issues in range
    void startBackfill(const BackfillConfig& config);
    void pauseBackfill();
    void resumeBackfill();
    void cancelBackfill();

    // Check if issue needs backfill
    bool shouldProcessIssue(const IssueData& issue, const BackfillConfig& config);
    
    // Detect existing duplicate comments
    bool hasDuplicateDetectionComment(int issueNumber);
    
    // Trigger workflow for issue
    bool triggerDedupeWorkflow(int issueNumber, bool dryRun = true);
    
    // Get detection status for issue
    DetectionStatus getDetectionStatus(int issueNumber);
    
    // Batch processing
    int processIssueBatch(const QVector<IssueData>& issues, const BackfillConfig& config);
    
    // Get statistics
    QJsonObject getStatistics() const;
    
    // Pagination support
    QVector<IssueData> fetchIssuesPage(int page, const BackfillConfig& config);
    
    // Safe workflow dispatch
    void dispatchWorkflow(int issueNumber, const QString& workflowId);
    
    // Logging helpers
    void logProgress(int processed, int total, int triggered);
    void logError(int issueNumber, const QString& error);

signals:
    void backfillStarted(int totalIssues);
    void issueProcessed(int issueNumber, bool triggered);
    void duplicateDetectionTriggered(int issueNumber);
    void backfillProgress(int processed, int total);
    void backfillCompleted(int processedCount, int triggeredCount);
    void backfillPaused();
    void backfillResumed();
    void backfillCancelled();
    void errorOccurred(const QString& error);

private:
    // Configuration
    BackfillConfig m_config;
    
    // State tracking
    bool m_isRunning = false;
    bool m_isPaused = false;
    
    // Statistics
    int m_totalProcessed = 0;
    int m_totalTriggered = 0;
    int m_currentPage = 1;
    
    // Cache of detection statuses
    QMap<int, DetectionStatus> m_detectionStatusCache;
    
    // Comment detection keywords
    QVector<QString> m_duplicateKeywords = {
        "Found",
        "possible duplicate",
        "duplicate of",
        "similar to"
    };

    // Helper methods
    void processIssueInternal(const IssueData& issue);
    bool validateIssue(const IssueData& issue) const;
    bool shouldSkip(const IssueData& issue) const;
    void updateStatistics(bool wasTriggered);
    QDateTime parseGitHubTimestamp(const QString& timestamp);
};
