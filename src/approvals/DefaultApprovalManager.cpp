#include "DefaultApprovalManager.h"
#include <QDebug>
#include <QDateTime>
#include <QUuid>

DefaultApprovalManager::DefaultApprovalManager(QObject *parent)
    : ApprovalManager(parent)
{
    // Initialize default policy
    m_defaultPolicy.defaultPolicy = AskForApproval::OnRequest;
    m_defaultPolicy.defaultReviewer = ApprovalsReviewer::User;
}

void DefaultApprovalManager::setDefaultPolicy(const ApprovalPolicy &policy)
{
    QMutexLocker locker(&m_mutex);
    m_defaultPolicy = policy;
    locker.unlock();
    emit policyChanged();
}

ApprovalPolicy DefaultApprovalManager::getDefaultPolicy() const
{
    QMutexLocker locker(&m_mutex);
    return m_defaultPolicy;
}

void DefaultApprovalManager::addGranularRule(const GranularApprovalConfig &rule)
{
    QMutexLocker locker(&m_mutex);
    m_granularRules.append(rule);
    locker.unlock();
    emit policyChanged();
}

void DefaultApprovalManager::removeGranularRule(const QString &resourcePattern)
{
    QMutexLocker locker(&m_mutex);
    m_granularRules.erase(
        std::remove_if(m_granularRules.begin(), m_granularRules.end(),
                      [&](const GranularApprovalConfig &rule) {
                          return rule.resourcePattern == resourcePattern;
                      }),
        m_granularRules.end());
    locker.unlock();
    emit policyChanged();
}

void DefaultApprovalManager::requestExecApproval(const ExecApprovalRequestEvent &request,
                                                 std::function<void(bool approved, ApprovalDecision decision)> callback)
{
    if (m_readOnlyMode) {
        if (callback) {
            callback(false, ApprovalDecision::Reject);
        }
        return;
    }
    
    QMutexLocker locker(&m_mutex);
    
    QString approvalId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    
    PendingApproval pending;
    pending.id = approvalId;
    pending.request = request;
    pending.requestedAt = QDateTime::currentDateTime();
    m_pendingApprovals[approvalId] = pending;
    
    AskForApproval policy = getPolicyFor_impl(request.toolName, request.command);
    
    locker.unlock();
    
    emit approvalRequested(approvalId, QVariantMap{
        {"toolName", request.toolName},
        {"command", request.command},
        {"context", request.context}
    });
    
    // Simulate immediate approval based on policy
    bool approved = (policy != AskForApproval::Never);
    ApprovalDecision decision = approved ? ApprovalDecision::Accept : ApprovalDecision::Reject;
    
    if (callback) {
        callback(approved, decision);
    }
    
    recordDecision(approvalId, decision, "Policy-based decision");
}

void DefaultApprovalManager::requestNetworkApproval(const NetworkApprovalContext &context,
                                                    std::function<void(bool approved, ApprovalDecision decision)> callback)
{
    if (m_readOnlyMode) {
        if (callback) {
            callback(false, ApprovalDecision::Reject);
        }
        return;
    }
    
    QMutexLocker locker(&m_mutex);
    
    QString approvalId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    
    AskForApproval policy = m_defaultPolicy.defaultPolicy;
    
    // Check granular rules for network patterns
    for (const auto &rule : m_granularRules) {
        if (context.targetHost.contains(rule.resourcePattern)) {
            policy = rule.policy;
            break;
        }
    }
    
    locker.unlock();
    
    bool approved = (policy != AskForApproval::Never);
    ApprovalDecision decision = approved ? ApprovalDecision::Accept : ApprovalDecision::Reject;
    
    if (callback) {
        callback(approved, decision);
    }
}

void DefaultApprovalManager::requestGuardianAssessment(const ExecApprovalRequestEvent &request,
                                                       std::function<void(GuardianAssessmentEvent)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    GuardianAssessmentEvent assessment;
    assessment.eventId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    assessment.assessedAt = QDateTime::currentDateTime();
    assessment.command = request.command;
    assessment.riskLevel = RiskLevel::Medium; // Default assessment
    
    m_assessmentHistory.append(assessment);
    
    locker.unlock();
    
    if (callback) {
        callback(assessment);
    }
}

bool DefaultApprovalManager::requiresApproval(const QString &action, const QString &toolName) const
{
    AskForApproval policy = getPolicyFor(toolName, action);
    return policy != AskForApproval::Never;
}

AskForApproval DefaultApprovalManager::getPolicyFor(const QString &toolName, const QString &resource) const
{
    QMutexLocker locker(&m_mutex);
    return getPolicyFor_impl(toolName, resource);
}

AskForApproval DefaultApprovalManager::getPolicyFor_impl(const QString &toolName, const QString &resource) const
{
    // Check granular rules first
    for (const auto &rule : m_granularRules) {
        if (rule.toolName == toolName && resource.contains(rule.resourcePattern)) {
            return rule.policy;
        }
    }
    
    // Fall back to default policy
    return m_defaultPolicy.defaultPolicy;
}

bool DefaultApprovalManager::checkGranularRules(const QString &toolName, const QString &resource) const
{
    for (const auto &rule : m_granularRules) {
        if (rule.toolName == toolName && resource.contains(rule.resourcePattern)) {
            return true;
        }
    }
    return false;
}

void DefaultApprovalManager::recordDecision(const QString &approvalId,
                                           ApprovalDecision decision,
                                           const QString &reason)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_pendingApprovals.find(approvalId);
    if (it != m_pendingApprovals.end()) {
        it->processed = true;
        
        if (decision == ApprovalDecision::Accept) {
            m_stats.approvedCount++;
        } else if (decision == ApprovalDecision::Reject) {
            m_stats.rejectedCount++;
        }
        m_stats.totalRequests++;
    }
    
    locker.unlock();
    
    emit approvalDecided(approvalId, decision == ApprovalDecision::Accept);
}

void DefaultApprovalManager::recordAssessment(const GuardianAssessmentEvent &assessment)
{
    QMutexLocker locker(&m_mutex);
    m_assessmentHistory.append(assessment);
}

QVariantMap DefaultApprovalManager::getApprovalStats() const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    stats["totalRequests"] = m_stats.totalRequests;
    stats["approvedCount"] = m_stats.approvedCount;
    stats["rejectedCount"] = m_stats.rejectedCount;
    stats["pendingCount"] = m_pendingApprovals.size();
    stats["assessmentCount"] = m_assessmentHistory.size();
    
    if (m_stats.totalRequests > 0) {
        int approved = (m_stats.approvedCount * 100) / m_stats.totalRequests;
        stats["approvalRate"] = QString("%1%").arg(approved);
    }
    
    return stats;
}

void DefaultApprovalManager::setReadOnlyMode(bool enabled)
{
    QMutexLocker locker(&m_mutex);
    m_readOnlyMode = enabled;
}

bool DefaultApprovalManager::isReadOnlyMode() const
{
    QMutexLocker locker(&m_mutex);
    return m_readOnlyMode;
}

QVector<ExecApprovalRequestEvent> DefaultApprovalManager::getPendingApprovals() const
{
    QMutexLocker locker(&m_mutex);
    
    QVector<ExecApprovalRequestEvent> pending;
    for (const auto &approval : m_pendingApprovals) {
        if (!approval.processed) {
            pending.append(approval.request);
        }
    }
    
    return pending;
}

#include "moc_DefaultApprovalManager.cpp"
