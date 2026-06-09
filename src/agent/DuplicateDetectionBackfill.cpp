#include "DuplicateDetectionBackfill.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonArray>
#include <QEventLoop>
#include <QTimer>

DuplicateDetectionBackfill::DuplicateDetectionBackfill(QObject* parent)
    : QObject(parent)
{
    // Initialize any required resources
}

DuplicateDetectionBackfill::~DuplicateDetectionBackfill()
{
    // Cleanup
}

void DuplicateDetectionBackfill::startBackfill(const BackfillConfig& config)
{
    m_config = config;
    m_isRunning = true;
    m_isPaused = false;
    m_totalProcessed = 0;
    m_totalTriggered = 0;
    m_currentPage = 1;
    m_detectionStatusCache.clear();

    // Estimate total issues in range
    int estimatedTotal = m_config.maxIssueNumber - m_config.minIssueNumber;
    emit backfillStarted(estimatedTotal);

    qInfo() << "[Backfill] Starting duplicate detection backfill";
    qInfo() << QString("  Range: #%1 - #%2").arg(m_config.minIssueNumber).arg(m_config.maxIssueNumber);
    qInfo() << QString("  Dry run: %1").arg(m_config.dryRunMode ? "true" : "false");
    qInfo() << QString("  Skip existing comments: %1").arg(m_config.skipWithExistingComments ? "true" : "false");

    // Process pages
    while (m_isRunning && m_currentPage <= m_config.maxPages) {
        if (m_isPaused) {
            QEventLoop loop;
            QTimer timer;
            connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
            timer.start(100);
            loop.exec();
            continue;
        }

        // Fetch page of issues
        QVector<IssueData> issues = fetchIssuesPage(m_currentPage, m_config);
        if (issues.isEmpty()) {
            break;
        }

        // Process batch
        int batchTriggered = processIssueBatch(issues, m_config);
        m_totalTriggered += batchTriggered;

        // Report progress
        emit backfillProgress(m_totalProcessed, estimatedTotal);

        // Add delay between requests
        QEventLoop loop;
        QTimer timer;
        connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
        timer.start(m_config.delayBetweenRequests);
        loop.exec();

        m_currentPage++;
    }

    if (m_isRunning) {
        m_isRunning = false;
        logProgress(m_totalProcessed, estimatedTotal, m_totalTriggered);
        emit backfillCompleted(m_totalProcessed, m_totalTriggered);
    }
}

void DuplicateDetectionBackfill::pauseBackfill()
{
    m_isPaused = true;
    emit backfillPaused();
    qInfo() << "[Backfill] Backfill paused";
}

void DuplicateDetectionBackfill::resumeBackfill()
{
    m_isPaused = false;
    emit backfillResumed();
    qInfo() << "[Backfill] Backfill resumed";
}

void DuplicateDetectionBackfill::cancelBackfill()
{
    m_isRunning = false;
    m_isPaused = false;
    emit backfillCancelled();
    qInfo() << "[Backfill] Backfill cancelled";
}

bool DuplicateDetectionBackfill::shouldProcessIssue(const IssueData& issue, const BackfillConfig& config)
{
    // Skip if outside range
    if (issue.number < config.minIssueNumber || issue.number >= config.maxIssueNumber) {
        return false;
    }

    // Skip if only processing open issues and this one is closed
    if (config.processOpenOnly && issue.state == "closed") {
        return false;
    }

    // Skip if has existing duplicate detection comment
    if (config.skipWithExistingComments && hasDuplicateDetectionComment(issue.number)) {
        return false;
    }

    // Skip very new issues
    QDateTime oneWeekAgo = QDateTime::currentDateTime().addDays(-7);
    if (issue.createdAt > oneWeekAgo) {
        return false;
    }

    return true;
}

bool DuplicateDetectionBackfill::hasDuplicateDetectionComment(int issueNumber)
{
    // Check cache first
    if (m_detectionStatusCache.contains(issueNumber)) {
        return m_detectionStatusCache[issueNumber].hasDuplicateComment;
    }

    // In production, would fetch comments from GitHub API
    // For now, return false
    return false;
}

bool DuplicateDetectionBackfill::triggerDedupeWorkflow(int issueNumber, bool dryRun)
{
    if (dryRun) {
        qInfo() << QString("[DRY RUN] Would trigger dedupe workflow for issue #%1").arg(issueNumber);
        return true;
    }

    try {
        dispatchWorkflow(issueNumber, "claude-dedupe-issues.yml");
        qInfo() << QString("[Backfill] Triggered dedupe workflow for issue #%1").arg(issueNumber);
        return true;
    } catch (const std::exception& e) {
        logError(issueNumber, QString::fromStdString(e.what()));
        return false;
    }
}

DuplicateDetectionBackfill::DetectionStatus DuplicateDetectionBackfill::getDetectionStatus(int issueNumber)
{
    if (m_detectionStatusCache.contains(issueNumber)) {
        return m_detectionStatusCache[issueNumber];
    }

    DetectionStatus status;
    status.issueNumber = issueNumber;
    status.hasDuplicateComment = false;
    status.workflowTriggered = false;

    return status;
}

int DuplicateDetectionBackfill::processIssueBatch(const QVector<IssueData>& issues, const BackfillConfig& config)
{
    int triggered = 0;

    for (const IssueData& issue : issues) {
        m_totalProcessed++;

        if (!shouldProcessIssue(issue, config)) {
            continue;
        }

        // Validate issue
        if (!validateIssue(issue)) {
            logError(issue.number, "Invalid issue data");
            continue;
        }

        // Skip if we should
        if (shouldSkip(issue)) {
            continue;
        }

        // Trigger workflow
        if (triggerDedupeWorkflow(issue.number, config.dryRunMode)) {
            triggered++;
            emit issueProcessed(issue.number, true);
            emit duplicateDetectionTriggered(issue.number);

            // Update cache
            DetectionStatus status;
            status.issueNumber = issue.number;
            status.hasDuplicateComment = true;
            status.workflowTriggered = true;
            status.commentDetectedAt = QDateTime::currentDateTime();
            m_detectionStatusCache[issue.number] = status;
        } else {
            emit issueProcessed(issue.number, false);
        }
    }

    return triggered;
}

QJsonObject DuplicateDetectionBackfill::getStatistics() const
{
    QJsonObject stats;
    stats["totalProcessed"] = m_totalProcessed;
    stats["totalTriggered"] = m_totalTriggered;
    stats["currentPage"] = m_currentPage;
    stats["isRunning"] = m_isRunning;
    stats["isPaused"] = m_isPaused;
    stats["cachedStatuses"] = static_cast<int>(m_detectionStatusCache.size());

    return stats;
}

QVector<DuplicateDetectionBackfill::IssueData> DuplicateDetectionBackfill::fetchIssuesPage(int page, const BackfillConfig& config)
{
    QVector<IssueData> issues;

    // In production, this would fetch from GitHub API
    // /repos/{owner}/{repo}/issues?state=all&per_page={config.perPage}&page={page}&sort=created&direction=desc
    
    // For now, return empty to indicate end of results
    return issues;
}

void DuplicateDetectionBackfill::dispatchWorkflow(int issueNumber, const QString& workflowId)
{
    // In production, this would call GitHub Actions API
    // POST /repos/{owner}/{repo}/actions/workflows/{workflowId}/dispatches
    
    qInfo() << QString("[Backfill] Dispatching workflow %1 for issue #%2").arg(workflowId).arg(issueNumber);
}

void DuplicateDetectionBackfill::logProgress(int processed, int total, int triggered)
{
    qInfo() << QString("[Backfill] Completed backfill: processed %1/%2, triggered %3 workflows")
               .arg(processed).arg(total).arg(triggered);
}

void DuplicateDetectionBackfill::logError(int issueNumber, const QString& error)
{
    qWarning() << QString("[Backfill] Error processing issue #%1: %2").arg(issueNumber).arg(error);
    emit errorOccurred(QString("Error processing issue #%1: %2").arg(issueNumber).arg(error));
}

bool DuplicateDetectionBackfill::validateIssue(const IssueData& issue) const
{
    return issue.number > 0 && !issue.title.isEmpty() && issue.userId > 0;
}

bool DuplicateDetectionBackfill::shouldSkip(const IssueData& issue) const
{
    // Skip if already marked as duplicate
    if (issue.isDuplicate) {
        return true;
    }

    // Skip very recent issues
    QDateTime oneWeekAgo = QDateTime::currentDateTime().addDays(-7);
    if (issue.createdAt > oneWeekAgo) {
        return true;
    }

    return false;
}

void DuplicateDetectionBackfill::updateStatistics(bool wasTriggered)
{
    if (wasTriggered) {
        m_totalTriggered++;
    }
}

QDateTime DuplicateDetectionBackfill::parseGitHubTimestamp(const QString& timestamp)
{
    // Parse ISO 8601 timestamp: 2024-01-15T10:30:45Z
    return QDateTime::fromString(timestamp, Qt::ISODate);
}
