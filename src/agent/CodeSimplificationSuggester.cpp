#include "CodeSimplificationSuggester.h"
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <cmath>
#include <algorithm>

CodeSimplificationSuggester::CodeSimplificationSuggester(QObject* parent)
    : QObject(parent)
{
}

CodeSimplificationSuggester::~CodeSimplificationSuggester()
{
}

void CodeSimplificationSuggester::analyzeCode(const QString& code, const QString& filePath, const AnalysisConfig& config)
{
    qInfo() << QString("[Simplification] Analyzing: %1").arg(filePath);
    emit analysisStarted(filePath);

    SimplificationAnalysis analysis;
    analysis.filePath = filePath;
    analysis.totalLines = code.split('\n').size();
    
    if (config.checkNesting) {
        analysis.suggestions.append(detectNestingIssues(code));
    }
    if (config.checkRedundancy) {
        analysis.suggestions.append(detectRedundantCode(code));
    }
    if (config.checkConditionals) {
        analysis.suggestions.append(detectComplexConditionals(code));
    }
    if (config.checkComplexity) {
        analysis.suggestions.append(detectExtractableLogic(code));
    }
    if (config.checkNaming) {
        analysis.suggestions.append(detectLowQualityNames(code));
    }

    analysis.averageComplexity = calculateComplexity(code);
    analysis.complexLines = static_cast<int>(analysis.totalLines * analysis.averageComplexity);
    
    if (!analysis.suggestions.isEmpty()) {
        analysis.overallImprovementPotential = 
            std::accumulate(analysis.suggestions.begin(), analysis.suggestions.end(), 0.0f,
                [](float acc, const SimplificationSuggestion& s) { return acc + s.impact; }) / analysis.suggestions.size();
    }

    analysis.summary = generateSuggestionReport(analysis);
    m_results[filePath] = analysis;
    m_totalAnalyzed++;
    m_totalImprovementPotential += analysis.overallImprovementPotential;

    for (const SimplificationSuggestion& s : analysis.suggestions) {
        emit suggestionFound(s);
    }

    emit analysisCompleted(filePath);
}

void CodeSimplificationSuggester::analyzeFile(const QString& filePath, const AnalysisConfig& config)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit errorOccurred(QString("Cannot open file: %1").arg(filePath));
        return;
    }

    QTextStream in(&file);
    QString code = in.readAll();
    file.close();

    analyzeCode(code, filePath, config);
}

QVector<CodeSimplificationSuggester::SimplificationSuggestion> CodeSimplificationSuggester::detectNestingIssues(const QString& code)
{
    QVector<SimplificationSuggestion> suggestions;
    QStringList lines = code.split('\n');
    
    for (int i = 0; i < lines.size(); ++i) {
        int depth = calculateNestingDepth(lines[i]);
        if (depth > 3) {
            SimplificationSuggestion sugg;
            sugg.lineNumber = i + 1;
            sugg.suggestionType = ReduceNesting;
            sugg.complexity = depth / 5.0f;
            sugg.impact = 0.8f;
            sugg.currentCode = lines[i];
            sugg.explanation = QString("Nesting depth of %1 exceeds recommended level of 3").arg(depth);
            sugg.reasoning = "Deep nesting reduces code readability and maintainability. Consider extracting nested logic into separate functions.";
            suggestions.append(sugg);
        }
    }

    return suggestions;
}

QVector<CodeSimplificationSuggester::SimplificationSuggestion> CodeSimplificationSuggester::detectRedundantCode(const QString& code)
{
    QVector<SimplificationSuggestion> suggestions;
    QStringList lines = code.split('\n');

    // Detect similar consecutive lines
    for (int i = 0; i < lines.size() - 1; ++i) {
        if (isRedundant(lines[i], lines[i+1])) {
            SimplificationSuggestion sugg;
            sugg.lineNumber = i + 1;
            sugg.endLineNumber = i + 2;
            sugg.suggestionType = RemoveRedundancy;
            sugg.complexity = 0.5f;
            sugg.impact = 0.7f;
            sugg.currentCode = lines[i] + "\n" + lines[i+1];
            sugg.explanation = "Redundant code detected - these lines are identical or nearly identical";
            sugg.reasoning = "Remove or consolidate redundant code to reduce maintenance burden.";
            suggestions.append(sugg);
        }
    }

    return suggestions;
}

QVector<CodeSimplificationSuggester::SimplificationSuggestion> CodeSimplificationSuggester::detectComplexConditionals(const QString& code)
{
    QVector<SimplificationSuggestion> suggestions;

    // Detect nested ternary operators
    if (code.contains("?") && code.count("?") > 2) {
        SimplificationSuggestion sugg;
        sugg.suggestionType = SimplifyConditionals;
        sugg.complexity = 0.85f;
        sugg.impact = 0.75f;
        sugg.explanation = "Complex ternary operator chain detected";
        sugg.reasoning = "Replace nested ternary operators with if/else chain or switch statement for better readability.";
        sugg.currentCode = code.left(100);
        suggestions.append(sugg);
    }

    // Detect long if conditions
    if (code.contains("if") && code.contains("&&") && code.count("&&") > 2) {
        SimplificationSuggestion sugg;
        sugg.suggestionType = SimplifyConditionals;
        sugg.complexity = 0.70f;
        sugg.impact = 0.6f;
        sugg.explanation = "Complex conditional with multiple AND operators";
        sugg.reasoning = "Consider extracting complex conditions into named helper functions.";
        suggestions.append(sugg);
    }

    return suggestions;
}

QVector<CodeSimplificationSuggester::SimplificationSuggestion> CodeSimplificationSuggester::detectLowQualityNames(const QString& code)
{
    QVector<SimplificationSuggestion> suggestions;

    // Detect single-letter variables (except in loops)
    if (code.contains(" a ") || code.contains(" b ") || code.contains(" x ") || code.contains(" y ")) {
        SimplificationSuggestion sugg;
        sugg.suggestionType = ImproveNaming;
        sugg.complexity = 0.4f;
        sugg.impact = 0.5f;
        sugg.explanation = "Single-letter or non-descriptive variable names detected";
        sugg.reasoning = "Use descriptive names that clearly indicate the variable's purpose.";
        suggestions.append(sugg);
    }

    // Detect unclear prefixes
    if (code.contains("temp") || code.contains("data") || code.contains("value")) {
        SimplificationSuggestion sugg;
        sugg.suggestionType = ImproveNaming;
        sugg.complexity = 0.3f;
        sugg.impact = 0.4f;
        sugg.explanation = "Generic or unclear variable names (temp, data, value)";
        sugg.reasoning = "Replace generic names with domain-specific, descriptive names.";
        suggestions.append(sugg);
    }

    return suggestions;
}

QVector<CodeSimplificationSuggester::SimplificationSuggestion> CodeSimplificationSuggester::detectExtractableLogic(const QString& code)
{
    QVector<SimplificationSuggestion> suggestions;

    int codeLines = code.split('\n').size();
    float complexity = calculateComplexity(code);

    if (codeLines > 50 && complexity > 0.7f) {
        SimplificationSuggestion sugg;
        sugg.suggestionType = ExtractMethod;
        sugg.complexity = complexity;
        sugg.impact = 0.8f;
        sugg.explanation = QString("Large function with high complexity (%1 lines, complexity %.2f)").arg(codeLines).arg(complexity);
        sugg.reasoning = "Consider breaking this function into smaller, more focused functions.";
        suggestions.append(sugg);
    }

    return suggestions;
}

int CodeSimplificationSuggester::calculateNestingDepth(const QString& line)
{
    int depth = 0;
    for (QChar c : line) {
        if (c == '{' || c == '[' || c == '(') {
            depth++;
        } else if (c == '}' || c == ']' || c == ')') {
            depth--;
        }
    }
    return std::max(0, depth);
}

float CodeSimplificationSuggester::calculateComplexity(const QString& code)
{
    float cyclomatic = calculateCyclomaticComplexity(code);
    float cognitive = calculateCognitiveComplexity(code);
    
    // Normalize and combine
    return (std::min(1.0f, cyclomatic / 10.0f) + std::min(1.0f, cognitive / 15.0f)) / 2.0f;
}

bool CodeSimplificationSuggester::isRedundant(const QString& line1, const QString& line2)
{
    QString l1 = line1.trimmed();
    QString l2 = line2.trimmed();
    
    if (l1.isEmpty() || l2.isEmpty()) return false;
    
    // Exact match
    if (l1 == l2) return true;
    
    // Similarity check (simplified)
    int similarity = 0;
    for (int i = 0; i < std::min(l1.size(), l2.size()); ++i) {
        if (l1[i] == l2[i]) similarity++;
    }
    
    float similarity_ratio = static_cast<float>(similarity) / std::max(l1.size(), l2.size());
    return similarity_ratio > 0.85f;
}

QString CodeSimplificationSuggester::suggestImprovedName(const QString& currentName)
{
    if (currentName.length() <= 1) {
        return "item";  // Generic fallback
    }
    
    // In production, would use domain-specific name dictionaries
    if (currentName == "x") return "value";
    if (currentName == "i") return "index";
    if (currentName == "temp") return "temporary";
    if (currentName == "data") return "payload";
    
    return currentName;
}

CodeSimplificationSuggester::SimplificationAnalysis CodeSimplificationSuggester::getAnalysisResult(const QString& filePath)
{
    if (m_results.contains(filePath)) {
        return m_results[filePath];
    }
    return SimplificationAnalysis();
}

QJsonObject CodeSimplificationSuggester::getStatistics() const
{
    QJsonObject stats;
    stats["totalAnalyzed"] = m_totalAnalyzed;
    stats["averageImprovementPotential"] = m_totalAnalyzed > 0 ? 
        m_totalImprovementPotential / m_totalAnalyzed : 0.0;
    return stats;
}

QString CodeSimplificationSuggester::generateSuggestionReport(const SimplificationAnalysis& analysis)
{
    QString report;
    report += "# Code Simplification Analysis\n\n";
    report += QString("**File**: %1\n").arg(analysis.filePath);
    report += QString("**Total Lines**: %1\n").arg(analysis.totalLines);
    report += QString("**Average Complexity**: %.2f\n").arg(analysis.averageComplexity);
    report += QString("**Improvement Potential**: %.1f%%\n\n").arg(analysis.overallImprovementPotential * 100);
    
    report += QString("## Suggestions (%1)\n\n").arg(analysis.suggestions.size());
    for (const SimplificationSuggestion& s : analysis.suggestions) {
        report += QString("- **%1** (Impact: %.1f%%, Complexity: %.2f)\n")
            .arg(QString::number(static_cast<int>(s.suggestionType))).arg(s.impact * 100).arg(s.complexity);
    }

    return report;
}

QString CodeSimplificationSuggester::generatePriorityList(const QVector<SimplificationSuggestion>& suggestions, int count)
{
    QString list;
    list += "## Top Simplification Priorities\n\n";
    
    int maxItems = std::min(count, static_cast<int>(suggestions.size()));
    for (int i = 0; i < maxItems; ++i) {
        list += QString("%1. %2 (Impact: %.1f%%)\n").arg(i+1).arg(suggestions[i].explanation).arg(suggestions[i].impact * 100);
    }

    return list;
}

QString CodeSimplificationSuggester::generateRefactoringGuide(const SimplificationAnalysis& analysis)
{
    QString guide;
    guide += "# Refactoring Guide\n\n";
    guide += "## Step-by-step refactoring recommendations:\n\n";
    
    for (const SimplificationSuggestion& s : analysis.suggestions) {
        guide += QString("### %1\n").arg(s.explanation);
        guide += QString("**Current**:\n```\n%1\n```\n\n").arg(s.currentCode);
        guide += QString("**Suggestion**: %1\n\n").arg(s.reasoning);
    }

    return guide;
}

float CodeSimplificationSuggester::calculateCyclomaticComplexity(const QString& code)
{
    float complexity = 1.0f;  // Base complexity
    complexity += code.count("if");
    complexity += code.count("else");
    complexity += code.count("switch");
    complexity += code.count("case");
    complexity += code.count("&&");
    complexity += code.count("||");
    complexity += code.count("?");
    return complexity;
}

float CodeSimplificationSuggester::calculateCognitiveComplexity(const QString& code)
{
    float complexity = 0.0f;
    int nestingLevel = 0;
    
    for (QChar c : code) {
        if (c == '{') {
            nestingLevel++;
            complexity += nestingLevel;
        } else if (c == '}') {
            nestingLevel--;
        }
    }
    
    return complexity;
}
