#pragma once

#include <QObject>
#include <QString>
#include <QMap>
#include <QVector>
#include <QJsonObject>

/**
 * @class CodeSimplificationSuggester
 * @brief Analyzes code for simplification opportunities
 * 
 * Based on pr-review-toolkit's code-simplifier. Identifies opportunities to
 * improve code clarity, consistency, and maintainability while preserving functionality.
 */
class CodeSimplificationSuggester : public QObject {
    Q_OBJECT

public:
    explicit CodeSimplificationSuggester(QObject* parent = nullptr);
    ~CodeSimplificationSuggester();

    // Simplification suggestion types
    enum SuggestionType {
        ReduceNesting,          // Reduce code nesting depth
        RemoveRedundancy,       // Remove redundant code
        ConsolidateLogic,       // Consolidate related logic
        ImproveNaming,          // Improve variable/function names
        SimplifyConditionals,   // Replace ternary chains with if/else or switch
        RemoveDeadCode,         // Remove unused code
        ExtractMethod,          // Extract complex logic into method
        ReduceComplexity,       // Reduce cyclomatic complexity
        ImproveReadability      // General readability improvements
    };

    // Simplification suggestion
    struct SimplificationSuggestion {
        int lineNumber;
        int endLineNumber;
        QString filePath;
        SuggestionType suggestionType;
        float impact;           // 0.0-1.0 (how much it improves code)
        float complexity;       // Current complexity level 0.0-1.0
        QString currentCode;
        QString suggestedCode;
        QString explanation;
        QString reasoning;      // Why this simplification is needed
        QStringList projectStandards;  // Relevant project standards
    };

    // Analysis result
    struct SimplificationAnalysis {
        QString filePath;
        int totalLines = 0;
        int complexLines = 0;
        float averageComplexity = 0.0f;
        QVector<SimplificationSuggestion> suggestions;
        float overallImprovementPotential = 0.0f;  // 0.0-1.0
        QString summary;
    };

    // Analysis config
    struct AnalysisConfig {
        bool checkNesting = true;
        bool checkRedundancy = true;
        bool checkConditionals = true;
        bool checkComplexity = true;
        bool checkNaming = true;
        float complexityThreshold = 0.70f;
    };

    // Analyze code
    void analyzeCode(const QString& code, const QString& filePath, const AnalysisConfig& config);
    void analyzeFile(const QString& filePath, const AnalysisConfig& config);
    
    // Detection methods
    QVector<SimplificationSuggestion> detectNestingIssues(const QString& code);
    QVector<SimplificationSuggestion> detectRedundantCode(const QString& code);
    QVector<SimplificationSuggestion> detectComplexConditionals(const QString& code);
    QVector<SimplificationSuggestion> detectLowQualityNames(const QString& code);
    QVector<SimplificationSuggestion> detectExtractableLogic(const QString& code);
    
    // Helper methods
    int calculateNestingDepth(const QString& line);
    float calculateComplexity(const QString& code);
    bool isRedundant(const QString& line1, const QString& line2);
    QString suggestImprovedName(const QString& currentName);
    
    // Results
    SimplificationAnalysis getAnalysisResult(const QString& filePath);
    QJsonObject getStatistics() const;
    
    // Report generation
    QString generateSuggestionReport(const SimplificationAnalysis& analysis);
    QString generatePriorityList(const QVector<SimplificationSuggestion>& suggestions, int count = 5);
    QString generateRefactoringGuide(const SimplificationAnalysis& analysis);

signals:
    void analysisStarted(const QString& filePath);
    void analysisCompleted(const QString& filePath);
    void suggestionFound(const SimplificationSuggestion& suggestion);
    void errorOccurred(const QString& error);

private:
    QMap<QString, SimplificationAnalysis> m_results;
    int m_totalAnalyzed = 0;
    float m_totalImprovementPotential = 0.0f;
    
    // Complexity calculation helpers
    float calculateCyclomaticComplexity(const QString& code);
    float calculateCognitiveComplexity(const QString& code);
};
