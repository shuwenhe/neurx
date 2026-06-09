#include "IssueLifecycleRulesEngine.h"
#include <QDebug>
#include <QDateTime>

IssueLifecycleRulesEngine::IssueLifecycleRulesEngine(QObject* parent)
    : QObject(parent), m_autoTransitionEnabled(true), m_maxInactivityDays(30), m_staleUpvoteThreshold(10)
{
    // Initialize with default policies
    QVector<LifecyclePolicy> defaultPolicies;
    
    defaultPolicies.append({
        Invalid,
        3,
        "this doesn't appear to be about Claude Code",
        "This doesn't appear to be about Claude Code. For general support, visit support.anthropic.com."
    });
    
    defaultPolicies.append({
        NeedsRepro,
        7,
        "we still need reproduction steps to investigate",
        "We weren't able to reproduce this. Could you provide steps to trigger the issue?"
    });
    
    defaultPolicies.append({
        NeedsInfo,
        7,
        "we still need a bit more information to move forward",
        "We need more information to continue investigating. Can you provide your Claude Code version and OS?"
    });
    
    defaultPolicies.append({
        Stale,
        14,
        "inactive for too long",
        "This issue has been automatically marked as stale due to inactivity."
    });
    
    defaultPolicies.append({
        Autoclose,
        14,
        "inactive for too long",
        "This issue has been marked for automatic closure."
    });
    
    registerPolicies(defaultPolicies);
}

IssueLifecycleRulesEngine::~IssueLifecycleRulesEngine()
{
}

void IssueLifecycleRulesEngine::registerPolicies(const QVector<LifecyclePolicy>& policies)
{
    m_policies.clear();
    for (const LifecyclePolicy& policy : policies) {
        addPolicy(policy);
    }
}

void IssueLifecycleRulesEngine::addPolicy(const LifecyclePolicy& policy)
{
    m_policies.append(policy);
    emit policyRegistered(labelToString(policy.label));
}

IssueLifecycleRulesEngine::LifecyclePolicy IssueLifecycleRulesEngine::getPolicy(LifecycleLabel label) const
{
    for (const LifecyclePolicy& policy : m_policies) {
        if (policy.label == label) {
            return policy;
        }
    }
    return {Invalid, 0, "", ""};
}

QVector<IssueLifecycleRulesEngine::LifecyclePolicy> IssueLifecycleRulesEngine::getAllPolicies() const
{
    return m_policies;
}

void IssueLifecycleRulesEngine::trackIssue(int issueNumber, LifecycleLabel initialLabel)
{
    m_issueStates[issueNumber] = initialLabel;
    m_lastActivity[issueNumber] = QDateTime::currentDateTimeUtc();
    emit issueTracked(issueNumber);
}

void IssueLifecycleRulesEngine::updateIssueState(int issueNumber, LifecycleLabel newLabel)
{
    if (!m_issueStates.contains(issueNumber)) {
        trackIssue(issueNumber, newLabel);
        return;
    }
    
    LifecycleLabel oldLabel = m_issueStates[issueNumber];
    m_issueStates[issueNumber] = newLabel;
    
    IssueTransition transition;
    transition.issueNumber = issueNumber;
    transition.fromLabel = oldLabel;
    transition.toLabel = newLabel;
    transition.transitionTime = QDateTime::currentDateTimeUtc();
    transition.reason = getPolicy(newLabel).reason;
    
    m_transitionHistory.append(transition);
    
    emit stateTransitioned(issueNumber, labelToString(oldLabel), labelToString(newLabel));
}

IssueLifecycleRulesEngine::LifecycleLabel IssueLifecycleRulesEngine::getCurrentState(int issueNumber) const
{
    return m_issueStates.value(issueNumber, Invalid);
}

QDateTime IssueLifecycleRulesEngine::getLastActivity(int issueNumber) const
{
    return m_lastActivity.value(issueNumber, QDateTime());
}

void IssueLifecycleRulesEngine::recordActivity(int issueNumber)
{
    m_lastActivity[issueNumber] = QDateTime::currentDateTimeUtc();
    emit activityRecorded(issueNumber);
}

IssueLifecycleRulesEngine::LifecycleLabel IssueLifecycleRulesEngine::evaluatePolicy(int issueNumber) const
{
    if (!m_issueStates.contains(issueNumber)) {
        return Invalid;
    }
    
    int daysSince = daysSinceLastActivity(issueNumber);
    LifecycleLabel currentState = m_issueStates.value(issueNumber);
    
    // Evaluate policies in priority order
    if (daysSince >= 30) {
        return Autoclose;
    }
    
    if (daysSince >= 14 && currentState != Autoclose) {
        return Stale;
    }
    
    if (daysSince >= 7 && (currentState == NeedsRepro || currentState == NeedsInfo)) {
        return currentState;
    }
    
    if (daysSince >= 3 && currentState == Invalid) {
        return Invalid;
    }
    
    return currentState;
}

bool IssueLifecycleRulesEngine::shouldTransition(int issueNumber) const
{
    if (!m_issueStates.contains(issueNumber)) {
        return false;
    }
    
    LifecycleLabel currentState = m_issueStates.value(issueNumber);
    LifecycleLabel recommendedState = evaluatePolicy(issueNumber);
    
    return currentState != recommendedState;
}

QVector<IssueLifecycleRulesEngine::IssueTransition> IssueLifecycleRulesEngine::evaluateAllIssues()
{
    QVector<IssueTransition> recommendedTransitions;
    
    for (auto it = m_issueStates.begin(); it != m_issueStates.end(); ++it) {
        int issueNumber = it.key();
        
        if (shouldTransition(issueNumber)) {
            LifecycleLabel recommendedState = evaluatePolicy(issueNumber);
            
            IssueTransition transition;
            transition.issueNumber = issueNumber;
            transition.fromLabel = m_issueStates.value(issueNumber);
            transition.toLabel = recommendedState;
            transition.transitionTime = QDateTime::currentDateTimeUtc();
            transition.reason = getPolicy(recommendedState).reason;
            
            recommendedTransitions.append(transition);
            
            if (m_autoTransitionEnabled) {
                updateIssueState(issueNumber, recommendedState);
            }
        }
    }
    
    return recommendedTransitions;
}

QString IssueLifecycleRulesEngine::generateNudgeMessage(LifecycleLabel label) const
{
    LifecyclePolicy policy = getPolicy(label);
    return policy.nudgeMessage;
}

QString IssueLifecycleRulesEngine::generateCloseReason(LifecycleLabel label) const
{
    LifecyclePolicy policy = getPolicy(label);
    return QString("Automatically closed: %1").arg(policy.reason);
}

QString IssueLifecycleRulesEngine::generateStatusUpdate(int issueNumber, LifecycleLabel label) const
{
    QString status = labelToString(label);
    return QString("Issue #%1 status updated to: %2\n%3")
        .arg(issueNumber)
        .arg(status)
        .arg(generateNudgeMessage(label));
}

void IssueLifecycleRulesEngine::setStaleUpvoteThreshold(int threshold)
{
    m_staleUpvoteThreshold = qMax(0, threshold);
}

void IssueLifecycleRulesEngine::setAutoTransitionEnabled(bool enabled)
{
    m_autoTransitionEnabled = enabled;
}

void IssueLifecycleRulesEngine::setMaxInactivityDays(int days)
{
    m_maxInactivityDays = qMax(1, days);
}

int IssueLifecycleRulesEngine::getIssueCount() const
{
    return m_issueStates.count();
}

int IssueLifecycleRulesEngine::getIssueCountByLabel(LifecycleLabel label) const
{
    int count = 0;
    for (auto it = m_issueStates.begin(); it != m_issueStates.end(); ++it) {
        if (it.value() == label) {
            count++;
        }
    }
    return count;
}

QMap<IssueLifecycleRulesEngine::LifecycleLabel, int> IssueLifecycleRulesEngine::getStatistics() const
{
    QMap<LifecycleLabel, int> stats;
    
    for (auto it = m_issueStates.begin(); it != m_issueStates.end(); ++it) {
        stats[it.value()]++;
    }
    
    return stats;
}

QVector<IssueLifecycleRulesEngine::IssueTransition> IssueLifecycleRulesEngine::getRecentTransitions(int count) const
{
    int startIndex = qMax(0, (int)m_transitionHistory.size() - count);
    return m_transitionHistory.mid(startIndex);
}

QString IssueLifecycleRulesEngine::labelToString(LifecycleLabel label) const
{
    switch (label) {
        case Invalid: return "invalid";
        case NeedsRepro: return "needs-repro";
        case NeedsInfo: return "needs-info";
        case Stale: return "stale";
        case Autoclose: return "autoclose";
    }
    return "unknown";
}

IssueLifecycleRulesEngine::LifecycleLabel IssueLifecycleRulesEngine::stringToLabel(const QString& str) const
{
    if (str == "invalid") return Invalid;
    if (str == "needs-repro") return NeedsRepro;
    if (str == "needs-info") return NeedsInfo;
    if (str == "stale") return Stale;
    if (str == "autoclose") return Autoclose;
    return Invalid;
}

int IssueLifecycleRulesEngine::daysSinceLastActivity(int issueNumber) const
{
    if (!m_lastActivity.contains(issueNumber)) {
        return 0;
    }
    
    QDateTime lastActivity = m_lastActivity.value(issueNumber);
    return lastActivity.daysTo(QDateTime::currentDateTimeUtc());
}
