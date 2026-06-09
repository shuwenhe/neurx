#include "ExplanatoryOutputStyleManager.h"
#include <QJsonDocument>
#include <QJsonArray>

ExplanatoryOutputStyleManager::ExplanatoryOutputStyleManager(QObject* parent)
    : QObject(parent), m_verboseMode(false), m_maxInsightPoints(3)
{
    // Initialize insight patterns
    m_patterns["design_pattern"] = {
        "Design Pattern",
        "Architectural pattern used",
        {"Strategy", "Observer", "Factory", "Singleton", "Builder", "Adapter"}
    };
    
    m_patterns["optimization"] = {
        "Optimization",
        "Performance improvement technique",
        {"caching", "lazy loading", "batching", "memoization", "throttling"}
    };
    
    m_patterns["error_handling"] = {
        "Error Handling",
        "Error management approach",
        {"try-catch", "error boundary", "fallback", "recovery", "validation"}
    };
    
    m_patterns["abstraction"] = {
        "Code Abstraction",
        "Abstraction and encapsulation",
        {"interface", "abstract class", "dependency injection", "facade"}
    };
    
    m_insightTemplate = 
        "`★ Insight ─────────────────────────────────────`\n"
        "%CONTENT%\n"
        "`─────────────────────────────────────────────────`";
}

ExplanatoryOutputStyleManager::~ExplanatoryOutputStyleManager()
{
}

QString ExplanatoryOutputStyleManager::generateSessionStartContext()
{
    QString context = 
        "You are in 'explanatory' output style mode, where you should provide "
        "educational insights about the codebase as you help with the user's task.\n\n"
        "You should be clear and educational, providing helpful explanations while "
        "remaining focused on the task. Balance educational content with task completion. "
        "When providing insights, you may exceed typical length constraints, but remain "
        "focused and relevant.\n\n"
        "## Key Guidelines\n"
        "1. Provide 2-3 educational points about implementation choices\n"
        "2. Focus on codebase-specific patterns rather than general programming\n"
        "3. Include insights before and after writing significant code\n"
        "4. Use the insight box format for clarity\n"
        "5. Balance learning with task completion\n\n"
        "## Insight Format\n"
        "When providing insights, format them as:\n"
        "`★ Insight ─────────────────────────────────────`\n"
        "[2-3 key educational points]\n"
        "`─────────────────────────────────────────────────`\n\n"
        "Remember: Insights are conversational, not in the codebase itself.";
    
    return context;
}

QString ExplanatoryOutputStyleManager::generateInsightBox(const QStringList& insights)
{
    if (insights.isEmpty()) {
        return QString();
    }
    
    QString formatted = "`★ Insight ─────────────────────────────────────`\n";
    for (const QString& insight : insights) {
        formatted += "• " + insight + "\n";
    }
    formatted += "`─────────────────────────────────────────────────`";
    
    return formatted;
}

QString ExplanatoryOutputStyleManager::generateImplementationExplanation(
    const QString& codeSnippet,
    const QString& fileContext,
    const QString& patternType)
{
    QStringList insights;
    
    // Analyze code for patterns
    QStringList patterns = analyzePattern(codeSnippet);
    
    // Generate insights based on pattern type
    if (patternType == "architecture") {
        insights << "This implementation follows a clear separation of concerns";
        insights << "The modular design allows for easy testing and reusability";
        insights << "Error handling is properly integrated throughout";
    } else if (patternType == "performance") {
        insights << "This approach optimizes for common use cases";
        insights << "Caching strategy reduces redundant computations";
        insights << "Lazy loading pattern improves startup performance";
    } else if (patternType == "maintainability") {
        insights << "Clear naming conventions improve code readability";
        insights << "Comments explain the 'why' behind complex logic";
        insights << "Consistent structure enables easier future modifications";
    } else {
        // Generic insights
        for (const QString& pattern : patterns) {
            insights << pattern;
        }
    }
    
    return generateInsightBox(insights);
}

void ExplanatoryOutputStyleManager::enableVerboseMode(bool enabled)
{
    m_verboseMode = enabled;
}

void ExplanatoryOutputStyleManager::setMaxInsightPoints(int count)
{
    m_maxInsightPoints = qMax(1, qMin(count, 5));
}

void ExplanatoryOutputStyleManager::setInsightTemplate(const QString& template_)
{
    m_insightTemplate = template_;
}

QJsonObject ExplanatoryOutputStyleManager::getHookContext()
{
    QJsonObject hook;
    hook["hookSpecificOutput"] = QJsonObject({
        {"hookEventName", "SessionStart"},
        {"additionalContext", generateSessionStartContext()}
    });
    return hook;
}

QString ExplanatoryOutputStyleManager::formatEducationalContent(const QString& content)
{
    if (content.isEmpty()) {
        return QString();
    }
    
    // Parse content and inject educational markers
    QString formatted = content;
    
    // Wrap key sections with insight markers
    if (!formatted.contains("★ Insight")) {
        // Auto-wrap in insight box if not already formatted
        formatted = generateInsightBox({content});
    }
    
    return formatted;
}

QString ExplanatoryOutputStyleManager::generateEducationalInsights(
    const QString& code,
    const QString& context)
{
    QStringList insights;
    
    // Analyze code patterns
    QStringList patterns = analyzePattern(code);
    
    int count = 0;
    for (const QString& pattern : patterns) {
        if (count >= m_maxInsightPoints) break;
        insights << pattern;
        count++;
    }
    
    return generateInsightBox(insights);
}

QStringList ExplanatoryOutputStyleManager::analyzePattern(const QString& code)
{
    QStringList detectedPatterns;
    
    // Check for design patterns
    if (code.contains("interface ") || code.contains("virtual ")) {
        detectedPatterns << "Uses interface-based design for loose coupling";
    }
    
    if (code.contains("class ") && code.contains("public:")) {
        detectedPatterns << "Well-defined public API with clear responsibilities";
    }
    
    // Check for error handling
    if (code.contains("try ") || code.contains("catch ")) {
        detectedPatterns << "Comprehensive error handling with try-catch blocks";
    }
    
    if (code.contains("throw ") || code.contains("exception")) {
        detectedPatterns << "Throws exceptions for exceptional conditions";
    }
    
    // Check for optimization patterns
    if (code.contains("cache ") || code.contains("memoiz")) {
        detectedPatterns << "Implements caching to avoid redundant computation";
    }
    
    if (code.contains("lazy ") || code.contains("defer")) {
        detectedPatterns << "Uses lazy evaluation for performance optimization";
    }
    
    // Check for code organization
    if (code.contains("private:") && code.contains("public:")) {
        detectedPatterns << "Proper encapsulation with public/private separation";
    }
    
    if (code.contains("const ") || code.contains("readonly")) {
        detectedPatterns << "Uses const correctness to prevent accidental mutations";
    }
    
    // Default insight if no patterns found
    if (detectedPatterns.isEmpty()) {
        detectedPatterns << "Clear and focused implementation";
        detectedPatterns << "Follows established coding conventions";
        detectedPatterns << "Good separation of concerns";
    }
    
    return detectedPatterns;
}

QString ExplanatoryOutputStyleManager::formatInsight(
    const QString& title,
    const QStringList& points)
{
    QString formatted = "`★ Insight ─────────────────────────────────────`\n";
    formatted += "**" + title + "**\n";
    
    for (const QString& point : points) {
        formatted += "• " + point + "\n";
    }
    
    formatted += "`─────────────────────────────────────────────────`";
    return formatted;
}
