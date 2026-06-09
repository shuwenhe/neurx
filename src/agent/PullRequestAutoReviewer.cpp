#include "PullRequestAutoReviewer.h"
#include <QDebug>
#include <QRegularExpression>
#include <QJsonDocument>
#include <cmath>

const QVector<QString> PullRequestAutoReviewer::SECURITY_KEYWORDS = {
    "password", "token", "secret", "key", "auth", "crypto", "eval",
    "exec", "system", "shell", "command", "injection", "sql", "xss",
    "cors", "csrf", "ssl", "tls", "cipher", "hash"
};

const QVector<QString> PullRequestAutoReviewer::PERFORMANCE_KEYWORDS = {
    "loop", "recursive", "cache", "memory", "buffer", "query", "database",
    "network", "timeout", "throttle", "debounce", "optimize", "slow",
    "expensive", "algorithm", "complexity"
};

const QVector<QString> PullRequestAutoReviewer::STYLE_KEYWORDS = {
    "const", "let", "var", "function", "async", "await", "error",
    "warning", "deprecate", "todo", "fixme", "hack", "dirty"
};

PullRequestAutoReviewer::PullRequestAutoReviewer(QObject* parent)
    : QObject(parent)
{
    initializePatterns();
}

PullRequestAutoReviewer::~PullRequestAutoReviewer()
{
    // Cleanup
}

void PullRequestAutoReviewer::reviewPullRequest(int prNumber, const ReviewConfig& config)
{
    m_config = config;
    
    qInfo() << QString("[Review] Starting review of PR #%1").arg(prNumber);
    emit reviewStarted(prNumber);

    try {
        ReviewResult result = generateReview(prNumber, config);
        m_reviewResults[prNumber] = result;
        m_totalReviewsPerformed++;
        m_totalFindingsDetected += result.findings.size();

        // Post review if needed
        if (config.generateSummaryComment) {
            postReviewSummary(prNumber, result);
        }

        emit reviewCompleted(prNumber);
        qInfo() << QString("[Review] Completed review of PR #%1: %2 findings").arg(prNumber).arg(result.findings.size());
    } catch (const std::exception& e) {
        QString error = QString::fromStdString(e.what());
        emit errorOccurred(error);
        qWarning() << "[Review] Error reviewing PR #" << prNumber << ": " << error;
    }
}

void PullRequestAutoReviewer::reviewMultiplePRs(const QVector<int>& prNumbers, const ReviewConfig& config)
{
    qInfo() << QString("[Review] Starting batch review of %1 PRs").arg(prNumbers.size());

    for (int prNumber : prNumbers) {
        reviewPullRequest(prNumber, config);
    }

    qInfo() << "[Review] Batch review completed";
}

void PullRequestAutoReviewer::detectSecurityPatterns(const ReviewFinding& finding)
{
    qInfo() << QString("[Review] Detecting security patterns in PR #%1").arg(finding.prNumber);

    for (const QString& keyword : SECURITY_KEYWORDS) {
        if (finding.codeSnippet.contains(keyword, Qt::CaseInsensitive)) {
            qWarning() << QString("  ⚠️  Security keyword found: %1").arg(keyword);
        }
    }
}

void PullRequestAutoReviewer::detectPerformancePatterns(const ReviewFinding& finding)
{
    qInfo() << QString("[Review] Detecting performance patterns in PR #%1").arg(finding.prNumber);

    for (const QString& keyword : PERFORMANCE_KEYWORDS) {
        if (finding.codeSnippet.contains(keyword, Qt::CaseInsensitive)) {
            qInfo() << QString("  ⚙️  Performance keyword found: %1").arg(keyword);
        }
    }
}

void PullRequestAutoReviewer::detectCodeStylePatterns(const ReviewFinding& finding)
{
    qInfo() << QString("[Review] Detecting style patterns in PR #%1").arg(finding.prNumber);

    for (const QString& keyword : STYLE_KEYWORDS) {
        if (finding.codeSnippet.contains(keyword, Qt::CaseInsensitive)) {
            qDebug() << QString("  📝 Style keyword found: %1").arg(keyword);
        }
    }
}

QVector<PullRequestAutoReviewer::CodePattern> PullRequestAutoReviewer::analyzeCode(const QString& code, const QString& language)
{
    QVector<CodePattern> patterns;

    // Analyze for common patterns
    if (code.contains("TODO", Qt::CaseInsensitive) || code.contains("FIXME", Qt::CaseInsensitive)) {
        CodePattern pattern;
        pattern.patternName = "IncompleteTODO";
        pattern.description = "Found TODO or FIXME comment in code";
        pattern.severity = Warning;
        pattern.confidenceScore = 0.95f;
        pattern.suggestion = "Complete the TODO or remove it before merging";
        pattern.isSecurityIssue = false;
        patterns.append(pattern);
    }

    if (code.contains("console.log") || code.contains("qDebug")) {
        CodePattern pattern;
        pattern.patternName = "DebugOutput";
        pattern.description = "Debug output statement found";
        pattern.severity = Info;
        pattern.confidenceScore = 0.9f;
        pattern.suggestion = "Remove debug output before production release";
        pattern.isSecurityIssue = false;
        patterns.append(pattern);
    }

    if (code.contains("eval(") || code.contains("exec(")) {
        CodePattern pattern;
        pattern.patternName = "DangerousEval";
        pattern.description = "Use of eval() or exec() detected";
        pattern.severity = Critical;
        pattern.confidenceScore = 0.98f;
        pattern.suggestion = "Replace eval/exec with safer alternatives";
        pattern.isSecurityIssue = true;
        patterns.append(pattern);
    }

    return patterns;
}

float PullRequestAutoReviewer::calculateComplexityScore(const QString& code)
{
    float score = 0.0f;
    int lineCount = code.split('\n').size();
    int nestingDepth = 0;
    int conditionCount = code.count("if") + code.count("else");
    int loopCount = code.count("for") + code.count("while");

    score += std::min(lineCount / 100.0f, 3.0f);  // Lines complexity
    score += conditionCount * 0.1f;              // Conditional complexity
    score += loopCount * 0.15f;                  // Loop complexity

    return std::min(score, 10.0f);  // Cap at 10.0
}

float PullRequestAutoReviewer::calculateConfidenceScore(const CodePattern& pattern)
{
    float confidence = pattern.confidenceScore;

    // Adjust based on severity
    switch (pattern.severity) {
        case Critical:
            confidence = std::min(1.0f, confidence + 0.05f);
            break;
        case Error:
            confidence = std::min(1.0f, confidence + 0.03f);
            break;
        case Warning:
            confidence = std::max(0.0f, confidence - 0.05f);
            break;
        case Info:
            confidence = std::max(0.0f, confidence - 0.10f);
            break;
    }

    return confidence;
}

PullRequestAutoReviewer::ReviewResult PullRequestAutoReviewer::generateReview(int prNumber, const ReviewConfig& config)
{
    ReviewResult result;
    result.prNumber = prNumber;

    qInfo() << QString("[Review] Generating review for PR #%1").arg(prNumber);

    // In production, would fetch PR data from GitHub API
    // Simulate review generation for now

    // Create sample findings
    CodePattern pattern1;
    pattern1.patternName = "CodeQuality";
    pattern1.severity = Warning;
    pattern1.confidenceScore = 0.85f;

    ReviewFinding finding1;
    finding1.prNumber = prNumber;
    finding1.pattern = pattern1;
    finding1.filePath = "src/main.cpp";
    finding1.lineNumber = 42;

    result.findings.append(finding1);
    result.totalFindings = result.findings.size();
    result.criticalIssues = 0;
    result.warnings = 1;

    // Calculate overall rating
    if (result.criticalIssues > 0) {
        result.overallRating = "Reject";
        result.requiresHumanReview = true;
    } else if (result.warnings > 0) {
        result.overallRating = "Needs Review";
        result.requiresHumanReview = true;
    } else {
        result.overallRating = "Pass";
        result.requiresHumanReview = false;
    }

    result.summaryComment = generateSummaryComment(result);

    return result;
}

QString PullRequestAutoReviewer::generateReviewComment(const ReviewResult& result, const ReviewConfig& config)
{
    QString comment;
    comment += "## Automated Review\n\n";
    comment += QString("Overall Rating: **%1**\n\n").arg(result.overallRating);
    comment += QString("Found %1 findings:\n").arg(result.totalFindings);

    int critical = result.criticalIssues;
    int warnings = result.warnings;

    if (critical > 0) {
        comment += QString("- 🔴 **%1 Critical issues**\n").arg(critical);
    }
    if (warnings > 0) {
        comment += QString("- 🟡 **%1 Warnings**\n").arg(warnings);
    }

    comment += "\n---\n";
    comment += QString("_Generated by %1_\n").arg(config.reviewerName);

    return comment;
}

QString PullRequestAutoReviewer::generateSummaryComment(const ReviewResult& result)
{
    QString summary = "## Review Summary\n\n";
    summary += QString("- Total Findings: %1\n").arg(result.totalFindings);
    summary += QString("- Rating: %1\n").arg(result.overallRating);

    if (result.requiresHumanReview) {
        summary += "\n⚠️ **Requires human review**\n";
    } else {
        summary += "\n✅ **Automated checks passed**\n";
    }

    return summary;
}

void PullRequestAutoReviewer::postReviewComment(int prNumber, const QString& comment)
{
    qInfo() << QString("[Review] Posting comment on PR #%1").arg(prNumber);
    // In production, would POST to GitHub API
    emit reviewCommented(prNumber);
}

void PullRequestAutoReviewer::postReviewFindings(int prNumber, const QVector<ReviewFinding>& findings)
{
    qInfo() << QString("[Review] Posting %1 findings on PR #%1").arg(findings.size()).arg(prNumber);
    // In production, would POST individual review comments
}

void PullRequestAutoReviewer::postReviewSummary(int prNumber, const ReviewResult& result)
{
    QString summary = generateSummaryComment(result);
    postReviewComment(prNumber, summary);
    emit reviewSummaryPosted(prNumber);
}

PullRequestAutoReviewer::ReviewResult PullRequestAutoReviewer::getReviewResult(int prNumber)
{
    if (m_reviewResults.contains(prNumber)) {
        return m_reviewResults[prNumber];
    }
    return ReviewResult();
}

QVector<PullRequestAutoReviewer::ReviewFinding> PullRequestAutoReviewer::getReviewFindings(int prNumber)
{
    if (m_reviewFindings.contains(prNumber)) {
        return m_reviewFindings[prNumber];
    }
    return QVector<ReviewFinding>();
}

QJsonObject PullRequestAutoReviewer::getReviewStatistics() const
{
    QJsonObject stats;
    stats["totalReviewsPerformed"] = m_totalReviewsPerformed;
    stats["totalFindingsDetected"] = m_totalFindingsDetected;
    stats["totalConfidenceAccumulated"] = m_totalConfidenceAccumulated;
    stats["averageConfidence"] = m_totalReviewsPerformed > 0 
        ? m_totalConfidenceAccumulated / m_totalReviewsPerformed 
        : 0.0;
    stats["registeredPatterns"] = static_cast<int>(m_patternRegistry.size());
    return stats;
}

void PullRequestAutoReviewer::registerPattern(const CodePattern& pattern)
{
    m_patternRegistry[pattern.patternName] = pattern;
    qInfo() << QString("[Review] Registered pattern: %1").arg(pattern.patternName);
}

QVector<PullRequestAutoReviewer::CodePattern> PullRequestAutoReviewer::getPatterns(SeverityLevel severity)
{
    QVector<CodePattern> patterns;
    for (auto it = m_patternRegistry.begin(); it != m_patternRegistry.end(); ++it) {
        if (it.value().severity == severity) {
            patterns.append(it.value());
        }
    }
    return patterns;
}

void PullRequestAutoReviewer::updatePatternConfidence(const QString& patternName, float newConfidence)
{
    if (m_patternRegistry.contains(patternName)) {
        m_patternRegistry[patternName].confidenceScore = std::min(1.0f, std::max(0.0f, newConfidence));
        qInfo() << QString("[Review] Updated confidence for %1: %.2f").arg(patternName).arg(newConfidence);
    }
}

void PullRequestAutoReviewer::setReviewConfig(const ReviewConfig& config)
{
    m_config = config;
}

PullRequestAutoReviewer::ReviewConfig PullRequestAutoReviewer::getReviewConfig() const
{
    return m_config;
}

float PullRequestAutoReviewer::getAverageConfidence(const ReviewResult& result)
{
    if (result.findings.isEmpty()) return 1.0f;

    float total = 0.0f;
    for (const ReviewFinding& finding : result.findings) {
        total += finding.pattern.confidenceScore;
    }

    return total / result.findings.size();
}

bool PullRequestAutoReviewer::meetsConfidenceThreshold(const ReviewResult& result, float threshold)
{
    return getAverageConfidence(result) >= threshold;
}

bool PullRequestAutoReviewer::isSecuritySensitiveFile(const QString& filePath)
{
    return filePath.contains("auth", Qt::CaseInsensitive) ||
           filePath.contains("crypto", Qt::CaseInsensitive) ||
           filePath.contains("security", Qt::CaseInsensitive) ||
           filePath.contains("password", Qt::CaseInsensitive);
}

QString PullRequestAutoReviewer::getFileLanguage(const QString& filePath)
{
    if (filePath.endsWith(".ts")) return "TypeScript";
    if (filePath.endsWith(".js")) return "JavaScript";
    if (filePath.endsWith(".cpp") || filePath.endsWith(".h")) return "C++";
    if (filePath.endsWith(".py")) return "Python";
    if (filePath.endsWith(".rs")) return "Rust";
    return "Unknown";
}

QString PullRequestAutoReviewer::truncateCodeSnippet(const QString& code, int maxLines)
{
    QStringList lines = code.split('\n');
    if (lines.size() > maxLines) {
        lines = lines.mid(0, maxLines);
        lines.append("...");
    }
    return lines.join('\n');
}

void PullRequestAutoReviewer::initializePatterns()
{
    // Register default patterns
    CodePattern debugPattern;
    debugPattern.patternName = "DebugStatement";
    debugPattern.description = "Debug console output found";
    debugPattern.severity = Info;
    debugPattern.confidenceScore = 0.85f;
    registerPattern(debugPattern);

    CodePattern todoPattern;
    todoPattern.patternName = "TODOComment";
    todoPattern.description = "Incomplete TODO found";
    todoPattern.severity = Warning;
    todoPattern.confidenceScore = 0.9f;
    registerPattern(todoPattern);

    CodePattern evalPattern;
    evalPattern.patternName = "DangerousEval";
    evalPattern.description = "Dangerous eval/exec usage";
    evalPattern.severity = Critical;
    evalPattern.confidenceScore = 0.98f;
    registerPattern(evalPattern);
}
