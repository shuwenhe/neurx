#pragma once

#include <QObject>
#include <QString>
#include <QMap>
#include <QVector>
#include <QJsonObject>
#include <QSet>
#include <QDateTime>

/**
 * @class TestCoverageAnalyzer
 * @brief Analyzes test coverage and identifies gaps
 * 
 * Based on pr-review-toolkit's pr-test-analyzer. Analyzes behavioral coverage,
 * identifies critical gaps, and recommends edge cases to test.
 */
class TestCoverageAnalyzer : public QObject {
    Q_OBJECT

public:
    explicit TestCoverageAnalyzer(QObject* parent = nullptr);
    ~TestCoverageAnalyzer();

    // Test coverage metrics
    struct CoverageMetrics {
        float lineCoverage;         // 0.0-1.0
        float branchCoverage;       // 0.0-1.0
        float functionCoverage;     // 0.0-1.0
        float conditionalCoverage;  // 0.0-1.0
        int totalLines;
        int coveredLines;
        int uncoveredLines;
        int totalBranches;
        int coveredBranches;
        QDateTime measuredAt;
    };

    // Test case metadata
    struct TestCase {
        QString name;
        QString description;
        QVector<QString> coveredFunctions;
        QVector<QString> testedBranches;
        bool isE2E;
        bool isIntegration;
        bool isUnit;
        float executionTime;  // milliseconds
        bool passed;
    };

    // Coverage gap
    struct CoverageGap {
        QString functionName;
        QString filePath;
        int lineNumber;
        float importance;  // 0.0-1.0
        QString reason;
        QVector<QString> suggestedTests;
        bool isCritical;
    };

    // Analysis result
    struct CoverageAnalysis {
        QString projectPath;
        CoverageMetrics metrics;
        int totalTests;
        int passingTests;
        int failingTests;
        QVector<CoverageGap> gaps;
        QVector<TestCase> untestableCode;
        float overallScore;  // 0.0-100.0
        QString recommendation;
        QDateTime analyzedAt;
    };

    // Analysis configuration
    struct AnalysisConfig {
        float minAcceptableCoverage = 0.80f;  // 80%
        bool includeBranchCoverage = true;
        bool analyzeEdgeCases = true;
        bool checkForFlakiness = true;
        int minTestsPerFunction = 1;
        bool detectDeadCode = true;
        QString testFramework;  // "jest", "pytest", "gtest", etc.
    };

    // Start analysis
    void analyzeCoverage(const QString& projectPath, const AnalysisConfig& config);
    void analyzeTestFile(const QString& filePath, const AnalysisConfig& config);
    void analyzeSourceFile(const QString& filePath, const AnalysisConfig& config);
    
    // Coverage metrics
    CoverageMetrics calculateMetrics(const QString& coverageData);
    float calculateLineCount(const QString& code);
    float calculateBranchCount(const QString& code);
    
    // Gap detection
    QVector<CoverageGap> detectCoverageGaps(const QString& code, const CoverageMetrics& metrics);
    QVector<CoverageGap> identifyUncoveredBranches(const QString& code);
    QVector<CoverageGap> identifyUntestableCode(const QString& code);
    
    // Edge case analysis
    QVector<QString> suggestEdgeCases(const QString& functionSignature);
    QVector<QString> suggestBoundaryTests(const QString& parameterType);
    bool hasEdgeCaseTests(const TestCase& test);
    
    // Test quality assessment
    float assessTestQuality(const QVector<TestCase>& tests);
    bool detectFlakiness(const QString& testName);
    bool isTestIndependent(const TestCase& test);
    
    // Gap prioritization
    void prioritizeGaps(QVector<CoverageGap>& gaps);
    float calculateGapImportance(const CoverageGap& gap);
    
    // Recommendations
    QString generateRecommendations(const CoverageAnalysis& analysis);
    QString suggestNextTests(const QVector<CoverageGap>& gaps, int count = 5);
    
    // Results management
    CoverageAnalysis getAnalysisResult(const QString& projectPath);
    QJsonObject getAnalysisStatistics() const;
    
    // Report generation
    QString generateCoverageReport(const CoverageAnalysis& analysis);
    QString generateGapReport(const CoverageAnalysis& analysis);
    
    // Comparison
    struct CoverageComparison {
        float coverageDelta;        // Improvement/degradation
        int newGaps;
        int resolvedGaps;
        QString trend;              // "improving", "declining", "stable"
    };
    CoverageComparison compareCoverage(const CoverageAnalysis& previous, const CoverageAnalysis& current);

signals:
    void analysisStarted(const QString& projectPath);
    void analysisCompleted(const QString& projectPath);
    void fileAnalyzed(const QString& filePath, float coverage);
    void gapDetected(const CoverageGap& gap);
    void edgeCaseRecommended(const QString& testCase);
    void analysisProgress(int current, int total);
    void errorOccurred(const QString& error);

private:
    // Configuration
    AnalysisConfig m_config;
    
    // Results cache
    QMap<QString, CoverageAnalysis> m_analysisResults;
    QMap<QString, CoverageMetrics> m_metricsCache;
    
    // Statistics
    int m_totalFilesAnalyzed = 0;
    float m_totalCoverageAccumulated = 0.0f;
    int m_totalGapsDetected = 0;
    
    // Edge case patterns
    static const QVector<QString> BOUNDARY_PATTERNS;
    static const QVector<QString> EDGE_CASE_KEYWORDS;
    static const QVector<QString> ERROR_CONDITIONS;

    // Helper methods
    void analyzeFileInternal(const QString& filePath);
    void computeMetrics(CoverageAnalysis& analysis);
    QString detectTestFramework(const QString& projectPath);
    float parseLineCoverage(const QString& coverageOutput);
    void identifyTestableUnits(const QString& code, CoverageAnalysis& analysis);
};
