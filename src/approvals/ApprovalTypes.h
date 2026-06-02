#pragma once

#include <QString>
#include <QVariantMap>
#include <QDateTime>
#include <QUuid>

/**
 * @enum AskForApproval
 * @brief When to request user approval for tool execution
 * 
 * Migrated from Codex approval policies.
 */
enum class AskForApproval {
    Never,              ///< Never ask, auto-allow
    OnFailure,          ///< Ask only if tool fails
    OnRequest,          ///< Ask for every execution
    Granular,           ///< Fine-grained approval per resource/path
    UnlessTrusted       ///< Ask unless tool is marked trusted
};

/**
 * @enum ApprovalsReviewer
 * @brief Who reviews and makes approval decisions
 */
enum class ApprovalsReviewer {
    User,               ///< Human user makes the decision
    AutoReview,         ///< Automatic policy-based review
    Guardian            ///< Guardian subagent makes review
};

/**
 * @enum NetworkApprovalProtocol
 * @brief Network protocols requiring approval for outbound connections
 */
enum class NetworkApprovalProtocol {
    Http,               ///< HTTP connections
    Https,              ///< HTTPS connections
    Socks5Tcp,          ///< SOCKS5 TCP
    Socks5Udp,          ///< SOCKS5 UDP
    Ssh,                ///< SSH connections
    Ftp,                ///< FTP/SFTP
    Dns,                ///< DNS queries
    Other               ///< Other protocols
};

/**
 * @enum ApprovalDecision
 * @brief User's response to an approval request
 */
enum class ApprovalDecision {
    Accept,             ///< Allow once
    Reject,             ///< Deny this time
    AcceptForSession,   ///< Allow for this session
    AcceptForever       ///< Allow permanently for this context
};

/**
 * @struct NetworkApprovalContext
 * @brief Context for network access approval
 */
struct NetworkApprovalContext {
    NetworkApprovalProtocol protocol;
    QString hostname;
    int port{0};
    QString destination;                    ///< Full URL or endpoint
    QString toolName;                       ///< Which tool is making the request
    QString reason;                         ///< Why is this connection needed
};

/**
 * @struct ExecApprovalRequestEvent
 * @brief Request for approval to execute a command or tool
 */
struct ExecApprovalRequestEvent {
    QString approvalId{QUuid::createUuid().toString()};
    QString commandLine;
    QString toolName;
    QString reason;
    
    AskForApproval policy{AskForApproval::OnRequest};
    ApprovalsReviewer reviewer{ApprovalsReviewer::User};
    
    QDateTime requestedAt;
    /// User's approval window (0 = unlimited)
    int timeoutSeconds{300};
    
    /// Additional context
    QVariantMap context;
};

/**
 * @struct GuardianAssessmentEvent
 * @brief Result of Guardian subagent's assessment
 */
struct GuardianAssessmentEvent {
    QString assessmentId{QUuid::createUuid().toString()};
    QString targetAction;
    QString riskLevel;                      ///< "low", "medium", "high"
    bool recommended{false};                ///< Guardian's recommendation
    QString reasoning;                      ///< Why Guardian recommends this
    
    QDateTime assessedAt;
    /// Guardian response time (useful for analytics)
    int responseTimeMs{0};
};

/**
 * @struct GranularApprovalConfig
 * @brief Fine-grained approval configuration per resource/directory/tool
 */
struct GranularApprovalConfig {
    QString resourcePattern;                ///< Path or resource pattern
    AskForApproval approval{AskForApproval::OnRequest};
    /// Can be "approve", "reject", "prompt"
    QString action;
    /// For which tools this applies ("*" for all)
    QStringList toolNames;
    /// Is this configuration permanent or session-scoped
    bool permanent{false};
};

/**
 * @enum GuardianAssessmentStatus
 * @brief Status of Guardian assessment
 */
enum class GuardianAssessmentStatus {
    InProgress,         ///< Assessment in progress
    Approved,           ///< Guardian approved
    Denied,             ///< Guardian denied
    TimedOut,           ///< Assessment timed out
    Aborted             ///< Assessment was aborted
};

/**
 * @struct ApprovalPolicy
 * @brief Complete approval policy for agent execution
 */
struct ApprovalPolicy {
    AskForApproval defaultPolicy{AskForApproval::OnRequest};
    ApprovalsReviewer defaultReviewer{ApprovalsReviewer::User};
    
    /// Fine-grained overrides per resource
    QVector<GranularApprovalConfig> granularRules;
    
    /// Network approval policy
    bool requireNetworkApproval{true};
    QVector<NetworkApprovalProtocol> restrictedProtocols;
    
    /// Dangerous command patterns that require double confirmation
    QStringList doubleConfirmPatterns;
    
    /// Read-only mode: disallow all write operations
    bool readOnlyMode{false};
    
    /// Automatically approve retries after initial failure
    bool autoApproveOnRetry{false};
};
