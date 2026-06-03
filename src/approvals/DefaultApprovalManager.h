#pragma once

#include "ApprovalManager.h"
#include <QMap>
#include <QMutex>
#include <memory>

/**
 * @class DefaultApprovalManager
 * @brief Default implementation of ApprovalManager
 * 
 * Handles approval workflows with support for:
 * - Policy-based decisions
 * - Granular per-tool/per-resource rules
 * - Guardian integration for risk assessment
 */
class DefaultApprovalManager : public ApprovalManager {
    Q_OBJECT
public:
    explicit DefaultApprovalManager(QObject *parent = nullptr);

    // Policy configuration
    void setDefaultPolicy(const ApprovalPolicy &policy) override;
    ApprovalPolicy getDefaultPolicy() const override;
    void addGranularRule(const GranularApprovalConfig &rule) override;
    void removeGranularRule(const QString &resourcePattern) override;

    // Approval requests
    void requestExecApproval(const ExecApprovalRequestEvent &request,
                            std::function<void(bool approved, ApprovalDecision decision)> callback) override;
    void requestNetworkApproval(const NetworkApprovalContext &context,
                               std::function<void(bool approved, ApprovalDecision decision)> callback) override;
    void requestGuardianAssessment(const ExecApprovalRequestEvent &request,
                                  std::function<void(GuardianAssessmentEvent)> callback) override;

    bool requiresApproval(const QString &action, const QString &toolName) const override;
    AskForApproval getPolicyFor(const QString &toolName, const QString &resource) const override;

    // Decision recording
    void recordDecision(const QString &approvalId,
                       ApprovalDecision decision,
                       const QString &reason) override;
    void recordAssessment(const GuardianAssessmentEvent &assessment) override;
    QVariantMap getApprovalStats() const override;

    // Mode control
    void setReadOnlyMode(bool enabled) override;
    bool isReadOnlyMode() const override;
    QVector<ExecApprovalRequestEvent> getPendingApprovals() const override;

private:
    struct PendingApproval {
        QString id;
        ExecApprovalRequestEvent request;
        QDateTime requestedAt;
        bool processed{false};
    };

    struct ApprovalStatistics {
        int totalRequests{0};
        int approvedCount{0};
        int rejectedCount{0};
        int averageDecisionTime{0}; // milliseconds
    };

    ApprovalPolicy m_defaultPolicy;
    QVector<GranularApprovalConfig> m_granularRules;
    QMap<QString, PendingApproval> m_pendingApprovals;
    QVector<GuardianAssessmentEvent> m_assessmentHistory;
    ApprovalStatistics m_stats;
    bool m_readOnlyMode{false};
    mutable QMutex m_mutex;

    AskForApproval getPolicyFor_impl(const QString &toolName, const QString &resource) const;
    bool checkGranularRules(const QString &toolName, const QString &resource) const;
};

using DefaultApprovalManagerPtr = std::shared_ptr<DefaultApprovalManager>;
