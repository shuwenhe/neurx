#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class OutputStyleManager
 * @brief Manages different output styles and presentation modes
 * 
 * Features:
 * - Multiple output styles (Explanatory, Learning, Concise, Detailed, etc.)
 * - Context-aware style selection
 * - Style-specific formatting rules
 * - Output enrichment and enhancement
 * - Educational content injection
 * - Code contribution suggestions
 * - Context preservation across styles
 */

class OutputStyleManager : public QObject {
    Q_OBJECT

public:
    enum OutputStyle {
        Concise,           // Short, focused output
        Detailed,          // Comprehensive explanations
        Explanatory,       // Educational with insights
        Learning,          // Interactive with code contributions
        CodeFirst,         // Code-focused minimal explanation
        Educational,       // Teaching-focused
        Interactive,       // User engagement focused
        Custom             // User-defined style
    };

    enum EnrichmentLevel {
        Minimal,    // No enrichment
        Standard,   // Basic enrichment
        Enhanced,   // Rich enrichment
        Maximum     // Full enrichment
    };

    struct OutputStyle_Config {
        OutputStyle style;
        QString name;
        QString description;
        EnrichmentLevel enrichment;
        bool includeExplanations;
        bool includeCodeExamples;
        bool includeWarnings;
        bool includeTips;
        bool requestUserContribution;
        float verbosityLevel;  // 0.0-1.0
        QStringList contextTags;
        QJsonObject customRules;
        bool enabled;
    };

    struct EnrichedOutput {
        QString originalOutput;
        QString enrichedOutput;
        OutputStyle style;
        QStringList addedInsights;
        QStringList addedWarnings;
        QStringList addedTips;
        QString suggestedContribution;
        float enrichmentScore;
        QJsonObject metadata;
    };

    explicit OutputStyleManager(QObject* parent = nullptr);
    ~OutputStyleManager();

    // Style management
    void registerOutputStyle(const OutputStyle_Config& config);
    void unregisterOutputStyle(OutputStyle style);
    OutputStyle_Config getOutputStyle(OutputStyle style);
    QVector<OutputStyle_Config> getAllStyles();
    void setDefaultStyle(OutputStyle style);
    OutputStyle getDefaultStyle() const;

    // Style selection
    OutputStyle selectStyleForContext(const QJsonObject& context);
    OutputStyle selectStyleForLanguage(const QString& language);
    OutputStyle selectStyleForTaskType(const QString& taskType);

    // Output formatting
    EnrichedOutput formatOutput(const QString& output, OutputStyle style);
    EnrichedOutput formatOutput(const QString& output, OutputStyle style, 
                               EnrichmentLevel enrichment);
    QString enrichWithExplanations(const QString& output, const QJsonObject& context);
    QString enrichWithExamples(const QString& output, const QString& language);
    QString enrichWithWarnings(const QString& output);
    QString enrichWithTips(const QString& output);

    // Educational features
    QString generateEducationalContext(const QString& code, const QString& language);
    QString generateLearningPrompt(const QString& topic);
    QString generateCodeContributionSuggestion(const QString& context);
    QStringList suggestImprovements(const QString& code);
    QJsonArray generateLearningPath(const QString& topic);

    // Context injection
    QString injectContextualInsights(const QString& output, const QJsonObject& context);
    QString injectArchitectureInsights(const QString& output, const QString& filepath);
    QString injectPatternInsights(const QString& output);
    QString injectBestPractices(const QString& output);

    // Style customization
    void createCustomStyle(const QString& styleName, const OutputStyle_Config& config);
    void modifyStyle(OutputStyle style, const OutputStyle_Config& newConfig);
    bool validateStyleConfig(const OutputStyle_Config& config);
    QJsonObject exportStyle(OutputStyle style);
    bool importStyle(const QJsonObject& styleJson);

    // Enrichment control
    void setEnrichmentLevel(EnrichmentLevel level);
    void enableExplanations(bool enabled);
    void enableExamples(bool enabled);
    void enableWarnings(bool enabled);
    void enableTips(bool enabled);
    void enableEducationalInsights(bool enabled);
    void enableCodeContributionRequests(bool enabled);

    // Statistics
    struct StyleStats {
        int totalOutputsFormatted;
        QMap<OutputStyle, int> outputsByStyle;
        float averageEnrichmentScore;
        int totalInsightsAdded;
        int totalWarningsAdded;
        int totalTipsAdded;
    };
    StyleStats getStatistics() const;

    // Context awareness
    void updateContextInformation(const QJsonObject& context);
    QJsonObject getCurrentContext() const;
    void clearContext();

signals:
    void styleRegistered(OutputStyle style);
    void styleApplied(OutputStyle style);
    void outputEnriched(const QString& originalOutput, const QString& enrichedOutput);
    void enrichmentLevelChanged(EnrichmentLevel level);

private:
    QMap<OutputStyle, OutputStyle_Config> m_styles;
    OutputStyle m_defaultStyle;
    EnrichmentLevel m_enrichmentLevel;
    QJsonObject m_currentContext;
    StyleStats m_statistics;

    QString generateEnrichedExplanation(const QString& output, const QJsonObject& context);
    QString formatAsEducational(const QString& output);
    QString formatAsLearning(const QString& output);
    QString applyCustomRules(const QString& output, const QJsonObject& rules);
};
