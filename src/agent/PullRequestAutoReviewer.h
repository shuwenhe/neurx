#pragma once

#include <QObject>
#include <QString>
#include <QMap>
#include <QVector>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>

/**
 * @class PullRequestAutoReviewer
 * @brief Automated PR review with confidence scoring and pattern detection
 * 
 * Analyzes pull requests for common patterns, detects issues, and provides
 * review comments with confidence levels.
 */
class PullRequestAutoReviewer : public QObject {
    Q_OBJECT

public:
    explicit PullRequestAutoReviewer(QObject* parent = nullptr);
    ~PullRequestAutoReviewer();

    // Review severity levels
    enum SeverityLevel {
        Info,
        Warning,
        Error,
        Critical
    };

    // Code pattern detection
    struct CodePattern {
        QString patternName;
        QString description;
        SeverityLevel severity;
        float confidenceScore;  // 0.0 - 1.0
        QString suggestion;
        bool isSecurityIssue;
    };

    // Review finding
    struct ReviewFinding {
        int prNumber;
        CodePattern pattern;
        QString filePath;
        int lineNumber;
        QString codeSnippet;
        QDateTime detectedAt;
    };

    // PR metadata
    struct PRMetadata {
        int number;
        QString title;
        QString author;
        int addedLines;
        int removedLines;
        int changedFiles;
        QVector<QString> fileExtensions;  // .ts, .js, .cpp, etc.
        float complexityScore;
        QDateTime createdAt;
    };

    // Review configuration
    struct ReviewConfig {
        bool detectSecurityIssues = true;
        bool detectPerformanceIssues = true;
        bool detectCodeStyleIssues = true;
        float confidenceThreshold = 0.7f;
        int maxFindingsPerPR = 20;
        bool includeSuggestions = true;
        bool generateSummaryComment = true;
        QString reviewerName = "Auto-Reviewer";
    };

    // Review result
    struct ReviewResult {
        int prNumber;
        int totalFindings = 0;
        int criticalIssues = 0;
        int warnings = 0;
        float averageConfidence = 0.0f;
        bool requiresHumanReview = false;
        QString overallRating;  // "Pass", "Needs Review", "Reject"
        QVector<ReviewFinding> findings;
        QString summaryComment;
    };

    // Start reviewing PRs
    void reviewPullRequest(int prNumber, const ReviewConfig& config);
    void reviewMultiplePRs(const QVector<int>& prNumbers, const ReviewConfig& config);
    
    // Pattern detection
    void detectSecurityPatterns(const ReviewFinding& finding);
    void detectPerformancePatterns(const ReviewFinding& finding);
    void detectCodeStylePatterns(const ReviewFinding& finding);
    
    // Code analysis
    QVector<CodePattern> analyzeCode(const QString& code, const QString& language);
    float calculateComplexityScore(const QString& code);
    float calculateConfidenceScore(const CodePattern& pattern);
    
    // Review generation
    ReviewResult generateReview(int prNumber, const ReviewConfig& config);
    QString generateReviewComment(const ReviewResult& result, const ReviewConfig& config);
    QString generateSummaryComment(const ReviewResult& result);
    
    // Posting reviews
    void postReviewComment(int prNumber, const QString& comment);
    void postReviewFindings(int prNumber, const QVector<ReviewFinding>& findings);
    void postReviewSummary(int prNumber, const ReviewResult& result);
    
    // Get review data
    ReviewResult getReviewResult(int prNumber);
    QVector<ReviewFinding> getReviewFindings(int prNumber);
    QJsonObject getReviewStatistics() const;
    
    // Pattern library management
    void registerPattern(const CodePattern& pattern);
    QVector<CodePattern> getPatterns(SeverityLevel severity);
    void updatePatternConfidence(const QString& patternName, float newConfidence);
    
    // Configuration
    void setReviewConfig(const ReviewConfig& config);
    ReviewConfig getReviewConfig() const;
    
    // Confidence scoring
    float getAverageConfidence(const ReviewResult& result);
    bool meetsConfidenceThreshold(const ReviewResult& result, float threshold);
    
    // Helper methods
    bool isSecuritySensitiveFile(const QString& filePath);
    QString getFileLanguage(const QString& filePath);
    QString truncateCodeSnippet(const QString& code, int maxLines = 3);

signals:
    void reviewStarted(int prNumber);
    void reviewCompleted(int prNumber);
    void findingDetected(int prNumber, const QString& patternName, int severity);
    void reviewCommented(int prNumber);
    void reviewSummaryPosted(int prNumber);
    void confidenceScoreCalculated(float score);
    void errorOccurred(const QString& error);

private:
    // Configuration
    ReviewConfig m_config;
    
    // Pattern registry
    QMap<QString, CodePattern> m_patternRegistry;
    
    // Review cache
    QMap<int, ReviewResult> m_reviewResults;
    QMap<int, QVector<ReviewFinding>> m_reviewFindings;
    
    // Statistics
    int m_totalReviewsPerformed = 0;
    int m_totalFindingsDetected = 0;
    float m_totalConfidenceAccumulated = 0.0f;
    
    // Language-specific patterns
    QMap<QString, QVector<CodePattern>> m_languagePatterns;
    
    // Security keywords
    static const QVector<QString> SECURITY_KEYWORDS;
    static const QVector<QString> PERFORMANCE_KEYWORDS;
    static const QVector<QString> STYLE_KEYWORDS;

    // Helper methods
    void initializePatterns();
    void detectPatternInCode(const QString& code, const CodePattern& pattern, const QString& filePath, int lineNumber);
    float calculateContextAwareness(const CodePattern& pattern, const QString& code);
    QString formatFindingMessage(const ReviewFinding& finding);
    QString generateDetailedSuggestion(const CodePattern& pattern);
};
