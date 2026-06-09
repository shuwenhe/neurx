#include "CommentQualityAnalyzer.h"
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>

CommentQualityAnalyzer::CommentQualityAnalyzer(QObject* parent)
    : QObject(parent)
{
}

CommentQualityAnalyzer::~CommentQualityAnalyzer()
{
}

void CommentQualityAnalyzer::analyzeComments(const QString& code, const QString& filePath, const AnalysisConfig& config)
{
    qInfo() << QString("[Comments] Analyzing: %1").arg(filePath);
    emit analysisStarted(filePath);

    CommentAnalysis analysis;
    analysis.filePath = filePath;
    
    if (config.checkAccuracy) {
        analysis.findings.append(findInaccurateComments(code));
    }
    if (config.checkCompleteness) {
        analysis.findings.append(findIncompleteComments(code));
    }
    if (config.checkForRedundancy) {
        analysis.findings.append(findRedundantComments(code));
    }
    if (config.checkReferences) {
        analysis.findings.append(findBrokenReferences(code));
    }

    analysis.totalComments = code.count("//") + code.count("/*");
    analysis.documentationComments = code.count("/**") + code.count("///");
    analysis.inlineComments = analysis.totalComments - analysis.documentationComments;
    
    for (const CommentFinding& f : analysis.findings) {
        if (f.severity > 0.7f) {
            analysis.criticalIssues++;
        } else {
            analysis.minorIssues++;
        }
    }

    analysis.overallQuality = analysis.totalComments > 0 ? 
        1.0f - (static_cast<float>(analysis.findings.size()) / analysis.totalComments) : 1.0f;
    
    analysis.summary = generateQualityReport(analysis);
    m_results[filePath] = analysis;
    m_totalAnalyzed++;
    m_totalIssuesFound += analysis.findings.size();

    for (const CommentFinding& f : analysis.findings) {
        emit issueFound(f);
    }

    emit analysisCompleted(filePath);
}

void CommentQualityAnalyzer::analyzeFile(const QString& filePath, const AnalysisConfig& config)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit errorOccurred(QString("Cannot open file: %1").arg(filePath));
        return;
    }

    QTextStream in(&file);
    QString code = in.readAll();
    file.close();

    analyzeComments(code, filePath, config);
}

QVector<CommentQualityAnalyzer::CommentFinding> CommentQualityAnalyzer::findInaccurateComments(const QString& code)
{
    QVector<CommentFinding> findings;
    
    // Simple heuristic: look for comments mentioning parameter names that don't exist
    QRegularExpression commentRegex(R"(/\*[\s\S]*?\*/|//.*$)");
    QRegularExpressionMatchIterator iter = commentRegex.globalMatch(code);
    
    while (iter.hasNext()) {
        QRegularExpressionMatch match = iter.next();
        QString comment = match.captured();
        
        // Check if comment claims to document something not in code
        if (comment.contains("parameter") && !comment.contains("const")) {
            CommentFinding finding;
            finding.issueType = Inaccurate;
            finding.severity = 0.6f;
            finding.commentText = comment.left(100);
            finding.issue = "Comment mentions parameters that may not exist";
            finding.suggestion = "Verify all mentioned parameters exist in the function signature";
            findings.append(finding);
        }
    }

    return findings;
}

QVector<CommentQualityAnalyzer::CommentFinding> CommentQualityAnalyzer::findOutdatedComments(const QString& code)
{
    QVector<CommentFinding> findings;

    if (code.contains("FIXME") || code.contains("TODO")) {
        CommentFinding finding;
        finding.issueType = Outdated;
        finding.severity = 0.5f;
        finding.issue = "Found FIXME/TODO comments - may indicate stale code";
        finding.suggestion = "Verify that the issue has been resolved or create a ticket";
        findings.append(finding);
    }

    return findings;
}

QVector<CommentQualityAnalyzer::CommentFinding> CommentQualityAnalyzer::findMisleadingComments(const QString& code)
{
    QVector<CommentFinding> findings;
    return findings;
}

QVector<CommentQualityAnalyzer::CommentFinding> CommentQualityAnalyzer::findRedundantComments(const QString& code)
{
    QVector<CommentFinding> findings;

    if (code.contains("// increment") || code.contains("// set")) {
        CommentFinding finding;
        finding.issueType = Redundant;
        finding.severity = 0.4f;
        finding.issue = "Comment just restates obvious code";
        finding.suggestion = "Remove redundant comments that merely repeat what the code clearly shows";
        findings.append(finding);
    }

    return findings;
}

QVector<CommentQualityAnalyzer::CommentFinding> CommentQualityAnalyzer::findIncompleteComments(const QString& code)
{
    QVector<CommentFinding> findings;

    if (code.contains("/**") && !code.contains("@param")) {
        CommentFinding finding;
        finding.issueType = Incomplete;
        finding.severity = 0.65f;
        finding.issue = "Documentation comment missing parameter documentation";
        finding.suggestion = "Add @param and @return documentation for all public functions";
        findings.append(finding);
    }

    return findings;
}

QVector<CommentQualityAnalyzer::CommentFinding> CommentQualityAnalyzer::findMissingEdgeCases(const QString& code)
{
    QVector<CommentFinding> findings;

    if (code.contains("if") && !code.contains("edge case")) {
        CommentFinding finding;
        finding.issueType = MissingEdgeCases;
        finding.severity = 0.5f;
        finding.issue = "Conditionals without edge case documentation";
        finding.suggestion = "Document how edge cases are handled";
        findings.append(finding);
    }

    return findings;
}

QVector<CommentQualityAnalyzer::CommentFinding> CommentQualityAnalyzer::findBrokenReferences(const QString& code)
{
    QVector<CommentFinding> findings;
    return findings;
}

bool CommentQualityAnalyzer::commentMatchesCode(const QString& comment, const QString& code)
{
    // Simplified: check if terms in comment appear in code
    return !comment.isEmpty() && !code.isEmpty();
}

bool CommentQualityAnalyzer::isRedundantComment(const QString& comment, const QString& code)
{
    // Check if comment is just describing obvious code
    QString lower = comment.toLower();
    return lower.contains("increment") || lower.contains("decrement") || 
           lower.contains("set") || lower.contains("get");
}

bool CommentQualityAnalyzer::hasBrokenReference(const QString& comment, const QString& code)
{
    return false;  // Placeholder
}

QStringList CommentQualityAnalyzer::extractReferencesFromComment(const QString& comment)
{
    QStringList refs;
    // Extract identifiers from comment
    QRegularExpression identifierRegex(R"(\b[a-zA-Z_][a-zA-Z0-9_]*\b)");
    QRegularExpressionMatchIterator iter = identifierRegex.globalMatch(comment);
    
    while (iter.hasNext()) {
        refs.append(iter.next().captured());
    }
    
    return refs;
}

CommentQualityAnalyzer::CommentAnalysis CommentQualityAnalyzer::getAnalysisResult(const QString& filePath)
{
    if (m_results.contains(filePath)) {
        return m_results[filePath];
    }
    return CommentAnalysis();
}

QJsonObject CommentQualityAnalyzer::getStatistics() const
{
    QJsonObject stats;
    stats["totalAnalyzed"] = m_totalAnalyzed;
    stats["totalIssuesFound"] = m_totalIssuesFound;
    return stats;
}

QString CommentQualityAnalyzer::generateQualityReport(const CommentAnalysis& analysis)
{
    QString report;
    report += "# Comment Quality Report\n\n";
    report += QString("**File**: %1\n").arg(analysis.filePath);
    report += QString("**Overall Quality**: %.1f%%\n").arg(analysis.overallQuality * 100);
    report += QString("**Total Comments**: %1\n").arg(analysis.totalComments);
    report += QString("**Documentation Comments**: %1\n").arg(analysis.documentationComments);
    report += QString("**Critical Issues**: %1\n").arg(analysis.criticalIssues);
    report += QString("**Minor Issues**: %1\n\n").arg(analysis.minorIssues);
    
    if (analysis.overallQuality < 0.75f) {
        report += "⚠️ **Action required**: Comment quality below acceptable threshold\n";
    }

    return report;
}

QString CommentQualityAnalyzer::generateCriticalIssuesReport(const CommentAnalysis& analysis)
{
    QString report;
    report += "# Critical Comment Issues\n\n";
    
    for (const CommentFinding& f : analysis.findings) {
        if (f.severity > 0.7f) {
            report += QString("## %1 (Severity: %.1f%%)\n").arg(f.issue).arg(f.severity * 100);
            report += QString("**Line %1**: %2\n\n").arg(f.lineNumber).arg(f.commentText);
        }
    }

    return report;
}

QString CommentQualityAnalyzer::generateImprovementSuggestions(const CommentAnalysis& analysis)
{
    QString suggestions;
    suggestions += "# Comment Improvement Suggestions\n\n";
    
    for (const CommentFinding& f : analysis.findings) {
        suggestions += QString("- %1\n").arg(f.suggestion);
    }

    return suggestions;
}
