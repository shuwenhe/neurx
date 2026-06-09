#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class PRReviewAgents
 * @brief Specialized PR review and code quality enforcement
 * 
 * Features:
 * - Multi-reviewer agent coordination
 * - Code quality metrics validation
 * - Security scanning in PR context
 * - Performance regression detection
 * - Documentation completeness check
 * - Test coverage analysis
 * - Architecture compliance
 * - Merge readiness assessment
 */

class PRReviewAgents : public QObject {
    Q_OBJECT

public:
    enum ReviewerType {
        SecurityReviewer,
        PerformanceReviewer,
        ArchitectureReviewer,
        DocumentationReviewer,
        TestReviewer,
        CodeQualityReviewer,
        APIReviewer
    };

    enum ReviewStatus {
        Pending,
        InProgress,
        Approved,
        RequestedChanges,
        Commented,
        Dismissed
    };

    struct ReviewerAgent {
        ReviewerType type;
        QString name;
        QString expertise;
        int priority;  // 0-100
        float reviewAccuracy;  // 0-1.0
        QStringList focusAreas;
    };

    struct CodeDiff {
        QString filePath;
        QString beforeCode;
        QString afterCode;
        int linesAdded;
        int linesRemoved;
        QString changeType;  // "add", "modify", "delete"
    };

    struct ReviewFinding {
        ReviewerType reviewerType;
        QString severity;  // "critical", "major", "minor", "info"
        QString issue;
        QString suggestion;
        QString filePath;
        int lineNumber;
        float confidence;  // 0-1.0
    };

    struct PRReviewReport {
        QString prId;
        QString title;
        int totalFindings;
        QVector<ReviewFinding> findings;
        float overallQualityScore;  // 0-100
        bool readyToMerge;
        QStringList blockers;
        QStringList suggestions;
        QString summary;
    };

    struct MergeReadinessAssessment {
        bool hasRequiredReviews;
        bool passesAllChecks;
        bool hasNoConflicts;
        bool hasTestCoverage;
        bool isDocumented;
        int securityScore;  // 0-100
        int performanceScore;  // 0-100
        float recommendedMergeScore;  // 0-1.0
    };

    explicit PRReviewAgents(QObject* parent = nullptr);
    ~PRReviewAgents();

    // Reviewer management
    void registerReviewer(const ReviewerAgent& reviewer);
    ReviewerAgent getReviewer(ReviewerType type);
    QVector<ReviewerAgent> getAllReviewers();
    void setReviewerPriority(ReviewerType type, int priority);

    // Review coordination
    void startPRReview(const QString& prId, const QString& title);
    void addCodeDiff(const CodeDiff& diff);
    PRReviewReport completePRReview();

    // Individual reviewer operations
    void runSecurityReview();
    void runPerformanceReview();
    void runArchitectureReview();
    void runDocumentationReview();
    void runTestCoverageReview();
    void runCodeQualityReview();

    // Finding management
    void addFinding(const ReviewFinding& finding);
    QVector<ReviewFinding> getFindingsBySeverity(const QString& severity);
    QVector<ReviewFinding> getFindingsByFile(const QString& filePath);
    int countFindingsBySeverity(const QString& severity);

    // Analysis operations
    float calculateCodeQualityScore();
    float detectPerformanceRegression();
    bool checkArchitectureCompliance();
    bool validateTestCoverage();
    QStringList validateDocumentation();
    bool runSecurityScan();

    // Merge readiness
    MergeReadinessAssessment assessMergeReadiness();
    bool canMerge();
    QStringList getMergeBlockers();
    QString generateMergeReadinessReport();

    // Automated suggestions
    QStringList suggestImprovements();
    QStringList suggestOptimizations();
    QStringList suggestSecurityEnhancements();
    QString suggestRefactorings();

    // Collaboration
    struct ReviewComment {
        ReviewerType reviewer;
        QString comment;
        QString filePath;
        int lineNumber;
        QDateTime timestamp;
    };
    void addReviewComment(const ReviewComment& comment);
    QVector<ReviewComment> getReviewComments();

    // Statistics
    struct ReviewStats {
        int reviewsCompleted;
        int totalFindingsFound;
        float avgReviewTime;
        float avgQualityScore;
        int mergesApproved;
        int mergesRejected;
    };
    ReviewStats getStatistics();

    // Continuous improvement
    void trainReviewers(const QString& trainingData);
    void calibrateReviewers();

signals:
    void reviewStarted(const QString& prId);
    void reviewerAnalysisCompleted(ReviewerType reviewer);
    void findingDiscovered(const ReviewFinding& finding);
    void reviewCompleted(const PRReviewReport& report);
    void mergeBlockerDetected(const QString& blocker);
    void readyToMerge();

private:
    QString m_currentPRId;
    QVector<CodeDiff> m_diffs;
    QMap<ReviewerType, ReviewerAgent> m_reviewers;
    QVector<ReviewFinding> m_findings;
    QVector<ReviewComment> m_comments;
    ReviewStats m_stats;

    void initializeDefaultReviewers();
};
