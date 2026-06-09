#pragma once

#include <QObject>
#include <QString>
#include <QMap>
#include <QVector>
#include <QJsonObject>

/**
 * @class CommentQualityAnalyzer
 * @brief Analyzes code comments for accuracy and maintenance
 * 
 * Based on pr-review-toolkit's comment-analyzer. Verifies comments for factual
 * accuracy, completeness, and long-term maintainability.
 */
class CommentQualityAnalyzer : public QObject {
    Q_OBJECT

public:
    explicit CommentQualityAnalyzer(QObject* parent = nullptr);
    ~CommentQualityAnalyzer();

    // Comment issue types
    enum CommentIssue {
        Inaccurate,             // Comment doesn't match code
        Outdated,               // Comment mentions refactored code
        Misleading,             // Comment could be misinterpreted
        Redundant,              // Comment just repeats obvious code
        Incomplete,             // Missing important context
        MissingEdgeCases,       // Doesn't mention edge cases
        AmbiguousLanguage,      // Vague or unclear wording
        BrokenReference         // References non-existent code
    };

    // Comment finding
    struct CommentFinding {
        int lineNumber;
        int endLineNumber;
        QString filePath;
        CommentIssue issueType;
        float severity;         // 0.0-1.0
        QString commentText;
        QString associatedCode;
        QString issue;
        QString suggestion;
        float accuracy;         // How accurate (0.0-1.0)
        bool isDocumentation;   // Is this a docstring/doc comment
    };

    // Analysis result
    struct CommentAnalysis {
        QString filePath;
        int totalComments = 0;
        int documentationComments = 0;
        int inlineComments = 0;
        int criticalIssues = 0;
        int minorIssues = 0;
        QVector<CommentFinding> findings;
        float overallQuality;   // 0.0-1.0
        QString summary;
    };

    // Config
    struct AnalysisConfig {
        bool checkAccuracy = true;
        bool checkCompleteness = true;
        bool checkForRedundancy = true;
        bool checkReferences = true;
        bool checkDocumentation = true;
        float minAcceptableQuality = 0.75f;
    };

    // Analysis
    void analyzeComments(const QString& code, const QString& filePath, const AnalysisConfig& config);
    void analyzeFile(const QString& filePath, const AnalysisConfig& config);
    
    // Detection methods
    QVector<CommentFinding> findInaccurateComments(const QString& code);
    QVector<CommentFinding> findOutdatedComments(const QString& code);
    QVector<CommentFinding> findMisleadingComments(const QString& code);
    QVector<CommentFinding> findRedundantComments(const QString& code);
    QVector<CommentFinding> findIncompleteComments(const QString& code);
    QVector<CommentFinding> findMissingEdgeCases(const QString& code);
    QVector<CommentFinding> findBrokenReferences(const QString& code);
    
    // Helper methods
    bool commentMatchesCode(const QString& comment, const QString& code);
    bool isRedundantComment(const QString& comment, const QString& code);
    bool hasBrokenReference(const QString& comment, const QString& code);
    QStringList extractReferencesFromComment(const QString& comment);
    
    // Results
    CommentAnalysis getAnalysisResult(const QString& filePath);
    QJsonObject getStatistics() const;
    
    // Report generation
    QString generateQualityReport(const CommentAnalysis& analysis);
    QString generateCriticalIssuesReport(const CommentAnalysis& analysis);
    QString generateImprovementSuggestions(const CommentAnalysis& analysis);

signals:
    void analysisStarted(const QString& filePath);
    void analysisCompleted(const QString& filePath);
    void issueFound(const CommentFinding& finding);
    void errorOccurred(const QString& error);

private:
    QMap<QString, CommentAnalysis> m_results;
    int m_totalAnalyzed = 0;
    int m_totalIssuesFound = 0;
};
