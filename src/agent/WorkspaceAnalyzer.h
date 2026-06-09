#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <memory>
#include <map>

/**
 * @class WorkspaceAnalyzer
 * @brief Analyzes codebase structure, patterns, and architecture
 * 
 * Features:
 * - Codebase structure analysis
 * - Architecture pattern detection
 * - Code quality metrics
 * - Dependency analysis
 * - Performance analysis
 * - Documentation coverage tracking
 * - Refactoring suggestions
 */

class WorkspaceAnalyzer : public QObject {
    Q_OBJECT

public:
    struct CodeMetrics {
        int totalFiles;
        int totalLines;
        float averageFileSize;
        int cyclomaticComplexity;
        float codeToCommentRatio;
        int numberOfMethods;
        int numberOfClasses;
    };

    struct ArchitecturePattern {
        QString pattern;
        QString description;
        float confidence;
        QStringList files;
        QJsonObject metadata;
    };

    struct DependencyAnalysis {
        QStringList directDependencies;
        QStringList transitiveDependencies;
        int circulardependencyCount;
        float dependencyScore;
        QMap<QString, int> dependencyFrequency;
    };

    struct CodeQualityReport {
        float overallScore;
        int issues;
        int warnings;
        int suggestions;
        QStringList violatedRules;
        QJsonObject categoryScores;
    };

    explicit WorkspaceAnalyzer(QObject* parent = nullptr);
    ~WorkspaceAnalyzer();

    // Workspace analysis
    void analyzeWorkspace(const QString& rootPath);
    CodeMetrics getCodeMetrics();
    QVector<ArchitecturePattern> detectArchitecturePatterns();
    DependencyAnalysis analyzeDependencies();
    CodeQualityReport generateQualityReport();

    // File and structure analysis
    QStringList findFilesByPattern(const QString& pattern);
    QStringList getFilesInDirectory(const QString& dirPath);
    int getFileComplexity(const QString& filepath);
    QStringList getFileImports(const QString& filepath);
    QStringList getFileDependents(const QString& filepath);

    // Code pattern detection
    QStringList detectDesignPatterns(const QString& filepath);
    QStringList detectAntiPatterns(const QString& filepath);
    QVector<ArchitecturePattern> suggestArchitectureImprovements();

    // Performance analysis
    struct PerformanceAnalysis {
        QStringList slowMethods;
        QStringList largeClasses;
        QStringList deepInheritanceTrees;
        QStringList inefficientAlgorithms;
        float overallPerformanceScore;
    };
    PerformanceAnalysis analyzePerformance();

    // Documentation analysis
    struct DocumentationMetrics {
        int documentedClasses;
        int documentedMethods;
        float documentationCoverage;
        QStringList missingDocumentation;
    };
    DocumentationMetrics analyzeDokumentation();

    // Refactoring suggestions
    struct RefactoringSuggestion {
        QString target;
        QString suggestion;
        QString reason;
        float confidence;
        int estimatedEffortMinutes;
    };
    QVector<RefactoringSuggestion> suggestRefactorings();

    // Architecture insights
    QString getArchitectureInsights();
    QJsonObject getLayerAnalysis();
    QStringList identifyModules();
    QString suggestModuleReorganization();

    // Code exploration
    struct CodeExplorationResult {
        QString filepath;
        int lineNumber;
        QString snippet;
        QString context;
    };
    QVector<CodeExplorationResult> exploreCodebase(const QString& searchTerm);

    // Statistics and reporting
    struct WorkspaceStats {
        int totalFiles;
        int codeFiles;
        int testFiles;
        int documentationFiles;
        float averageFileSize;
        float documentationCoverage;
    };
    WorkspaceStats getStatistics() const;

    // Export and visualization
    QJsonObject exportAnalysisAsJson();
    QString exportAnalysisAsMarkdown();
    QJsonArray generateDependencyGraph();
    QJsonArray generateArchitectureVisualization();

    // Caching and updates
    void cacheAnalysisResults();
    void clearCache();
    bool isCacheValid();
    void updateAnalysis();

    // Change detection
    void trackFileChanges();
    QStringList getChangedFiles();
    QString getChangesSummary();

signals:
    void analysisStarted();
    void analysisProgress(int percentComplete);
    void analysisCompleted();
    void patternDetected(const ArchitecturePattern& pattern);

private:
    QString m_rootPath;
    CodeMetrics m_metrics;
    QVector<ArchitecturePattern> m_patterns;
    WorkspaceStats m_statistics;
    bool m_cacheValid;

    void calculateCodeMetrics();
    void detectPatterns();
};
