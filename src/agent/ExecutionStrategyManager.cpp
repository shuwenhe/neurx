#include "agent/ExecutionStrategyManager.h"
#include <QDebug>
#include <QJsonObject>
#include <QJsonArray>
#include <QUuid>

ExecutionStrategyManager::ExecutionStrategyManager(QObject *parent)
    : QObject(parent)
{
    registerDefaultStrategies();
}

ExecutionStrategyManager::~ExecutionStrategyManager() = default;

// ── Strategy Management ─────────────────────────────────────────────────

void ExecutionStrategyManager::registerStrategy(const ExecutionStrategy &strategy)
{
    m_strategies[strategy.id] = strategy;
    emit strategyRegistered(strategy);
    qDebug() << "Registered strategy:" << strategy.name;
}

bool ExecutionStrategyManager::unregisterStrategy(const QString &strategyId)
{
    return m_strategies.remove(strategyId) > 0;
}

ExecutionStrategy ExecutionStrategyManager::getStrategy(const QString &strategyId) const
{
    auto it = m_strategies.find(strategyId);
    if (it != m_strategies.end()) {
        return *it;
    }
    return ExecutionStrategy();
}

QList<ExecutionStrategy> ExecutionStrategyManager::allStrategies() const
{
    return m_strategies.values();
}

// ── Strategy Application ────────────────────────────────────────────────

ExecutionStrategy ExecutionStrategyManager::getStrategyForTool(const QString &toolName) const
{
    for (const auto &strategy : m_strategies.values()) {
        if (strategy.enabled && strategy.applicableTools.contains(toolName)) {
            return strategy;
        }
    }
    
    // Return default strategy
    return getStrategy("default");
}

ExecutionStrategy ExecutionStrategyManager::getStrategyForCommand(const QString &commandName) const
{
    for (const auto &strategy : m_strategies.values()) {
        if (strategy.enabled && strategy.applicableCommands.contains(commandName)) {
            return strategy;
        }
    }
    
    // Return default strategy
    return getStrategy("default");
}

// ── Risk Assessment ─────────────────────────────────────────────────────

RiskAssessment ExecutionStrategyManager::assessToolRisk(const QString &toolName, 
                                                       const QJsonObject &parameters)
{
    RiskAssessment assessment = assessBasicToolRisk(toolName);
    
    // Add parameter-based risk
    int paramRisk = assessParameterRisk(parameters);
    assessment.score += paramRisk / 2;
    
    // Check for destructive patterns
    if (hasDestructivePattern(toolName, parameters)) {
        assessment.score += 30;
        assessment.factors.append("Destructive operation detected");
    }
    
    // Clamp score to 0-100
    assessment.score = qMax(0, qMin(100, assessment.score));
    
    // Determine risk level
    if (assessment.score < 30) {
        assessment.level = "low";
    } else if (assessment.score < 60) {
        assessment.level = "medium";
    } else if (assessment.score < 85) {
        assessment.level = "high";
    } else {
        assessment.level = "critical";
    }
    
    emit riskAssessed(toolName, assessment);
    m_riskHistory[toolName] = assessment.score;
    
    return assessment;
}

RiskAssessment ExecutionStrategyManager::assessCommandRisk(const QString &commandName,
                                                         const QStringList &args)
{
    RiskAssessment assessment;
    assessment.score = 20;  // Base risk
    assessment.level = "low";
    
    // Check for dangerous commands
    if (commandName.contains("rm") || commandName.contains("delete")) {
        assessment.score += 50;
        assessment.factors.append("Potentially destructive command");
    }
    
    if (commandName.contains("chmod") || commandName.contains("chown")) {
        assessment.score += 30;
        assessment.factors.append("Permission modification");
    }
    
    if (commandName.contains("sudo")) {
        assessment.score += 40;
        assessment.factors.append("Elevated privileges");
    }
    
    // Check arguments
    for (const auto &arg : args) {
        if (arg.contains("-rf") || arg.contains("-force")) {
            assessment.score += 20;
            assessment.factors.append("Forced operation flag");
        }
    }
    
    // Clamp and determine level
    assessment.score = qMax(0, qMin(100, assessment.score));
    
    if (assessment.score < 30) {
        assessment.level = "low";
    } else if (assessment.score < 60) {
        assessment.level = "medium";
    } else if (assessment.score < 85) {
        assessment.level = "high";
    } else {
        assessment.level = "critical";
    }
    
    return assessment;
}

QJsonObject ExecutionStrategyManager::getRiskFactors() const
{
    QJsonObject factors;
    
    QJsonArray tools;
    tools.append("shell_tool");
    tools.append("delete_file");
    tools.append("modify_permissions");
    factors["dangerousTools"] = tools;
    
    QJsonArray patterns;
    patterns.append("rm -rf");
    patterns.append("DROP TABLE");
    patterns.append("DELETE FROM");
    factors["destructivePatterns"] = patterns;
    
    return factors;
}

// ── Approval Decision ────────────────────────────────────────────────────

bool ExecutionStrategyManager::needsApproval(const RiskAssessment &risk,
                                            const ExecutionStrategy &strategy)
{
    switch (strategy.approvalMode) {
        case ExecutionStrategy::ApprovalMode::Auto:
            return false;
            
        case ExecutionStrategy::ApprovalMode::Manual:
            return true;
            
        case ExecutionStrategy::ApprovalMode::RiskBased:
            if (risk.score >= strategy.highRiskThreshold) {
                return true;
            }
            return false;
            
        case ExecutionStrategy::ApprovalMode::AlwaysDeny:
            return true;  // Effectively denies by requiring approval
            
        default:
            return true;
    }
}

QString ExecutionStrategyManager::getApprovalReason(const RiskAssessment &risk) const
{
    QString reason = QString("Risk level: %1 (%2%)").arg(risk.level).arg(risk.score);
    
    if (!risk.factors.isEmpty()) {
        reason += "\n\nRisk factors:";
        for (const auto &factor : risk.factors) {
            reason += QString("\n- %1").arg(factor);
        }
    }
    
    return reason;
}

// ── Built-in Strategies ─────────────────────────────────────────────────

void ExecutionStrategyManager::registerDefaultStrategies()
{
    // Safe strategy (high approval threshold)
    {
        ExecutionStrategy safe;
        safe.id = "safe";
        safe.name = "Safe Mode";
        safe.description = "Requires approval for risky operations";
        safe.approvalMode = ExecutionStrategy::ApprovalMode::RiskBased;
        safe.highRiskThreshold = 50;  // Lower threshold
        safe.enableRollback = true;
        safe.captureState = true;
        
        registerStrategy(safe);
    }
    
    // Default strategy
    {
        ExecutionStrategy normal;
        normal.id = "default";
        normal.name = "Normal Mode";
        normal.description = "Standard approval workflow";
        normal.approvalMode = ExecutionStrategy::ApprovalMode::RiskBased;
        normal.highRiskThreshold = 70;
        normal.enableRollback = true;
        
        registerStrategy(normal);
    }
    
    // Permissive strategy (low approval threshold)
    {
        ExecutionStrategy permissive;
        permissive.id = "permissive";
        permissive.name = "Permissive Mode";
        permissive.description = "Auto-approve most operations";
        permissive.approvalMode = ExecutionStrategy::ApprovalMode::RiskBased;
        permissive.highRiskThreshold = 90;  // High threshold
        permissive.enableRollback = false;
        
        registerStrategy(permissive);
    }
    
    // Restricted strategy (all operations require approval)
    {
        ExecutionStrategy restricted;
        restricted.id = "restricted";
        restricted.name = "Restricted Mode";
        restricted.description = "Require approval for all operations";
        restricted.approvalMode = ExecutionStrategy::ApprovalMode::Manual;
        restricted.enableRollback = true;
        restricted.captureState = true;
        
        registerStrategy(restricted);
    }
}

ExecutionStrategy ExecutionStrategyManager::createSafeStrategy(const QString &name)
{
    ExecutionStrategy safe;
    safe.id = QString("safe_%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    safe.name = name;
    safe.approvalMode = ExecutionStrategy::ApprovalMode::RiskBased;
    safe.highRiskThreshold = 40;
    safe.enableRollback = true;
    safe.captureState = true;
    
    registerStrategy(safe);
    return safe;
}

ExecutionStrategy ExecutionStrategyManager::createPermissiveStrategy(const QString &name)
{
    ExecutionStrategy permissive;
    permissive.id = QString("perm_%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    permissive.name = name;
    permissive.approvalMode = ExecutionStrategy::ApprovalMode::Auto;
    permissive.enableRollback = false;
    
    registerStrategy(permissive);
    return permissive;
}

// ── State Management ────────────────────────────────────────────────────

QString ExecutionStrategyManager::captureState()
{
    QString stateId = QString("state_%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    
    QJsonObject state;
    state["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    state["data"] = QJsonObject();  // TODO: Capture actual system state
    
    m_stateSnapshots[stateId] = state;
    qDebug() << "Captured state:" << stateId;
    
    return stateId;
}

bool ExecutionStrategyManager::restoreState(const QString &stateId)
{
    auto it = m_stateSnapshots.find(stateId);
    if (it == m_stateSnapshots.end()) {
        return false;
    }
    
    // TODO: Implement actual state restoration
    qDebug() << "Restored state:" << stateId;
    return true;
}

QList<QString> ExecutionStrategyManager::getCapturedStates() const
{
    return m_stateSnapshots.keys();
}

void ExecutionStrategyManager::clearCapturedStates()
{
    m_stateSnapshots.clear();
    m_operationStates.clear();
}

// ── Rollback Support ────────────────────────────────────────────────────

bool ExecutionStrategyManager::canRollback(const QString &operationId) const
{
    return m_operationStates.contains(operationId);
}

bool ExecutionStrategyManager::rollback(const QString &operationId)
{
    auto it = m_operationStates.find(operationId);
    if (it == m_operationStates.end()) {
        return false;
    }
    
    QString stateId = it.value();
    bool success = restoreState(stateId);
    
    if (success) {
        emit rollbackOccurred(operationId, "User-initiated rollback");
    }
    
    return success;
}

// ── Statistics ───────────────────────────────────────────────────────────

QJsonObject ExecutionStrategyManager::getStatistics() const
{
    QJsonObject stats;
    stats["totalStrategies"] = m_strategies.size();
    stats["capturedStates"] = m_stateSnapshots.size();
    
    QJsonObject byName;
    for (const auto &strategy : m_strategies.values()) {
        byName[strategy.name] = strategy.enabled;
    }
    stats["strategies"] = byName;
    
    return stats;
}

QJsonObject ExecutionStrategyManager::getRiskDistribution() const
{
    QJsonObject distribution;
    int low = 0, medium = 0, high = 0, critical = 0;
    
    for (const auto &score : m_riskHistory.values()) {
        if (score < 30) low++;
        else if (score < 60) medium++;
        else if (score < 85) high++;
        else critical++;
    }
    
    distribution["low"] = low;
    distribution["medium"] = medium;
    distribution["high"] = high;
    distribution["critical"] = critical;
    
    return distribution;
}

// ── Private helper methods ──────────────────────────────────────────────

RiskAssessment ExecutionStrategyManager::assessBasicToolRisk(const QString &toolName) const
{
    RiskAssessment assessment;
    assessment.score = 20;  // Base risk
    
    // Known dangerous tools
    if (toolName == "shell_tool" || toolName.contains("exec")) {
        assessment.score = 60;
        assessment.factors.append("Shell execution tool");
    } else if (toolName.contains("delete") || toolName.contains("remove")) {
        assessment.score = 50;
        assessment.factors.append("File deletion tool");
    } else if (toolName.contains("write") || toolName.contains("modify")) {
        assessment.score = 40;
        assessment.factors.append("File modification tool");
    } else if (toolName.contains("read")) {
        assessment.score = 10;
        assessment.factors.append("Read-only operation");
    }
    
    assessment.level = assessment.score < 30 ? "low" : 
                      assessment.score < 60 ? "medium" :
                      assessment.score < 85 ? "high" : "critical";
    
    return assessment;
}

int ExecutionStrategyManager::assessParameterRisk(const QJsonObject &parameters) const
{
    int risk = 0;
    
    for (auto it = parameters.begin(); it != parameters.end(); ++it) {
        QString value = it.value().toString();
        
        // Check for patterns
        if (value.contains("rm -rf") || value.contains("DROP TABLE")) {
            risk += 50;
        } else if (value.contains("DELETE") || value.contains("truncate")) {
            risk += 40;
        } else if (value.contains("chmod") || value.contains("chown")) {
            risk += 30;
        }
    }
    
    return qMin(100, risk);
}

bool ExecutionStrategyManager::hasDestructivePattern(const QString &toolName,
                                                    const QJsonObject &params) const
{
    for (auto it = params.begin(); it != params.end(); ++it) {
        QString value = it.value().toString();
        
        if (value.contains("rm -rf") || 
            value.contains("DROP TABLE") ||
            value.contains("DELETE FROM") ||
            value.contains("truncate")) {
            return true;
        }
    }
    
    return false;
}
