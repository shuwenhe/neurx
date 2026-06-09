#pragma once

#include <QObject>
#include <QString>
#include <QMap>
#include <QVector>
#include <QJsonObject>

/**
 * @class ErrorHandlingAnalyzer
 * @brief Detects silent failures and inadequate error handling
 * 
 * Based on pr-review-toolkit's silent-failure-hunter. Analyzes catch blocks
 * for proper error handling, logging, and propagation.
 */
class ErrorHandlingAnalyzer : public QObject {
    Q_OBJECT

public:
    explicit ErrorHandlingAnalyzer(QObject* parent = nullptr);
    ~ErrorHandlingAnalyzer();

    // Error handling issue types
    enum ErrorIssueType {
        SilentFailure,          // Empty catch block
        NoLogging,              // Exception caught but not logged
        NoRethrow,              // Exception should be re-thrown
        SwallowedException,     // Exception ignored
        IncompleteRecovery,     // Partial error handling
        NoFallback,             // No fallback behavior
        WrongExceptionType      // Catches wrong exception type
    };

    // Error handling finding
    struct ErrorHandlingFinding {
        int lineNumber;
        QString filePath;
        ErrorIssueType issueType;
        float severity;         // 0.0-1.0
        QString codeSnippet;
        QString message;
        QString suggestion;
        QString category;       // "try-catch", "error-return", "callback", etc.
    };

    // Analysis result
    struct ErrorAnalysisResult {
        QString filePath;
        int totalErrorBlocks = 0;
        int properlyHandled = 0;
        int silentFailures = 0;
        int missingLogs = 0;
        QVector<ErrorHandlingFinding> findings;
        float overallScore;     // 0.0-1.0
        QString recommendation;
    };

    // Analysis configuration
    struct AnalysisConfig {
        bool checkSilentFailures = true;
        bool checkLogging = true;
        bool checkRethrow = true;
        bool checkFallbacks = true;
        float minAcceptableScore = 0.70f;
    };

    // Analyze code
    void analyzeErrorHandling(const QString& code, const QString& filePath, const AnalysisConfig& config);
    void analyzeFile(const QString& filePath, const AnalysisConfig& config);
    
    // Detection methods
    QVector<ErrorHandlingFinding> findSilentFailures(const QString& code);
    QVector<ErrorHandlingFinding> findMissingLogs(const QString& code);
    QVector<ErrorHandlingFinding> findSwallowedExceptions(const QString& code);
    QVector<ErrorHandlingFinding> findIncompleteRecovery(const QString& code);
    QVector<ErrorHandlingFinding> findMissingFallbacks(const QString& code);
    
    // Helper methods
    bool isSilentCatch(const QString& catchBlock);
    bool hasLogging(const QString& catchBlock);
    bool hasRethrow(const QString& catchBlock);
    bool hasFallback(const QString& catchBlock);
    
    // Results
    ErrorAnalysisResult getAnalysisResult(const QString& filePath);
    QJsonObject getStatistics() const;
    
    // Recommendations
    QString generateRecommendations(const ErrorAnalysisResult& result);
    QString suggestImprovements(const ErrorHandlingFinding& finding);

signals:
    void analysisStarted(const QString& filePath);
    void analysisCompleted(const QString& filePath);
    void findingDetected(const ErrorHandlingFinding& finding);
    void errorOccurred(const QString& error);

private:
    QMap<QString, ErrorAnalysisResult> m_results;
    int m_totalAnalyzed = 0;
    int m_totalIssuesFound = 0;

    static const QVector<QString> LOG_FUNCTIONS;
};
