#pragma once

#include "ApprovalTypes.h"
#include <QObject>
#include <QVector>
#include <memory>
#include <functional>

/**
 * @class ApprovalManager
 * @brief Central manager for approval policies, requests, and decisions
 * 
 * Handles:
 * - Approval policy configuration and storage
 * - Approval request lifecycle
 * - User/Guardian decision collection
 * - Approval analytics
 * 
 * Migrated from Codex's approval system for fine-grained agent control.
 */
class ApprovalManager : public QObject {
    Q_OBJECT
public:
    explicit ApprovalManager(QObject *parent = nullptr) : QObject(parent) {}
    virtual ~ApprovalManager() = default;
    
    // ── Policy Configuration ───────────────────────────────────────────
    
    /// Set default approval policy
    virtual void setDefaultPolicy(const ApprovalPolicy &policy) = 0;
    
    /// Get current default policy
    virtual ApprovalPolicy getDefaultPolicy() const = 0;
    
    /// Add granular approval rule
    virtual void addGranularRule(const GranularApprovalConfig &rule) = 0;
    
    /// Remove granular rule by pattern
    virtual void removeGranularRule(const QString &resourcePattern) = 0;
    
    // ── Approval Requests ──────────────────────────────────────────────
    
    /// Request approval for command execution
    virtual void requestExecApproval(const ExecApprovalRequestEvent &request,
                                    std::function<void(bool approved, ApprovalDecision decision)> callback) = 0;
    
    /// Request approval for network access
    virtual void requestNetworkApproval(const NetworkApprovalContext &context,
                                       std::function<void(bool approved, ApprovalDecision decision)> callback) = 0;
    
    /// Request Guardian assessment
    virtual void requestGuardianAssessment(const ExecApprovalRequestEvent &request,
                                          std::function<void(GuardianAssessmentEvent)> callback) = 0;
    
    /// Check if action needs approval without requesting it
    virtual bool requiresApproval(const QString &action, const QString &toolName) const = 0;
    
    /// Get approval policy for specific tool/resource
    virtual AskForApproval getPolicyFor(const QString &toolName, const QString &resource) const = 0;
    
    // ── Decision Recording ─────────────────────────────────────────────
    
    /// Record user's approval decision
    virtual void recordDecision(const QString &approvalId,
                               ApprovalDecision decision,
                               const QString &reason) = 0;
    
    /// Record Guardian's assessment
    virtual void recordAssessment(const GuardianAssessmentEvent &assessment) = 0;
    
    /// Get approval history for analytics
    virtual QVariantMap getApprovalStats() const = 0;
    
    // ── Mode Control ───────────────────────────────────────────────────
    
    /// Enable read-only mode (block all write operations)
    virtual void setReadOnlyMode(bool enabled) = 0;
    
    /// Check if read-only mode is active
    virtual bool isReadOnlyMode() const = 0;
    
    /// Get list of pending approvals
    virtual QVector<ExecApprovalRequestEvent> getPendingApprovals() const = 0;

signals:
    /// Emitted when approval is requested
    void approvalRequested(const QString &approvalId, const QVariantMap &details);
    
    /// Emitted when approval is decided
    void approvalDecided(const QString &approvalId, bool approved);
    
    /// Emitted when policy changes
    void policyChanged();
};

using ApprovalManagerPtr = std::shared_ptr<ApprovalManager>;
