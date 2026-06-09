#include "IssueLifecycleManager.h"
#include <QDebug>

IssueLifecycleManager::IssueLifecycleManager(QObject* parent)
    : QObject(parent) {
}

IssueLifecycleManager::~IssueLifecycleManager() {
}

void IssueLifecycleManager::registerIssuePolicies(const QVector<IssuePolicy>& policies) {
    m_policies = policies;
}

void IssueLifecycleManager::trackIssue(const Issue& issue) {
    m_issues[issue.id] = issue;
}

void IssueLifecycleManager::updateLastActivity(const QString& issueId) {
    if (m_issues.contains(issueId)) {
        m_issues[issueId].lastActivityAt = QDateTime::currentDateTime();
    }
}

QVector<IssueLifecycleManager::Issue> IssueLifecycleManager::findStaleIssues() {
    QVector<Issue> stale;
    auto now = QDateTime::currentDateTime();
    for (const auto& issue : m_issues.values()) {
        int daysSinceActivity = issue.lastActivityAt.daysTo(now);
        if (daysSinceActivity > 14 && issue.isOpen) {
            stale.append(issue);
        }
    }
    return stale;
}

QVector<IssueLifecycleManager::Issue> IssueLifecycleManager::findNeedsRepro() {
    QVector<Issue> results;
    for (const auto& issue : m_issues.values()) {
        if (issue.labels.contains("needs-repro")) {
            results.append(issue);
        }
    }
    return results;
}

QVector<IssueLifecycleManager::Issue> IssueLifecycleManager::findInvalidIssues() {
    QVector<Issue> results;
    for (const auto& issue : m_issues.values()) {
        if (issue.labels.contains("invalid")) {
            results.append(issue);
        }
    }
    return results;
}

void IssueLifecycleManager::autoCloseIssue(const QString& issueId) {
    if (m_issues.contains(issueId)) {
        m_issues[issueId].isOpen = false;
        emit issueAutoClosed(issueId);
    }
}

void IssueLifecycleManager::sendNudgeMessage(const QString& issueId) {
    if (m_issues.contains(issueId)) {
        emit nudgeMessageSent(issueId);
    }
}

void IssueLifecycleManager::labelIssue(const QString& issueId, LifecycleLabel label) {
    if (m_issues.contains(issueId)) {
        QString labelStr;
        switch (label) {
        case Invalid:
            labelStr = "invalid";
            break;
        case NeedsRepro:
            labelStr = "needs-repro";
            break;
        case NeedsInfo:
            labelStr = "needs-info";
            break;
        case Stale:
            labelStr = "stale";
            break;
        case Autoclose:
            labelStr = "autoclose";
            break;
        }
        if (!m_issues[issueId].labels.contains(labelStr)) {
            m_issues[issueId].labels.append(labelStr);
        }
    }
}

IssueLifecycleManager::LifecycleReport IssueLifecycleManager::generateReport() {
    LifecycleReport report;
    report.totalIssues = m_issues.size();
    report.activeIssues = 0;
    report.staleIssues = 0;
    report.invalidIssues = 0;
    report.needsReproIssues = 0;
    report.needsInfoIssues = 0;

    for (const auto& issue : m_issues.values()) {
        if (issue.isOpen) {
            report.activeIssues++;
        }
        if (issue.labels.contains("stale")) report.staleIssues++;
        if (issue.labels.contains("invalid")) report.invalidIssues++;
        if (issue.labels.contains("needs-repro")) report.needsReproIssues++;
        if (issue.labels.contains("needs-info")) report.needsInfoIssues++;
    }

    return report;
}
