#include "GitHubSweepAutomation.h"
#include <QDebug>
#include <QRegularExpression>
#include <algorithm>

GitHubSweepAutomation::GitHubSweepAutomation(QObject* parent)
    : QObject(parent), m_daysBeforeNudge(7), m_daysBeforeClose(30), 
      m_autoCloseEnabled(true), m_totalProcessed(0), m_totalActions(0)
{
    // Initialize default keywords
    m_needInfoKeywords << "unclear" << "ambiguous" << "details?" << "more info" 
                      << "please clarify" << "not enough info" << "need details";
    
    m_needReproKeywords << "can't reproduce" << "cannot reproduce" << "can not reproduce"
                        << "unable to reproduce" << "not reproducible" << "steps to reproduce"
                        << "minimal example" << "repro case";
}

GitHubSweepAutomation::~GitHubSweepAutomation()
{
}

void GitHubSweepAutomation::scanRepositoryIssues(const QString& owner, const QString& repo)
{
    Q_UNUSED(owner);
    emit sweepStarted(repo);
    m_totalProcessed = 0;
    m_totalActions = 0;
    m_actionStats.clear();
}

void GitHubSweepAutomation::processIssue(const QJsonObject& issue)
{
    SweepAction action = determineSweepAction(issue);
    
    int issueNumber = issue.value("number").toInt();
    
    m_totalProcessed++;
    
    if (action != NoAction) {
        m_totalActions++;
        m_actionStats[action]++;

        QString message;
        switch (action) {
            case NudgeForInfo:
                message = generateInfoNudge();
                break;
            case RequestRepro:
                message = generateReproNudge();
                break;
            case MarkStale:
                message = generateStaleWarning();
                break;
            case AutoClose:
                message = generateAutoCloseReason();
                break;
            case Archive:
                message = QStringLiteral("Issue marked for archive.");
                break;
            case NoAction:
                break;
        }
        emit actionTaken(issueNumber, action, message);
    }
    
    emit issueProcessed(issueNumber, action);
}

GitHubSweepAutomation::SweepAction GitHubSweepAutomation::determineSweepAction(const QJsonObject& issue)
{
    QString title = issue.value("title").toString().toLower();
    QString body = issue.value("body").toString().toLower();
    QJsonArray labels = issue.value("labels").toArray();
    int inactiveDays = daysSinceLastActivity(issue);
    
    // Check if already needs-info or needs-reproduction
    QStringList labelNames;
    for (const QJsonValue& label : labels) {
        labelNames << label.toObject().value("name").toString();
    }
    
    // Analyze content
    bool needsInfo = needsInformation(issue);
    bool needsRepro = needsReproduction(issue);
    bool isStale = isStaleWithoutResponse(issue);
    bool pastNudgeThreshold = inactiveDays >= m_daysBeforeNudge;
    
    // Determine action priority
    if (isStale && m_autoCloseEnabled) {
        return AutoClose;
    }
    
    if (needsInfo && pastNudgeThreshold && !labelNames.contains("needs-info")) {
        return NudgeForInfo;
    }
    
    if (needsRepro && pastNudgeThreshold && !labelNames.contains("needs-repro")) {
        return RequestRepro;
    }
    
    if (needsInfo && !labelNames.contains("needs-info")) {
        return NudgeForInfo;
    }

    if (needsRepro && !labelNames.contains("needs-repro")) {
        return RequestRepro;
    }

    if (isStale) {
        return MarkStale;
    }
    
    return NoAction;
}

GitHubSweepAutomation::IssueCategory GitHubSweepAutomation::categorizeIssue(
    const QString& title,
    const QString& body,
    const QStringList& labels)
{
    QString combined = (title + " " + body).toLower();
    
    // Check labels first
    if (labels.contains("needs-info") || labels.contains("needs-information")) {
        return BugNeedsInfo;
    }
    if (labels.contains("needs-repro") || labels.contains("needs-reproduction")) {
        return BugNeedsRepro;
    }
    if (labels.contains("duplicate")) {
        return DuplicateIssue;
    }
    if (labels.contains("wontfix") || labels.contains("invalid")) {
        return Invalid;
    }
    
    // Check body keywords
    if (combined.contains("feature request") || combined.contains("feature:")) {
        return FeatureComplete;
    }
    if (combined.contains("documentation") || combined.contains("docs")) {
        return DocumentationNeeded;
    }
    
    return Invalid;
}

bool GitHubSweepAutomation::needsInformation(const QJsonObject& issue)
{
    QString body = issue.value("body").toString().toLower();
    QString title = issue.value("title").toString().toLower();
    QJsonArray comments = issue.value("comments").toArray();
    
    // Check if any comment mentions keywords
    for (const QString& keyword : m_needInfoKeywords) {
        if (body.contains(keyword)) {
            return true;
        }
        if (title.contains(keyword)) {
            return true;
        }
    }
    
    // Check comments
    for (const QJsonValue& commentValue : comments) {
        QString commentBody = commentValue.toObject().value("body").toString().toLower();
        for (const QString& keyword : m_needInfoKeywords) {
            if (commentBody.contains(keyword)) {
                return true;
            }
        }
    }
    
    return false;
}

bool GitHubSweepAutomation::needsReproduction(const QJsonObject& issue)
{
    QString body = issue.value("body").toString().toLower();
    QString title = issue.value("title").toString().toLower();
    QJsonArray comments = issue.value("comments").toArray();
    
    // Check if any comment mentions reproduction keywords
    for (const QString& keyword : m_needReproKeywords) {
        if (body.contains(keyword)) {
            return true;
        }
        if (title.contains(keyword)) {
            return true;
        }
    }
    
    // Check comments
    for (const QJsonValue& commentValue : comments) {
        QString commentBody = commentValue.toObject().value("body").toString().toLower();
        for (const QString& keyword : m_needReproKeywords) {
            if (commentBody.contains(keyword)) {
                return true;
            }
        }
    }
    
    return false;
}

bool GitHubSweepAutomation::isStaleWithoutResponse(const QJsonObject& issue)
{
    int daysSinceActivity = daysSinceLastActivity(issue);
    
    // Check if has recent response from maintainers
    QJsonArray comments = issue.value("comments").toArray();
    if (!comments.isEmpty()) {
        QJsonObject lastComment = comments.last().toObject();
        QString authorAssociation = lastComment.value("author_association").toString();
        
        // If last comment is from owner/member, not stale
        if (authorAssociation == "OWNER" || authorAssociation == "MEMBER") {
            return false;
        }
    }
    
    return daysSinceActivity >= m_daysBeforeClose;
}

GitHubSweepAutomation::SweepIssue GitHubSweepAutomation::analyzeSweepIssue(const QJsonObject& issue)
{
    SweepIssue sweep;
    sweep.number = issue.value("number").toInt();
    sweep.title = issue.value("title").toString();
    sweep.body = issue.value("body").toString();
    sweep.created = QDateTime::fromString(issue.value("created_at").toString(), Qt::ISODate);
    sweep.lastActivity = QDateTime::fromString(issue.value("updated_at").toString(), Qt::ISODate);
    sweep.daysInactive = daysSinceLastActivity(issue);
    sweep.hasReproduction = hasReproductionInfo(sweep.body);
    sweep.hasInformation = hasUserInfo(sweep.body);
    
    QJsonArray labels = issue.value("labels").toArray();
    for (const QJsonValue& label : labels) {
        sweep.labels << label.toObject().value("name").toString();
    }
    
    sweep.recommendedAction = determineSweepAction(issue);
    
    return sweep;
}

int GitHubSweepAutomation::daysSinceLastActivity(const QJsonObject& issue)
{
    QDateTime lastActivity = QDateTime::fromString(issue.value("updated_at").toString(), Qt::ISODate);
    if (!lastActivity.isValid()) {
        lastActivity = QDateTime::fromString(issue.value("created_at").toString(), Qt::ISODate);
    }
    
    return lastActivity.daysTo(QDateTime::currentDateTimeUtc());
}

bool GitHubSweepAutomation::hasReproductionInfo(const QString& body)
{
    QString lower = body.toLower();
    return lower.contains("steps to reproduce") || 
           lower.contains("expected behavior") ||
           lower.contains("actual behavior") ||
           lower.contains("reproduction") ||
           lower.contains("repro");
}

bool GitHubSweepAutomation::hasUserInfo(const QString& body)
{
    QString lower = body.toLower();
    return lower.length() > 100 &&
           (lower.contains("version") || lower.contains("environment") ||
            lower.contains("browser") || lower.contains("os"));
}

void GitHubSweepAutomation::nudgeForInformation(int issueNumber, const QString& lastCommentBy)
{
    QString message = generateInfoNudge();
    emit actionTaken(issueNumber, NudgeForInfo, message);
}

void GitHubSweepAutomation::nudgeForReproduction(int issueNumber)
{
    QString message = generateReproNudge();
    emit actionTaken(issueNumber, RequestRepro, message);
}

void GitHubSweepAutomation::markAsStale(int issueNumber)
{
    QString message = generateStaleWarning();
    emit actionTaken(issueNumber, MarkStale, message);
}

void GitHubSweepAutomation::autoCloseStale(int issueNumber, const QString& reason)
{
    QString message = reason.isEmpty() ? generateAutoCloseReason() : reason;
    emit actionTaken(issueNumber, AutoClose, message);
}

QString GitHubSweepAutomation::generateInfoNudge()
{
    return "Thanks for reporting this issue! We need a bit more information to help you better:\n\n"
           "1. Can you provide more details about your environment?\n"
           "2. Are there any error messages or logs?\n"
           "3. What steps led to this issue?\n\n"
           "With more information, we can help you more effectively.";
}

QString GitHubSweepAutomation::generateReproNudge()
{
    return "Thanks for reporting this! We're having trouble reproducing the issue. "
           "Could you provide:\n\n"
           "1. **Steps to reproduce** - specific actions to trigger the issue\n"
           "2. **Expected behavior** - what should happen\n"
           "3. **Actual behavior** - what currently happens\n"
           "4. **Minimal example** - a small code snippet or project setup\n\n"
           "A clear reproduction case helps us fix the issue faster!";
}

QString GitHubSweepAutomation::generateStaleWarning()
{
    return "This issue has been inactive for a while. If no response is provided soon, "
           "it may be automatically closed. Please feel free to reopen if you believe "
           "this is still an active issue.";
}

QString GitHubSweepAutomation::generateAutoCloseReason()
{
    return "This issue has been inactive for too long and is being automatically closed. "
           "Feel free to reopen if you'd like to continue the discussion.";
}

void GitHubSweepAutomation::setDaysBeforeNudge(int days)
{
    m_daysBeforeNudge = qMax(1, days);
}

void GitHubSweepAutomation::setDaysBeforeClose(int days)
{
    m_daysBeforeClose = qMax(1, days);
}

void GitHubSweepAutomation::setAutoCloseEnabled(bool enabled)
{
    m_autoCloseEnabled = enabled;
}

void GitHubSweepAutomation::setNeedInfoKeywords(const QStringList& keywords)
{
    m_needInfoKeywords = keywords;
}

void GitHubSweepAutomation::setNeedReproKeywords(const QStringList& keywords)
{
    m_needReproKeywords = keywords;
}

int GitHubSweepAutomation::getTotalIssuesProcessed() const
{
    return m_totalProcessed;
}

int GitHubSweepAutomation::getTotalActionsTaken() const
{
    return m_totalActions;
}

QMap<GitHubSweepAutomation::SweepAction, int> GitHubSweepAutomation::getActionStatistics() const
{
    return m_actionStats;
}
