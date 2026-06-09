#include "IssueActivityMonitor.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonArray>
#include <QEventLoop>
#include <QTimer>

const QVector<QString> IssueActivityMonitor::DEFAULT_STALE_LABELS = {"stale", "needs-repro", "needs-info"};
const QString IssueActivityMonitor::STALE_LABEL = "stale";
const QString IssueActivityMonitor::AUTOCLOSE_LABEL = "autoclose";

IssueActivityMonitor::IssueActivityMonitor(QObject* parent)
    : QObject(parent)
{
    // Initialize monitoring state
}

IssueActivityMonitor::~IssueActivityMonitor()
{
    stopMonitoring();
}

void IssueActivityMonitor::startMonitoring(const MonitorConfig& config)
{
    m_config = config;
    m_isMonitoring = true;
    m_isPaused = false;
    m_totalProcessed = 0;
    m_totalMarkedStale = 0;
    m_totalClosed = 0;

    qInfo() << "[Monitor] Starting issue activity monitoring";
    qInfo() << QString("  Stale threshold: %1 days").arg(m_config.staleDays);
    qInfo() << QString("  Close threshold: %1 days").arg(m_config.closeExpirationDays);
    qInfo() << QString("  Upvote preservation: %1+").arg(m_config.upvoteThresholdForPreservation);

    emit monitoringStarted();

    // Start monitoring passes
    processStalePass();
    processExpirePass();
}

void IssueActivityMonitor::stopMonitoring()
{
    m_isMonitoring = false;
    m_isPaused = false;
    logStatistics();
    emit monitoringStopped();
    qInfo() << "[Monitor] Monitoring stopped";
}

void IssueActivityMonitor::pauseMonitoring()
{
    m_isPaused = true;
    emit monitoringPaused();
    qInfo() << "[Monitor] Monitoring paused";
}

void IssueActivityMonitor::resumeMonitoring()
{
    m_isPaused = false;
    emit monitoringResumed();
    qInfo() << "[Monitor] Monitoring resumed";
}

int IssueActivityMonitor::markStaleIssues(const MonitorConfig& config)
{
    int marked = 0;
    QDateTime cutoff = QDateTime::currentDateTime().addDays(-config.staleDays);

    qInfo() << QString("[Monitor] Marking stale issues (>%1 days inactive)").arg(config.staleDays);

    // In production, fetch issues from GitHub API and mark them
    // /repos/{owner}/{repo}/issues?state=open&sort=updated&direction=asc&per_page=100

    for (auto it = m_issueStates.begin(); it != m_issueStates.end(); ++it) {
        IssueState& state = it.value();

        if (state.state != "open") continue;
        if (state.assigneeCount > 0 && !config.processAssignedIssues) continue;
        if (state.labels.contains(STALE_LABEL)) continue;

        if (state.lastActivityAt < cutoff && !shouldPreserveIssue(state, config)) {
            markAsStale(state.number);
            marked++;
            emit issuMarkedStale(state.number);
        }
    }

    m_totalMarkedStale += marked;
    return marked;
}

int IssueActivityMonitor::closeExpiredIssues(const MonitorConfig& config)
{
    int closed = 0;

    qInfo() << QString("[Monitor] Closing expired issues (%1 days timeout)").arg(config.closeExpirationDays);

    for (auto it = m_issueStates.begin(); it != m_issueStates.end(); ++it) {
        IssueState& state = it.value();

        if (state.state != "open") continue;
        if (!state.labels.contains(STALE_LABEL) && !state.labels.contains(AUTOCLOSE_LABEL)) continue;

        if (shouldPreserveIssue(state, config)) continue;

        // Check if has recent human activity
        QDateTime labeledTime = getIssueLastLabelTime(state.number, STALE_LABEL);
        if (!labeledTime.isValid()) labeledTime = getIssueLastLabelTime(state.number, AUTOCLOSE_LABEL);

        if (labeledTime.isValid()) {
            QDateTime expiry = labeledTime.addDays(config.closeExpirationDays);
            if (QDateTime::currentDateTime() >= expiry && !hasRecentHumanComment(state.number, labeledTime)) {
                closeIssueAsNotPlanned(state.number, "Closing due to inactivity");
                closed++;
                emit issueClosed(state.number);
            }
        }
    }

    m_totalClosed += closed;
    return closed;
}

void IssueActivityMonitor::recordActivity(const ActivityEvent& event)
{
    m_activityLog.append(event);

    // Update issue state if tracking it
    if (m_issueStates.contains(event.issueNumber)) {
        IssueState& state = m_issueStates[event.issueNumber];
        state.lastActivityAt = event.timestamp;
        state.recentActivity.append(event);

        // Keep only last 100 activities
        if (state.recentActivity.size() > 100) {
            state.recentActivity.remove(0);
        }
    }

    emit activityDetected(event.issueNumber, QString::number(static_cast<int>(event.type)));
}

QVector<IssueActivityMonitor::ActivityEvent> IssueActivityMonitor::getRecentActivity(int issueNumber, int maxDays)
{
    QVector<ActivityEvent> recent;
    QDateTime cutoff = QDateTime::currentDateTime().addDays(-maxDays);

    if (m_issueStates.contains(issueNumber)) {
        const IssueState& state = m_issueStates[issueNumber];
        for (const ActivityEvent& event : state.recentActivity) {
            if (event.timestamp > cutoff) {
                recent.append(event);
            }
        }
    }

    return recent;
}

bool IssueActivityMonitor::isStaleIssue(const IssueState& issue, const MonitorConfig& config)
{
    QDateTime cutoff = QDateTime::currentDateTime().addDays(-config.staleDays);
    return issue.state == "open" && issue.lastActivityAt < cutoff;
}

bool IssueActivityMonitor::shouldPreserveIssue(const IssueState& issue, const MonitorConfig& config)
{
    // Preserve if high upvote count
    if (issue.upvoteCount >= config.upvoteThresholdForPreservation) {
        return true;
    }

    // Preserve if assigned
    if (issue.assigneeCount > 0) {
        return true;
    }

    return false;
}

bool IssueActivityMonitor::hasHumanActivitySince(int issueNumber, const QDateTime& sinceTime)
{
    return hasRecentHumanComment(issueNumber, sinceTime);
}

IssueActivityMonitor::IssueState IssueActivityMonitor::getIssueState(int issueNumber)
{
    if (m_issueStates.contains(issueNumber)) {
        return m_issueStates[issueNumber];
    }

    IssueState state;
    state.number = issueNumber;
    return state;
}

void IssueActivityMonitor::updateIssueState(const IssueState& state)
{
    m_issueStates[state.number] = state;
}

void IssueActivityMonitor::markAsStale(int issueNumber)
{
    if (m_issueStates.contains(issueNumber)) {
        m_issueStates[issueNumber].labels.insert(STALE_LABEL);
    }
    qInfo() << QString("[Monitor] Marked issue #%1 as stale").arg(issueNumber);
}

void IssueActivityMonitor::markForAutoclose(int issueNumber)
{
    if (m_issueStates.contains(issueNumber)) {
        m_issueStates[issueNumber].labels.insert(AUTOCLOSE_LABEL);
    }
    qInfo() << QString("[Monitor] Marked issue #%1 for autoclose").arg(issueNumber);
    emit issuMarkedForAutoClose(issueNumber);
}

void IssueActivityMonitor::removeStaleLabel(int issueNumber)
{
    if (m_issueStates.contains(issueNumber)) {
        m_issueStates[issueNumber].labels.remove(STALE_LABEL);
    }
}

void IssueActivityMonitor::closeIssueAsNotPlanned(int issueNumber, const QString& reason)
{
    emit issueClosing(issueNumber);
    postCloseMessage(issueNumber, reason);
    
    if (m_issueStates.contains(issueNumber)) {
        m_issueStates[issueNumber].state = "closed";
        m_issueStates[issueNumber].stateReason = "not_planned";
    }

    qInfo() << QString("[Monitor] Closed issue #%1: %2").arg(issueNumber).arg(reason);
}

void IssueActivityMonitor::postCloseMessage(int issueNumber, const QString& reason)
{
    QString message = QString("Closing for now — %1. Please open a new issue if this is still relevant.").arg(reason);
    qInfo() << QString("[Monitor] Posting close message on issue #%1").arg(issueNumber);
}

int IssueActivityMonitor::getUpvoteCount(int issueNumber)
{
    if (m_issueStates.contains(issueNumber)) {
        return m_issueStates[issueNumber].upvoteCount;
    }
    return 0;
}

QJsonObject IssueActivityMonitor::getMonitoringStatistics() const
{
    QJsonObject stats;
    stats["isMonitoring"] = m_isMonitoring;
    stats["isPaused"] = m_isPaused;
    stats["totalProcessed"] = m_totalProcessed;
    stats["totalMarkedStale"] = m_totalMarkedStale;
    stats["totalClosed"] = m_totalClosed;
    stats["cachedIssueStates"] = static_cast<int>(m_issueStates.size());
    stats["activityLogSize"] = static_cast<int>(m_activityLog.size());
    return stats;
}

QVector<IssueActivityMonitor::IssueState> IssueActivityMonitor::getStaleIssues(const MonitorConfig& config)
{
    QVector<IssueState> staleIssues;
    for (auto it = m_issueStates.begin(); it != m_issueStates.end(); ++it) {
        if (isStaleIssue(it.value(), config)) {
            staleIssues.append(it.value());
        }
    }
    return staleIssues;
}

QVector<IssueActivityMonitor::IssueState> IssueActivityMonitor::getExpiredIssues(const MonitorConfig& config)
{
    QVector<IssueState> expiredIssues;
    for (auto it = m_issueStates.begin(); it != m_issueStates.end(); ++it) {
        const IssueState& state = it.value();
        if (state.labels.contains(STALE_LABEL) || state.labels.contains(AUTOCLOSE_LABEL)) {
            expiredIssues.append(state);
        }
    }
    return expiredIssues;
}

int IssueActivityMonitor::processIssuesPaginatedStale(const MonitorConfig& config)
{
    return markStaleIssues(config);
}

int IssueActivityMonitor::processIssuesPaginatedExpired(const MonitorConfig& config)
{
    return closeExpiredIssues(config);
}

bool IssueActivityMonitor::shouldSkipIssue(const IssueState& issue, const MonitorConfig& config)
{
    return isAssignedOrLocked(issue, config);
}

bool IssueActivityMonitor::isAssignedOrLocked(const IssueState& issue, const MonitorConfig& config)
{
    if (issue.assigneeCount > 0 && !config.processAssignedIssues) {
        return true;
    }
    // Locked check would go here
    return false;
}

QDateTime IssueActivityMonitor::getLastActivityTime(int issueNumber)
{
    if (m_issueStates.contains(issueNumber)) {
        return m_issueStates[issueNumber].lastActivityAt;
    }
    return QDateTime();
}

int IssueActivityMonitor::getDaysSinceActivity(int issueNumber)
{
    QDateTime lastActivity = getLastActivityTime(issueNumber);
    if (lastActivity.isValid()) {
        return lastActivity.daysTo(QDateTime::currentDateTime());
    }
    return -1;
}

void IssueActivityMonitor::processStalePass()
{
    qInfo() << "[Monitor] Starting stale pass...";
    markStaleIssues(m_config);
}

void IssueActivityMonitor::processExpirePass()
{
    qInfo() << "[Monitor] Starting expire pass...";
    closeExpiredIssues(m_config);
}

bool IssueActivityMonitor::hasRecentHumanComment(int issueNumber, const QDateTime& sinceTime)
{
    if (m_issueStates.contains(issueNumber)) {
        const IssueState& state = m_issueStates[issueNumber];
        for (const ActivityEvent& event : state.recentActivity) {
            if (event.isHumanActivity && event.timestamp > sinceTime && event.type == Comment) {
                return true;
            }
        }
    }
    return false;
}

QDateTime IssueActivityMonitor::getIssueLastLabelTime(int issueNumber, const QString& label)
{
    if (m_issueStates.contains(issueNumber)) {
        const IssueState& state = m_issueStates[issueNumber];
        for (int i = state.recentActivity.size() - 1; i >= 0; --i) {
            if (state.recentActivity[i].type == Label && state.recentActivity[i].details == label) {
                return state.recentActivity[i].timestamp;
            }
        }
    }
    return QDateTime();
}

void IssueActivityMonitor::pruneOldActivityLogs()
{
    QDateTime oneMonthAgo = QDateTime::currentDateTime().addMonths(-1);
    
    QVector<ActivityEvent> pruned;
    for (const ActivityEvent& event : m_activityLog) {
        if (event.timestamp > oneMonthAgo) {
            pruned.append(event);
        }
    }
    
    m_activityLog = pruned;
    qInfo() << QString("[Monitor] Pruned activity log, now %1 entries").arg(m_activityLog.size());
}

void IssueActivityMonitor::logStatistics()
{
    qInfo() << "[Monitor] === Monitoring Session Statistics ===";
    qInfo() << QString("  Total processed: %1").arg(m_totalProcessed);
    qInfo() << QString("  Total marked stale: %1").arg(m_totalMarkedStale);
    qInfo() << QString("  Total closed: %1").arg(m_totalClosed);
    qInfo() << QString("  Cached issues: %1").arg(m_issueStates.size());
    qInfo() << QString("  Activity log entries: %1").arg(m_activityLog.size());
}
