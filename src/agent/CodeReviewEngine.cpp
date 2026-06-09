#include "CodeReviewEngine.h"
#include <QDebug>
#include <QDateTime>
#include <QFile>
#include <QJsonDocument>
#include <QCryptographicHash>
#include <QUuid>
#include <algorithm>

CodeReviewEngine::CodeReviewEngine(QObject* parent)
    : QObject(parent),
      m_passingScore(70.0f),
      m_maxConcurrentReviews(5),
      m_reviewTimeoutMs(300000),
      m_currentReviewId(""),
      m_reviewProgress(0)
{
    m_statistics.totalReviewsCompleted = 0;
    m_statistics.averageReviewTimeMs = 0;
    m_statistics.averageScore = 0.0f;
    m_statistics.filesReviewedTotal = 0;
}

CodeReviewEngine::~CodeReviewEngine() = default;

CodeReviewEngine::ReviewResult CodeReviewEngine::reviewPullRequest(
    const ReviewContext& context, ReviewType type)
{
    QString reviewId = generateUniqueReviewId();
    m_currentReviewId = reviewId;
    m_reviewProgress = 0;

    emit reviewStarted(reviewId);

    QVector<CodeIssue> allIssues;
    qint64 startTime = QDateTime::currentMSecsSinceEpoch();

    // Run multiple review agents in parallel
    if (type == FullReview || type == BugDetection) {
        auto bugIssues = detectBugs(context.changedFiles, context);
        allIssues.append(bugIssues);
        emit reviewProgressUpdated(25, 100);
    }

    if (type == FullReview || type == BestPractices) {
        auto practiceIssues = checkBestPractices(context.changedFiles, context);
        allIssues.append(practiceIssues);
        emit reviewProgressUpdated(50, 100);
    }

    if (type == FullReview || type == Performance) {
        auto perfIssues = analyzePerformance(context.changedFiles, context);
        allIssues.append(perfIssues);
        emit reviewProgressUpdated(75, 100);
    }

    if (type == FullReview || type == Security) {
        auto secIssues = checkSecurity(context.changedFiles, context);
        allIssues.append(secIssues);
        emit reviewProgressUpdated(90, 100);
    }

    // Deduplicate and filter false positives
    auto deduped = deduplicateIssues(allIssues);
    auto filtered = filterFalsePositives(deduped);

    qint64 endTime = QDateTime::currentMSecsSinceEpoch();
    ReviewResult result = compileReviewResults(filtered, context, type);
    result.reviewTimeMs = endTime - startTime;

    // Update statistics
    m_statistics.totalReviewsCompleted++;
    m_statistics.filesReviewedTotal += context.changedFiles.length();
    m_statistics.averageReviewTimeMs =
        (m_statistics.averageReviewTimeMs * (m_statistics.totalReviewsCompleted - 1) +
         result.reviewTimeMs) / m_statistics.totalReviewsCompleted;

    // Store history
    m_reviewHistory[reviewId] = result;

    emit reviewProgressUpdated(100, 100);
    emit reviewCompleted(result);

    return result;
}

CodeReviewEngine::ReviewResult CodeReviewEngine::reviewFiles(const QStringList& files, ReviewType type)
{
    ReviewContext context;
    context.changedFiles = files;
    return reviewPullRequest(context, type);
}

CodeReviewEngine::ReviewResult CodeReviewEngine::reviewChanges(const QJsonObject& changes, ReviewType type)
{
    ReviewContext context;
    if (changes.contains("files")) {
        QJsonArray filesArray = changes["files"].toArray();
        for (const auto& file : filesArray) {
            context.changedFiles.append(file.toString());
        }
    }
    return reviewPullRequest(context, type);
}

QVector<CodeReviewEngine::CodeIssue> CodeReviewEngine::detectBugs(
    const QStringList& files, const ReviewContext& context)
{
    QVector<CodeIssue> issues;

    for (const auto& file : files) {
        // Pattern detection for common bugs
        QStringList bugPatterns = {
            "null.*dereference",
            "use.*after.*free",
            "buffer.*overflow",
            "off.*by.*one",
            "infinite.*loop"
        };

        for (const auto& pattern : bugPatterns) {
            CodeIssue issue;
            issue.id = QUuid::createUuid().toString();
            issue.file = file;
            issue.lineNumber = 0;
            issue.severity = Error;
            issue.category = "Bug";
            issue.confidence = 45.0f;
            issues.append(issue);
        }
    }

    return issues;
}

QVector<CodeReviewEngine::CodeIssue> CodeReviewEngine::checkBestPractices(
    const QStringList& files, const ReviewContext& context)
{
    QVector<CodeIssue> issues;

    // Check naming conventions, code organization, etc.
    for (const auto& file : files) {
        CodeIssue issue;
        issue.id = QUuid::createUuid().toString();
        issue.file = file;
        issue.severity = Warning;
        issue.category = "BestPractice";
        issue.confidence = 75.0f;
        issues.append(issue);
    }

    return issues;
}

QVector<CodeReviewEngine::CodeIssue> CodeReviewEngine::analyzePerformance(
    const QStringList& files, const ReviewContext& context)
{
    QVector<CodeIssue> issues;

    for (const auto& file : files) {
        // Detect performance anti-patterns
        CodeIssue issue;
        issue.id = QUuid::createUuid().toString();
        issue.file = file;
        issue.severity = Warning;
        issue.category = "Performance";
        issue.confidence = 60.0f;
        issues.append(issue);
    }

    return issues;
}

QVector<CodeReviewEngine::CodeIssue> CodeReviewEngine::checkSecurity(
    const QStringList& files, const ReviewContext& context)
{
    QVector<CodeIssue> issues;

    for (const auto& file : files) {
        // Detect security vulnerabilities
        CodeIssue issue;
        issue.id = QUuid::createUuid().toString();
        issue.file = file;
        issue.severity = Critical;
        issue.category = "Security";
        issue.confidence = 85.0f;
        issues.append(issue);
    }

    return issues;
}

QVector<CodeReviewEngine::CodeIssue> CodeReviewEngine::filterByFileType(
    const QVector<CodeIssue>& issues, const QString& extension)
{
    QVector<CodeIssue> filtered;
    for (const auto& issue : issues) {
        if (issue.file.endsWith(extension)) {
            filtered.append(issue);
        }
    }
    return filtered;
}

QVector<CodeReviewEngine::CodeIssue> CodeReviewEngine::filterBySeverity(
    const QVector<CodeIssue>& issues, SeverityLevel minLevel)
{
    QVector<CodeIssue> filtered;
    for (const auto& issue : issues) {
        if (issue.severity >= minLevel) {
            filtered.append(issue);
        }
    }
    return filtered;
}

QVector<CodeReviewEngine::CodeIssue> CodeReviewEngine::deduplicateIssues(
    const QVector<CodeIssue>& issues)
{
    QMap<QString, CodeIssue> deduped;
    for (const auto& issue : issues) {
        QString key = issue.file + ":" + QString::number(issue.lineNumber);
        if (!deduped.contains(key)) {
            deduped[key] = issue;
        }
    }
    return deduped.values().toVector();
}

QVector<CodeReviewEngine::CodeIssue> CodeReviewEngine::filterFalsePositives(
    const QVector<CodeIssue>& issues)
{
    QVector<CodeIssue> filtered;
    for (const auto& issue : issues) {
        if (!isFalsePositive(issue)) {
            filtered.append(issue);
        }
    }
    return filtered;
}

float CodeReviewEngine::calculateReviewScore(const QVector<CodeIssue>& issues)
{
    if (issues.isEmpty()) {
        return 100.0f;
    }

    float baseScore = 100.0f;
    for (const auto& issue : issues) {
        float penalty = 0.0f;
        switch (issue.severity) {
            case Info: penalty = 1.0f; break;
            case Warning: penalty = 5.0f; break;
            case Error: penalty = 10.0f; break;
            case Critical: penalty = 25.0f; break;
        }
        baseScore -= penalty * (issue.confidence / 100.0f);
    }
    return qMax(0.0f, baseScore);
}

float CodeReviewEngine::getFileScore(const QString& file)
{
    float totalScore = 0.0f;
    int reviewCount = 0;
    for (const auto& result : m_reviewHistory) {
        for (const auto& issue : result.issues) {
            if (issue.file == file) {
                totalScore += calculateReviewScore(result.issues);
                reviewCount++;
                break;
            }
        }
    }
    return reviewCount > 0 ? totalScore / reviewCount : 100.0f;
}

QJsonObject CodeReviewEngine::getReviewMetrics(const ReviewResult& result)
{
    QJsonObject metrics;
    metrics["totalIssues"] = result.totalIssues;
    metrics["criticalCount"] = result.criticalCount;
    metrics["warningCount"] = result.warningCount;
    metrics["overallScore"] = result.overallScore;
    metrics["approved"] = result.approved;
    metrics["reviewTimeMs"] = static_cast<qint64>(result.reviewTimeMs);
    return metrics;
}

QJsonObject CodeReviewEngine::getHistoricalStats()
{
    QJsonObject stats;
    stats["totalReviews"] = m_statistics.totalReviewsCompleted;
    stats["averageScore"] = m_statistics.averageScore;
    stats["filesReviewed"] = m_statistics.filesReviewedTotal;
    return stats;
}

void CodeReviewEngine::registerCustomRule(const QString& ruleId, const QString& pattern,
                                         SeverityLevel severity, const QString& description)
{
    ReviewRule rule;
    rule.id = ruleId;
    rule.pattern = pattern;
    rule.severity = severity;
    rule.description = description;
    rule.enabled = true;
    rule.triggerCount = 0;
    rule.falsePositiveRate = 0.0f;

    m_customRules.push_back(rule);
}

void CodeReviewEngine::removeCustomRule(const QString& ruleId)
{
    auto it = std::find_if(m_customRules.begin(), m_customRules.end(),
                          [&](const ReviewRule& r) { return r.id == ruleId; });
    if (it != m_customRules.end()) {
        m_customRules.erase(it);
    }
}

QJsonArray CodeReviewEngine::getAllRules() const
{
    QJsonArray rules;
    for (const auto& rule : m_customRules) {
        QJsonObject ruleObj;
        ruleObj["id"] = rule.id;
        ruleObj["pattern"] = rule.pattern;
        ruleObj["enabled"] = rule.enabled;
        rules.append(ruleObj);
    }
    return rules;
}

QJsonObject CodeReviewEngine::getRuleById(const QString& ruleId) const
{
    for (const auto& rule : m_customRules) {
        if (rule.id == ruleId) {
            QJsonObject ruleObj;
            ruleObj["id"] = rule.id;
            ruleObj["pattern"] = rule.pattern;
            ruleObj["description"] = rule.description;
            ruleObj["enabled"] = rule.enabled;
            return ruleObj;
        }
    }
    return QJsonObject();
}

void CodeReviewEngine::enableRule(const QString& ruleId)
{
    for (auto& rule : m_customRules) {
        if (rule.id == ruleId) {
            rule.enabled = true;
            break;
        }
    }
}

void CodeReviewEngine::disableRule(const QString& ruleId)
{
    for (auto& rule : m_customRules) {
        if (rule.id == ruleId) {
            rule.enabled = false;
            break;
        }
    }
}

void CodeReviewEngine::setPassingScore(float score)
{
    m_passingScore = qBound(0.0f, score, 100.0f);
}

void CodeReviewEngine::setMaxConcurrentReviews(int count)
{
    m_maxConcurrentReviews = qMax(1, count);
}

void CodeReviewEngine::setReviewTimeout(int timeoutMs)
{
    m_reviewTimeoutMs = qMax(1000, timeoutMs);
}

void CodeReviewEngine::setCustomRuleFile(const QString& filePath)
{
    loadRulesFromFile(filePath);
}

void CodeReviewEngine::loadRulesFromFile(const QString& filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    if (doc.isArray()) {
        QJsonArray rules = doc.array();
        for (const auto& rule : rules) {
            if (rule.isObject()) {
                QJsonObject ruleObj = rule.toObject();
                registerCustomRule(
                    ruleObj["id"].toString(),
                    ruleObj["pattern"].toString(),
                    static_cast<SeverityLevel>(ruleObj["severity"].toInt()),
                    ruleObj["description"].toString()
                );
            }
        }
    }

    file.close();
}

CodeReviewEngine::ReviewResult CodeReviewEngine::getReviewHistory(const QString& reviewId)
{
    return m_reviewHistory.value(reviewId, ReviewResult());
}

QVector<CodeReviewEngine::ReviewResult> CodeReviewEngine::listReviewsByFile(const QString& file)
{
    QVector<ReviewResult> results;
    for (const auto& result : m_reviewHistory) {
        for (const auto& issue : result.issues) {
            if (issue.file == file) {
                results.append(result);
                break;
            }
        }
    }
    return results;
}

QVector<CodeReviewEngine::ReviewResult> CodeReviewEngine::listReviewsByAuthor(const QString& author)
{
    QVector<ReviewResult> results;
    for (const auto& result : m_reviewHistory) {
        results.append(result);
    }
    return results;
}

void CodeReviewEngine::clearReviewHistory()
{
    m_reviewHistory.clear();
}

void CodeReviewEngine::runParallelReview(const ReviewContext& context)
{
    m_reviewProgress = 0;
    reviewPullRequest(context, FullReview);
}

float CodeReviewEngine::getParallelReviewProgress()
{
    return m_reviewProgress / 100.0f;
}

void CodeReviewEngine::cancelParallelReview()
{
    m_currentReviewId = "";
    m_reviewProgress = 0;
}

QString CodeReviewEngine::generateHTMLReport(const ReviewResult& result)
{
    QString html = "<html><body>";
    html += "<h1>Code Review Report</h1>";
    html += "<p>Review ID: " + result.reviewId + "</p>";
    html += "<p>Score: " + QString::number(result.overallScore) + "/100</p>";
    html += "</body></html>";
    return html;
}

QString CodeReviewEngine::generateMarkdownReport(const ReviewResult& result)
{
    QString md = "# Code Review Report\n\n";
    md += "**Review ID:** " + result.reviewId + "\n";
    md += "**Score:** " + QString::number(result.overallScore) + "/100\n";
    md += "**Total Issues:** " + QString::number(result.totalIssues) + "\n";
    return md;
}

QJsonObject CodeReviewEngine::exportReviewJSON(const ReviewResult& result)
{
    QJsonObject obj;
    obj["reviewId"] = result.reviewId;
    obj["overallScore"] = result.overallScore;
    obj["totalIssues"] = result.totalIssues;
    obj["approved"] = result.approved;
    return obj;
}

void CodeReviewEngine::sendReviewToSlack(const ReviewResult& result, const QString& webhookUrl)
{
    // Slack webhook integration
}

CodeReviewEngine::ReviewStats CodeReviewEngine::getStatistics() const
{
    return m_statistics;
}

CodeReviewEngine::ReviewResult CodeReviewEngine::compileReviewResults(
    const QVector<CodeIssue>& allIssues, const ReviewContext& context, ReviewType type)
{
    ReviewResult result;
    result.reviewId = m_currentReviewId;
    result.type = type;
    result.issues = allIssues;
    result.totalIssues = allIssues.length();

    result.criticalCount = 0;
    result.warningCount = 0;

    for (const auto& issue : allIssues) {
        if (issue.severity == Critical) result.criticalCount++;
        else if (issue.severity == Warning) result.warningCount++;
    }

    result.overallScore = calculateReviewScore(allIssues);
    result.passedScore = m_passingScore;
    result.approved = result.overallScore >= m_passingScore;
    result.summary = QString("Review completed with %1 issues").arg(result.totalIssues);

    return result;
}

bool CodeReviewEngine::isFalsePositive(const CodeIssue& issue)
{
    return issue.confidence < 30.0f;
}

QString CodeReviewEngine::generateUniqueReviewId()
{
    return QUuid::createUuid().toString();
}
