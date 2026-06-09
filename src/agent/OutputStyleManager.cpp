#include "OutputStyleManager.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QRegularExpression>
#include <QDateTime>

OutputStyleManager::OutputStyleManager(QObject* parent)
    : QObject(parent), m_defaultStyle(Detailed), m_enrichmentLevel(Standard) {
    // Initialize default styles
    OutputStyle_Config concise;
    concise.style = Concise;
    concise.name = "Concise";
    concise.description = "Short, focused output";
    concise.enrichment = Minimal;
    concise.verbosityLevel = 0.2f;
    concise.includeExplanations = false;
    concise.includeCodeExamples = false;
    concise.includeWarnings = true;
    concise.enabled = true;
    m_styles[Concise] = concise;

    OutputStyle_Config detailed;
    detailed.style = Detailed;
    detailed.name = "Detailed";
    detailed.description = "Comprehensive explanations";
    detailed.enrichment = Enhanced;
    detailed.verbosityLevel = 0.7f;
    detailed.includeExplanations = true;
    detailed.includeCodeExamples = true;
    detailed.includeWarnings = true;
    detailed.includeTips = true;
    detailed.enabled = true;
    m_styles[Detailed] = detailed;

    OutputStyle_Config explanatory;
    explanatory.style = Explanatory;
    explanatory.name = "Explanatory";
    explanatory.description = "Educational with insights";
    explanatory.enrichment = Maximum;
    explanatory.verbosityLevel = 0.8f;
    explanatory.includeExplanations = true;
    explanatory.includeCodeExamples = true;
    explanatory.includeWarnings = true;
    explanatory.includeTips = true;
    explanatory.enabled = true;
    m_styles[Explanatory] = explanatory;

    OutputStyle_Config learning;
    learning.style = Learning;
    learning.name = "Learning";
    learning.description = "Interactive with code contributions";
    learning.enrichment = Maximum;
    learning.verbosityLevel = 0.9f;
    learning.includeExplanations = true;
    learning.includeCodeExamples = true;
    learning.requestUserContribution = true;
    learning.enabled = true;
    m_styles[Learning] = learning;

    m_statistics = {0, {}, 0.0f, 0, 0, 0};
}

OutputStyleManager::~OutputStyleManager() {
    m_styles.clear();
}

void OutputStyleManager::registerOutputStyle(const OutputStyle_Config& config) {
    if (!validateStyleConfig(config)) {
        qWarning("Invalid output style configuration");
        return;
    }
    m_styles[config.style] = config;
    emit styleRegistered(config.style);
}

void OutputStyleManager::unregisterOutputStyle(OutputStyle style) {
    m_styles.remove(style);
}

OutputStyleManager::OutputStyle_Config OutputStyleManager::getOutputStyle(OutputStyle style) {
    return m_styles.value(style, OutputStyle_Config{style, "", "", Minimal, false, false, false, false, false, 0.0f, {}, {}, false});
}

QVector<OutputStyleManager::OutputStyle_Config> OutputStyleManager::getAllStyles() {
    return QVector<OutputStyle_Config>(m_styles.values().begin(), m_styles.values().end());
}

void OutputStyleManager::setDefaultStyle(OutputStyle style) {
    if (m_styles.contains(style)) {
        m_defaultStyle = style;
    }
}

OutputStyleManager::OutputStyle OutputStyleManager::getDefaultStyle() const {
    return m_defaultStyle;
}

OutputStyleManager::OutputStyle OutputStyleManager::selectStyleForContext(const QJsonObject& context) {
    QString taskType = context.value("taskType").toString();
    QString language = context.value("language").toString();
    bool isEducational = context.value("educational").toBool(false);
    bool isInteractive = context.value("interactive").toBool(false);

    if (isEducational && isInteractive) return Learning;
    if (isEducational) return Explanatory;
    if (isInteractive) return Detailed;
    
    return m_defaultStyle;
}

OutputStyleManager::OutputStyle OutputStyleManager::selectStyleForLanguage(const QString& language) {
    // For documentation-heavy languages, prefer detailed
    if (language == "markdown" || language == "rst" || language == "asciidoc") {
        return Detailed;
    }
    return m_defaultStyle;
}

OutputStyleManager::OutputStyle OutputStyleManager::selectStyleForTaskType(const QString& taskType) {
    if (taskType == "learning" || taskType == "tutorial") {
        return Learning;
    }
    if (taskType == "documentation") {
        return Explanatory;
    }
    if (taskType == "refactor" || taskType == "optimize") {
        return Concise;
    }
    return m_defaultStyle;
}

OutputStyleManager::EnrichedOutput OutputStyleManager::formatOutput(const QString& output, OutputStyle style) {
    return formatOutput(output, style, m_enrichmentLevel);
}

OutputStyleManager::EnrichedOutput OutputStyleManager::formatOutput(const QString& output, OutputStyle style, EnrichmentLevel enrichment) {
    EnrichedOutput result;
    result.originalOutput = output;
    result.style = style;
    result.enrichmentScore = 0.0f;

    auto styleConfig = m_styles.value(style);
    
    // Apply formatting based on style
    switch (style) {
        case Explanatory:
            result.enrichedOutput = generateEnrichedExplanation(output, m_currentContext);
            break;
        case Learning:
            result.enrichedOutput = formatAsLearning(output);
            break;
        case Detailed:
            result.enrichedOutput = enrichWithExplanations(output, m_currentContext);
            break;
        case Concise:
            result.enrichedOutput = output;
            break;
        default:
            result.enrichedOutput = output;
    }

    // Apply enrichment
    if (enrichment >= Enhanced) {
        if (styleConfig.includeWarnings) {
            result.addedWarnings = QStringList{"⚠️ Consider edge cases"};
        }
        if (styleConfig.includeTips) {
            result.addedTips = QStringList{"💡 Tip: Follow the code organization pattern"};
        }
    }

    if (enrichment == Maximum && styleConfig.requestUserContribution) {
        result.suggestedContribution = generateCodeContributionSuggestion(output);
    }

    result.enrichmentScore = static_cast<float>(enrichment) / static_cast<float>(Maximum);
    
    m_statistics.totalOutputsFormatted++;
    m_statistics.outputsByStyle[style]++;
    m_statistics.totalInsightsAdded += result.addedInsights.size();
    m_statistics.totalWarningsAdded += result.addedWarnings.size();
    m_statistics.totalTipsAdded += result.addedTips.size();

    emit outputEnriched(result.originalOutput, result.enrichedOutput);
    return result;
}

QString OutputStyleManager::enrichWithExplanations(const QString& output, const QJsonObject& context) {
    QString enriched = output;
    
    // Add explanation markers
    if (context.contains("conceptKey")) {
        QString concept = context.value("conceptKey").toString();
        enriched.prepend(QString("**Understanding %1:**\n").arg(concept));
    }
    
    return enriched;
}

QString OutputStyleManager::enrichWithExamples(const QString& output, const QString& language) {
    QString enriched = output + "\n\n**Example:**\n```" + language + "\n// Add relevant example\n```";
    return enriched;
}

QString OutputStyleManager::enrichWithWarnings(const QString& output) {
    return output + "\n\n⚠️ **Important Considerations:** Review error handling and edge cases.";
}

QString OutputStyleManager::enrichWithTips(const QString& output) {
    return output + "\n\n💡 **Best Practice Tip:** Follow consistent naming and organization patterns.";
}

QString OutputStyleManager::generateEducationalContext(const QString& code, const QString& language) {
    return QString("Learning Objective for %1:\n%2").arg(language, code.left(100));
}

QString OutputStyleManager::generateLearningPrompt(const QString& topic) {
    return QString("Let's learn about %1 step by step...").arg(topic);
}

QString OutputStyleManager::generateCodeContributionSuggestion(const QString& context) {
    return "Consider writing 5-10 lines of code to implement this concept.";
}

QStringList OutputStyleManager::suggestImprovements(const QString& code) {
    QStringList improvements;
    
    if (!code.contains("const")) improvements << "Consider using const for immutability";
    if (!code.contains("try") && !code.contains("catch")) improvements << "Add error handling";
    if (code.length() < 100) improvements << "Consider adding documentation";
    
    return improvements;
}

QJsonArray OutputStyleManager::generateLearningPath(const QString& topic) {
    QJsonArray path;
    path.append(QJsonObject{{"step", 1}, {"title", "Introduction"}, {"topic", topic}});
    path.append(QJsonObject{{"step", 2}, {"title", "Basic Concepts"}});
    path.append(QJsonObject{{"step", 3}, {"title", "Advanced Topics"}});
    path.append(QJsonObject{{"step", 4}, {"title", "Practical Application"}});
    return path;
}

QString OutputStyleManager::injectContextualInsights(const QString& output, const QJsonObject& context) {
    QString enriched = output;
    
    if (context.contains("currentFile")) {
        enriched.prepend("**File Context:** " + context.value("currentFile").toString() + "\n\n");
    }
    
    return enriched;
}

QString OutputStyleManager::injectArchitectureInsights(const QString& output, const QString& filepath) {
    return output + "\n\n**Architecture Note:** This aligns with the current codebase structure.";
}

QString OutputStyleManager::injectPatternInsights(const QString& output) {
    return output + "\n\n**Design Pattern:** This uses established patterns from the codebase.";
}

QString OutputStyleManager::injectBestPractices(const QString& output) {
    return output + "\n\n**Best Practice:** Follow the guidelines established in the codebase.";
}

void OutputStyleManager::createCustomStyle(const QString& styleName, const OutputStyle_Config& config) {
    if (validateStyleConfig(config)) {
        m_styles[Custom] = config;
    }
}

void OutputStyleManager::modifyStyle(OutputStyle style, const OutputStyle_Config& newConfig) {
    if (m_styles.contains(style) && validateStyleConfig(newConfig)) {
        m_styles[style] = newConfig;
    }
}

bool OutputStyleManager::validateStyleConfig(const OutputStyle_Config& config) {
    return !config.name.isEmpty() && config.verbosityLevel >= 0.0f && config.verbosityLevel <= 1.0f;
}

QJsonObject OutputStyleManager::exportStyle(OutputStyle style) {
    auto config = m_styles.value(style);
    return QJsonObject{
        {"name", config.name},
        {"description", config.description},
        {"enrichment", static_cast<int>(config.enrichment)},
        {"verbosityLevel", config.verbosityLevel}
    };
}

bool OutputStyleManager::importStyle(const QJsonObject& styleJson) {
    OutputStyle_Config config;
    config.name = styleJson.value("name").toString();
    config.description = styleJson.value("description").toString();
    config.verbosityLevel = styleJson.value("verbosityLevel").toDouble(0.5);
    
    if (validateStyleConfig(config)) {
        m_styles[Custom] = config;
        return true;
    }
    return false;
}

void OutputStyleManager::setEnrichmentLevel(EnrichmentLevel level) {
    m_enrichmentLevel = level;
    emit enrichmentLevelChanged(level);
}

void OutputStyleManager::enableExplanations(bool enabled) {
    for (auto& style : m_styles) {
        style.includeExplanations = enabled;
    }
}

void OutputStyleManager::enableExamples(bool enabled) {
    for (auto& style : m_styles) {
        style.includeCodeExamples = enabled;
    }
}

void OutputStyleManager::enableWarnings(bool enabled) {
    for (auto& style : m_styles) {
        style.includeWarnings = enabled;
    }
}

void OutputStyleManager::enableTips(bool enabled) {
    for (auto& style : m_styles) {
        style.includeTips = enabled;
    }
}

void OutputStyleManager::enableEducationalInsights(bool enabled) {
    for (auto& style : m_styles) {
        style.includeExplanations = enabled;
    }
}

void OutputStyleManager::enableCodeContributionRequests(bool enabled) {
    for (auto& style : m_styles) {
        style.requestUserContribution = enabled;
    }
}

OutputStyleManager::StyleStats OutputStyleManager::getStatistics() const {
    return m_statistics;
}

void OutputStyleManager::updateContextInformation(const QJsonObject& context) {
    m_currentContext = context;
}

QJsonObject OutputStyleManager::getCurrentContext() const {
    return m_currentContext;
}

void OutputStyleManager::clearContext() {
    m_currentContext = QJsonObject();
}

QString OutputStyleManager::generateEnrichedExplanation(const QString& output, const QJsonObject& context) {
    QString enriched = "**Implementation Overview:**\n\n" + output + "\n\n";
    enriched += "**Key Considerations:**\n";
    enriched += "- Design rationale and architectural choices\n";
    enriched += "- Integration points with the system\n";
    enriched += "- Performance and scalability factors\n";
    return enriched;
}

QString OutputStyleManager::formatAsEducational(const QString& output) {
    return "**Learning Context:**\n\n" + output + "\n\n**Practice:** Try implementing a variation of this pattern.";
}

QString OutputStyleManager::formatAsLearning(const QString& output) {
    return "**Interactive Learning:**\n\n" + output + "\n\n**Challenge:** Can you extend this implementation with additional features?";
}

QString OutputStyleManager::applyCustomRules(const QString& output, const QJsonObject& rules) {
    QString result = output;
    
    for (const auto& key : rules.keys()) {
        QString pattern = rules.value(key).toString();
        if (!pattern.isEmpty()) {
            result.append("\n[Rule: " + key + "]");
        }
    }
    
    return result;
}
