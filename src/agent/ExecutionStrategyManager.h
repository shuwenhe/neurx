#pragma once

#include <QString>
#include <QMap>
#include <QList>
#include <QJsonObject>
#include <QObject>

/**
 * @class ExecutionStrategy
 * @brief Defines how operations should be executed
 */
struct ExecutionStrategy {
    enum class ApprovalMode {
        Auto,               ///< Automatically approve all
        Manual,             ///< Require manual approval
        RiskBased,          ///< Approve based on risk assessment
        AlwaysDeny          ///< Never approve
    };
    
    enum class Priority {
        Low = 0,
        Normal = 1,
        High = 2,
        Critical = 3
    };
    
    QString id;                      ///< Strategy ID
    QString name;                    ///< Strategy name
    QString description;             ///< Strategy description
    
    ApprovalMode approvalMode{ApprovalMode::RiskBased};
    int timeoutMs{60000};           ///< Approval timeout
    
    // Risk thresholds
    int lowRiskThreshold{20};
    int mediumRiskThreshold{60};
    int highRiskThreshold{85};
    
    // What types of operations this strategy applies to
    QStringList applicableTools;    ///< Tools affected by this strategy
    QStringList applicableCommands; ///< Commands affected by this strategy
    
    // Rollback settings
    bool enableRollback{true};      ///< Enable automatic rollback on failure
    bool captureState{true};        ///< Capture state before execution
    
    // Metadata
    bool enabled{true};
    Priority priority{Priority::Normal};
};

/**
 * @class RiskAssessment
 * @brief Assessment of risk for an operation
 */
struct RiskAssessment {
    int score{0};                   ///< Risk score (0-100)
    QString level;                  ///< Risk level (low, medium, high, critical)
    QString reason;                 ///< Reason for risk assessment
    QList<QString> factors;         ///< Contributing risk factors
    QJsonObject details;            ///< Detailed assessment data
};

/**
 * @class ExecutionStrategyManager
 * @brief Manages execution strategies and approval workflows
 * 
 * Features:
 * - Strategy registration and management
 * - Risk assessment
 * - Approval workflow
 * - Rollback support
 * - State capture and recovery
 */
class ExecutionStrategyManager : public QObject {
    Q_OBJECT

public:
    explicit ExecutionStrategyManager(QObject *parent = nullptr);
    ~ExecutionStrategyManager();

    // ── Strategy Management ─────────────────────────────────────────────────
    
    /**
     * @brief Register an execution strategy
     */
    void registerStrategy(const ExecutionStrategy &strategy);
    
    /**
     * @brief Unregister a strategy
     */
    bool unregisterStrategy(const QString &strategyId);
    
    /**
     * @brief Get strategy by ID
     */
    ExecutionStrategy getStrategy(const QString &strategyId) const;
    
    /**
     * @brief Get all strategies
     */
    QList<ExecutionStrategy> allStrategies() const;

    // ── Strategy Application ────────────────────────────────────────────────
    
    /**
     * @brief Get applicable strategy for a tool
     */
    ExecutionStrategy getStrategyForTool(const QString &toolName) const;
    
    /**
     * @brief Get applicable strategy for a command
     */
    ExecutionStrategy getStrategyForCommand(const QString &commandName) const;

    // ── Risk Assessment ─────────────────────────────────────────────────────
    
    /**
     * @brief Assess risk for a tool execution
     */
    RiskAssessment assessToolRisk(const QString &toolName, const QJsonObject &parameters);
    
    /**
     * @brief Assess risk for a command execution
     */
    RiskAssessment assessCommandRisk(const QString &commandName, const QStringList &args);
    
    /**
     * @brief Get predefined risk factors
     */
    QJsonObject getRiskFactors() const;

    // ── Approval Decision ────────────────────────────────────────────────────
    
    /**
     * @brief Determine if operation needs approval
     */
    bool needsApproval(const RiskAssessment &risk, const ExecutionStrategy &strategy);
    
    /**
     * @brief Get approval reason
     */
    QString getApprovalReason(const RiskAssessment &risk) const;

    // ── Built-in Strategies ─────────────────────────────────────────────────
    
    /**
     * @brief Register default strategies
     */
    void registerDefaultStrategies();
    
    /**
     * @brief Create a safe strategy
     */
    ExecutionStrategy createSafeStrategy(const QString &name);
    
    /**
     * @brief Create a permissive strategy
     */
    ExecutionStrategy createPermissiveStrategy(const QString &name);

    // ── State Management ────────────────────────────────────────────────────
    
    /**
     * @brief Capture system state before operation
     */
    QString captureState();
    
    /**
     * @brief Restore system state
     */
    bool restoreState(const QString &stateId);
    
    /**
     * @brief List captured states
     */
    QList<QString> getCapturedStates() const;
    
    /**
     * @brief Clear captured states
     */
    void clearCapturedStates();

    // ── Rollback Support ────────────────────────────────────────────────────
    
    /**
     * @brief Check if rollback is available for an operation
     */
    bool canRollback(const QString &operationId) const;
    
    /**
     * @brief Rollback an operation
     */
    bool rollback(const QString &operationId);

    // ── Statistics ───────────────────────────────────────────────────────────
    
    /**
     * @brief Get strategy usage statistics
     */
    QJsonObject getStatistics() const;
    
    /**
     * @brief Get risk distribution
     */
    QJsonObject getRiskDistribution() const;

signals:
    /**
     * @brief Emitted when strategy is registered
     */
    void strategyRegistered(const ExecutionStrategy &strategy);
    
    /**
     * @brief Emitted when risk assessment completes
     */
    void riskAssessed(const QString &operation, const RiskAssessment &risk);
    
    /**
     * @brief Emitted when approval is needed
     */
    void approvalNeeded(const QString &operation, const RiskAssessment &risk);
    
    /**
     * @brief Emitted when rollback occurs
     */
    void rollbackOccurred(const QString &operationId, const QString &reason);

private:
    /**
     * @brief Assess basic tool risk
     */
    RiskAssessment assessBasicToolRisk(const QString &toolName) const;
    
    /**
     * @brief Assess parameter risk
     */
    int assessParameterRisk(const QJsonObject &parameters) const;
    
    /**
     * @brief Check for destructive patterns
     */
    bool hasDestructivePattern(const QString &toolName, const QJsonObject &params) const;

    // ── Data members ────────────────────────────────────────────────────────
    QMap<QString, ExecutionStrategy> m_strategies;
    QMap<QString, QJsonObject> m_stateSnapshots;  // stateId -> state data
    QMap<QString, QString> m_operationStates;     // operationId -> stateId
    QMap<QString, int> m_riskHistory;            // tracking risk assessment
};
