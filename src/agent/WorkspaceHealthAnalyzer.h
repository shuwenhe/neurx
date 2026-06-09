#ifndef WORKSPACE_HEALTH_ANALYZER_H
#define WORKSPACE_HEALTH_ANALYZER_H

#include <QObject>
#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QMap>
#include <QSet>
#include <memory>

/**
 * WorkspaceHealthAnalyzer
 *
 * Analyzes and improves workspace health:
 * - Code quality metrics
 * - Test coverage analysis
 * - Documentation completeness
 * - Dependency analysis
 * - Performance profiling recommendations
 */
class WorkspaceHealthAnalyzer : public QObject {
    Q_OBJECT

public:
    enum HealthMetric {
        CodeQuality,
        TestCoverage,
        Documentation,
        Dependencies,
        Performance,
        Security,
        Maintainability
    };
    
    enum HealthScore {
        Critical,
        Poor,
        Fair,
        Good,
        Excellent
    };
    
    struct HealthReport {
        QMap<HealthMetric, int> scores;  // 0-100
        QMap<HealthMetric, QString> recommendations;
        int overallScore;
        HealthScore overallHealth;
        QStringList issues;
        QStringList improvements;
    };

    explicit WorkspaceHealthAnalyzer(QObject* parent = nullptr);
    ~WorkspaceHealthAnalyzer();

    // Analysis operations
    HealthReport analyzeWorkspace(const QString& workspacePath);
    HealthReport analyzeProject(const QString& projectPath);
    void analyzeCodeQuality(const QString& sourcePath);
    void analyzeTestCoverage(const QString& projectPath);
    void analyzeDocumentation(const QString& projectPath);
    void analyzeDependencies(const QString& projectPath);
    
    // Metrics
    int calculateCodeQualityScore(const QString& sourcePath);
    int calculateTestCoverageScore(const QString& projectPath);
    int calculateDocumentationScore(const QString& projectPath);
    int calculateMaintainabilityScore(const QString& sourcePath);
    
    // Issue detection
    QStringList detectCodeSmells(const QString& sourcePath);
    QStringList detectDocumentationGaps(const QString& projectPath);
    QStringList detectSecurityIssues(const QString& sourcePath);
    QStringList detectPerformanceIssues(const QString& sourcePath);
    
    // Recommendations
    QStringList generateRecommendations(const HealthReport& report);
    QString getDetailedRecommendation(HealthMetric metric, int score);
    
    // Reporting
    QString generateHealthReport(const HealthReport& report);
    QJsonObject exportHealthReport(const HealthReport& report);
    
    // Configuration
    void setQualityThresholds(const QMap<HealthMetric, int>& thresholds);
    void enableDetailedAnalysis(bool enabled);

signals:
    void analysisStarted(const QString& path);
    void metricAnalyzed(HealthMetric metric, int score);
    void issueDetected(const QString& issue, const QString& severity);
    void analysisFinished(const HealthReport& report);

private:
    struct CodeQualityMetrics {
        int cyclomaticComplexity;
        int linesPerFunction;
        int duplicateLines;
        int commentRatio;
        int warningCount;
    };
    
    struct TestMetrics {
        int totalTests;
        int passingTests;
        int failingTests;
        float coveragePercentage;
    };

    CodeQualityMetrics analyzeCodeMetrics(const QString& sourcePath);
    TestMetrics analyzeTests(const QString& projectPath);
    int countFiles(const QString& path, const QString& extension);
    int countLines(const QString& filePath);
    int detectCodeSmellsInFile(const QString& filePath);
    int calculateCyclomaticComplexity(const QString& code);
    
    QMap<HealthMetric, int> m_qualityThresholds;
    bool m_detailedAnalysis;
};

#endif // WORKSPACE_HEALTH_ANALYZER_H
