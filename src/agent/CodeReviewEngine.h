#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <memory>
#include <vector>

/**
 * @class CodeReviewEngine
 * @brief Automated code review system with multi-agent parallel analysis
 * 
 * Features:
 * - Parallel review agents (bug detection, best practices, performance)
 * - Confidence scoring (0-100)
 * - Historical context tracking
 * - PR change analysis
 * - Customizable review rules
 * - Integration with code quality tools
 */

class CodeReviewEngine : public QObject {
    Q_OBJECT

public:
    enum ReviewType {
        FullReview,
        BugDetection,
        BestPractices,
        Performance,
        Security,
        Documentation
    };

    enum SeverityLevel {
        Info,
        Warning,
        Error,
        Critical
    };

    struct CodeIssue {
        QString id;
        QString file;
        int lineNumber;
        SeverityLevel severity;
        QString category;
        QString description;
        QString suggestedFix;
        float confidence;  // 0-100
        bool falsePositive;
        QStringList relatedFiles;
    };

    struct ReviewResult {
        QString reviewId;
        ReviewType type;
        QVector<CodeIssue> issues;
        int totalIssues;
        int criticalCount;
        int warningCount;
        float overallScore;  // 0-100
        float passedScore;   // Passing threshold
        bool approved;
        QString summary;
        QJsonObject metadata;
        qint64 reviewTimeMs;
    };

    struct ReviewContext {
        QString prNumber;
        QString branch;
        QString targetBranch;
        QStringList changedFiles;
        QString author;
        QString description;
        QStringList labels;
    };

    explicit CodeReviewEngine(QObject* parent = nullptr);
    ~CodeReviewEngine();

    // Main review operations
    ReviewResult reviewPullRequest(const ReviewContext& context, ReviewType type = FullReview);
    ReviewResult reviewFiles(const QStringList& files, ReviewType type = FullReview);
    ReviewResult reviewChanges(const QJsonObject& changes, ReviewType type = FullReview);

    // Individual review agents
    QVector<CodeIssue> detectBugs(const QStringList& files, const ReviewContext& context);
    QVector<CodeIssue> checkBestPractices(const QStringList& files, const ReviewContext& context);
    QVector<CodeIssue> analyzePerformance(const QStringList& files, const ReviewContext& context);
    QVector<CodeIssue> checkSecurity(const QStringList& files, const ReviewContext& context);
    QVector<CodeIssue> validateDocumentation(const QStringList& files, const ReviewContext& context);

    // Issue filtering and management
    QVector<CodeIssue> filterByFileType(const QVector<CodeIssue>& issues, const QString& extension);
    QVector<CodeIssue> filterBySeverity(const QVector<CodeIssue>& issues, SeverityLevel minLevel);
    QVector<CodeIssue> deduplicateIssues(const QVector<CodeIssue>& issues);
    QVector<CodeIssue> filterFalsePositives(const QVector<CodeIssue>& issues);

    // Scoring and metrics
    float calculateReviewScore(const QVector<CodeIssue>& issues);
    float getFileScore(const QString& file);
    QJsonObject getReviewMetrics(const ReviewResult& result);
    QJsonObject getHistoricalStats();

    // Rules management
    void registerCustomRule(const QString& ruleId, const QString& pattern, 
                            SeverityLevel severity, const QString& description);
    void removeCustomRule(const QString& ruleId);
    QJsonArray getAllRules() const;
    QJsonObject getRuleById(const QString& ruleId) const;
    void enableRule(const QString& ruleId);
    void disableRule(const QString& ruleId);

    // Configuration
    void setPassingScore(float score);
    void setMaxConcurrentReviews(int count);
    void setReviewTimeout(int timeoutMs);
    void setCustomRuleFile(const QString& filePath);
    void loadRulesFromFile(const QString& filePath);

    // History and tracking
    ReviewResult getReviewHistory(const QString& reviewId);
    QVector<ReviewResult> listReviewsByFile(const QString& file);
    QVector<ReviewResult> listReviewsByAuthor(const QString& author);
    void clearReviewHistory();

    // Parallel review execution
    void runParallelReview(const ReviewContext& context);
    float getParallelReviewProgress();
    void cancelParallelReview();

    // Export and reporting
    QString generateHTMLReport(const ReviewResult& result);
    QString generateMarkdownReport(const ReviewResult& result);
    QJsonObject exportReviewJSON(const ReviewResult& result);
    void sendReviewToSlack(const ReviewResult& result, const QString& webhookUrl);

    // Statistics
    struct ReviewStats {
        int totalReviewsCompleted;
        int averageReviewTimeMs;
        float averageScore;
        QMap<QString, int> issuesByCategory;
        QMap<QString, float> falsePositiveRates;
        int filesReviewedTotal;
    };
    ReviewStats getStatistics() const;

signals:
    void reviewStarted(const QString& reviewId);
    void reviewProgressUpdated(int processed, int total);
    void issueFound(const CodeIssue& issue);
    void reviewCompleted(const ReviewResult& result);
    void reviewFailed(const QString& error);

private:
    struct ReviewRule {
        QString id;
        QString pattern;
        SeverityLevel severity;
        QString description;
        bool enabled;
        int triggerCount;
        float falsePositiveRate;
    };

    std::vector<ReviewRule> m_customRules;
    QMap<QString, ReviewResult> m_reviewHistory;
    float m_passingScore;
    int m_maxConcurrentReviews;
    int m_reviewTimeoutMs;
    ReviewStats m_statistics;

    QString m_currentReviewId;
    int m_reviewProgress;

    ReviewResult compileReviewResults(const QVector<CodeIssue>& allIssues, 
                                     const ReviewContext& context, ReviewType type);
    bool isFalsePositive(const CodeIssue& issue);
    QString generateUniqueReviewId();
};
