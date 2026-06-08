#include "ApprovalStrategyManager.h"
#include <QJsonDocument>
#include <QDateTime>
#include <QDebug>
#include <QUuid>
#include <QMap>

ApprovalStrategyManager::ApprovalStrategyManager(QObject *parent)
    : QObject(parent)
{
    initializeDefaultStrategies();
}

ApprovalStrategyManager::~ApprovalStrategyManager()
{
}

void ApprovalStrategyManager::initializeDefaultStrategies()
{
    // Never策略 - 自动允许
    {
        ApprovalStrategy strategy;
        strategy.name = "Never";
        strategy.type = Never;
        strategy.description = "自动批准所有操作，不需要审批";
        strategy.isActive = true;
        strategy.createdAt = QDateTime::currentDateTime().toString(Qt::ISODate);
        strategy.updatedAt = strategy.createdAt;

        QJsonObject config;
        config["requireApproval"] = false;
        config["logOnly"] = true;
        strategy.config = config;

        m_strategies.insert("Never", strategy);
    }

    // OnFailure策略
    {
        ApprovalStrategy strategy;
        strategy.name = "OnFailure";
        strategy.type = OnFailure;
        strategy.description = "仅在操作失败时需要审批";
        strategy.isActive = true;
        strategy.createdAt = QDateTime::currentDateTime().toString(Qt::ISODate);
        strategy.updatedAt = strategy.createdAt;

        QJsonObject config;
        config["requireApprovalOnFailure"] = true;
        config["retryLimit"] = 3;
        strategy.config = config;

        m_strategies.insert("OnFailure", strategy);
    }

    // OnRequest策略
    {
        ApprovalStrategy strategy;
        strategy.name = "OnRequest";
        strategy.type = OnRequest;
        strategy.description = "每次操作都需要用户审批";
        strategy.isActive = true;
        strategy.createdAt = QDateTime::currentDateTime().toString(Qt::ISODate);
        strategy.updatedAt = strategy.createdAt;

        QJsonObject config;
        config["requireApprovalAlways"] = true;
        config["timeoutMinutes"] = 30;
        strategy.config = config;

        m_strategies.insert("OnRequest", strategy);
    }

    // Granular策略
    {
        ApprovalStrategy strategy;
        strategy.name = "Granular";
        strategy.type = Granular;
        strategy.description = "细粒度资源级审批 - 根据风险等级决策";
        strategy.isActive = true;
        strategy.createdAt = QDateTime::currentDateTime().toString(Qt::ISODate);
        strategy.updatedAt = strategy.createdAt;

        QJsonObject config;
        config["criticalRequiresApproval"] = true;
        config["highRequiresApproval"] = true;
        config["mediumRequiresApproval"] = false;
        config["lowAutoApprove"] = true;
        strategy.config = config;

        m_strategies.insert("Granular", strategy);
    }

    // UnlessTrusted策略
    {
        ApprovalStrategy strategy;
        strategy.name = "UnlessTrusted";
        strategy.type = UnlessTrusted;
        strategy.description = "除非工具被信任，否则需要审批";
        strategy.isActive = true;
        strategy.createdAt = QDateTime::currentDateTime().toString(Qt::ISODate);
        strategy.updatedAt = strategy.createdAt;

        QJsonObject config;
        config["trustListEnabled"] = true;
        config["requireApprovalForUntrusted"] = true;
        config["trustLevelMedium"] = 3;
        strategy.config = config;

        m_strategies.insert("UnlessTrusted", strategy);
    }

    // 初始化默认规则
    m_rules.append({
        RiskLevel,
        "CRITICAL",
        Granular,
        100  // 最高优先级
    });

    m_rules.append({
        RiskLevel,
        "HIGH",
        Granular,
        90
    });

    m_rules.append({
        ToolName,
        "ShellTool",
        OnRequest,
        80
    });

    m_rules.append({
        ToolName,
        "FileSystemTool",
        Granular,
        70
    });

    m_rules.append({
        ActionType,
        "delete",
        OnRequest,
        85
    });

    m_rules.append({
        ActionType,
        "execute",
        Granular,
        75
    });
}

void ApprovalStrategyManager::createStrategy(
    const QString &name,
    StrategyType type,
    const QString &description,
    const QJsonObject &config)
{
    if (m_strategies.contains(name)) {
        qWarning() << "Strategy already exists:" << name;
        return;
    }

    ApprovalStrategy strategy;
    strategy.name = name;
    strategy.type = type;
    strategy.description = description;
    strategy.config = config;
    strategy.isActive = true;
    strategy.createdAt = QDateTime::currentDateTime().toString(Qt::ISODate);
    strategy.updatedAt = strategy.createdAt;

    m_strategies.insert(name, strategy);
    m_stats.insert(name, {name, 0, 0, 0, 0.0, 0.0});

    emit strategyCreated(name);
}

void ApprovalStrategyManager::updateStrategy(
    const QString &name,
    const QJsonObject &config)
{
    if (!m_strategies.contains(name)) {
        qWarning() << "Strategy not found:" << name;
        return;
    }

    m_strategies[name].config = config;
    m_strategies[name].updatedAt = QDateTime::currentDateTime().toString(Qt::ISODate);

    emit strategyUpdated(name);
}

void ApprovalStrategyManager::deleteStrategy(const QString &name)
{
    if (m_strategies.remove(name) > 0) {
        m_stats.remove(name);
        emit strategyDeleted(name);
    }
}

ApprovalStrategyManager::ApprovalStrategy ApprovalStrategyManager::getStrategy(
    const QString &name)
{
    return m_strategies.value(name);
}

QList<ApprovalStrategyManager::ApprovalStrategy> ApprovalStrategyManager::listStrategies()
{
    return m_strategies.values();
}

void ApprovalStrategyManager::addRule(const StrategyRule &rule)
{
    m_rules.append(rule);

    // 按优先级排序
    std::sort(m_rules.begin(), m_rules.end(),
        [](const StrategyRule &a, const StrategyRule &b) {
            return a.priority > b.priority;
        });

    emit ruleAdded();
}

void ApprovalStrategyManager::removeRule(const QString &ruleId)
{
    // 这里简化处理，实际应该使用真正的rule ID
    emit ruleRemoved();
}

QList<ApprovalStrategyManager::StrategyRule> ApprovalStrategyManager::getRulesForTool(
    const QString &toolName)
{
    QList<StrategyRule> matchingRules;

    for (const auto &rule : m_rules) {
        if (rule.condition == ToolName && rule.value == toolName) {
            matchingRules.append(rule);
        }
    }

    return matchingRules;
}

QList<ApprovalStrategyManager::StrategyRule> ApprovalStrategyManager::getRulesForAction(
    const QString &actionType)
{
    QList<StrategyRule> matchingRules;

    for (const auto &rule : m_rules) {
        if (rule.condition == ActionType && rule.value == actionType) {
            matchingRules.append(rule);
        }
    }

    return matchingRules;
}

ApprovalStrategyManager::StrategyType ApprovalStrategyManager::selectStrategy(
    const QString &toolName,
    const QString &actionType,
    int riskLevel,
    const QString &userRole)
{
    // 收集所有匹配的规则
    QList<StrategyType> candidates;

    // 检查工具规则
    for (const auto &rule : getRulesForTool(toolName)) {
        candidates.append(rule.recommendedStrategy);
    }

    // 检查动作规则
    for (const auto &rule : getRulesForAction(actionType)) {
        candidates.append(rule.recommendedStrategy);
    }

    // 检查风险等级规则
    for (const auto &rule : m_rules) {
        if (rule.condition == RiskLevel) {
            if ((riskLevel >= 4 && rule.value == "CRITICAL") ||
                (riskLevel >= 3 && riskLevel < 4 && rule.value == "HIGH")) {
                candidates.append(rule.recommendedStrategy);
            }
        }
    }

    if (candidates.isEmpty()) {
        return Granular;  // 默认策略
    }

    return resolveConflict(candidates);
}

ApprovalStrategyManager::StrategyType ApprovalStrategyManager::resolveConflict(
    const QList<StrategyType> &conflictingStrategies)
{
    if (conflictingStrategies.isEmpty()) {
        return Granular;
    }

    // 冲突解决策略：优先级最高的赢
    // 优先级：OnRequest > Granular > UnlessTrusted > OnFailure > Never
    QMap<StrategyType, int> priority;
    priority[OnRequest] = 5;
    priority[Granular] = 4;
    priority[UnlessTrusted] = 3;
    priority[OnFailure] = 2;
    priority[Never] = 1;

    StrategyType bestStrategy = conflictingStrategies[0];
    int bestPriority = priority[bestStrategy];

    for (const auto &strategy : conflictingStrategies) {
        if (priority[strategy] > bestPriority) {
            bestStrategy = strategy;
            bestPriority = priority[strategy];
        }
    }

    return bestStrategy;
}

bool ApprovalStrategyManager::evaluateStrategy(
    StrategyType strategy,
    int riskLevel,
    const QString &approvalHistory)
{
    switch (strategy) {
    case Never:
        return true;  // 总是批准

    case OnFailure:
        return approvalHistory.isEmpty();  // 如果没有历史失败，批准

    case OnRequest:
        return false;  // 总是需要审批

    case Granular:
        // 基于风险等级：CRITICAL(5)和HIGH(4)需要审批
        return riskLevel < 4;

    case UnlessTrusted:
        // 默认需要审批，除非工具被信任
        return false;

    default:
        return false;
    }
}

QJsonObject ApprovalStrategyManager::getStrategyStats(const QString &strategyName)
{
    if (!m_stats.contains(strategyName)) {
        return QJsonObject();
    }

    const auto &stats = m_stats[strategyName];
    QJsonObject result;
    result["strategy"] = strategyName;
    result["totalApprovals"] = stats.totalApprovals;
    result["totalRejections"] = stats.totalRejections;
    result["totalReviews"] = stats.totalReviews;
    result["averageApprovalTime"] = stats.averageApprovalTime;
    result["successRate"] = stats.successRate;

    return result;
}

QJsonArray ApprovalStrategyManager::getApprovalMetrics()
{
    QJsonArray metrics;

    for (const auto &stats : m_stats) {
        QJsonObject metric;
        metric["strategy"] = stats.strategyName;
        metric["approvals"] = stats.totalApprovals;
        metric["rejections"] = stats.totalRejections;
        metric["reviews"] = stats.totalReviews;
        metric["successRate"] = stats.successRate;
        metrics.append(metric);
    }

    return metrics;
}

QJsonObject ApprovalStrategyManager::exportPolicies()
{
    QJsonObject export_obj;

    QJsonArray strategies;
    for (const auto &strategy : m_strategies.values()) {
        QJsonObject strategyObj;
        strategyObj["name"] = strategy.name;
        strategyObj["type"] = static_cast<int>(strategy.type);
        strategyObj["description"] = strategy.description;
        strategyObj["config"] = strategy.config;
        strategyObj["isActive"] = strategy.isActive;
        strategies.append(strategyObj);
    }

    export_obj["strategies"] = strategies;

    QJsonArray rulesArray;
    for (const auto &rule : m_rules) {
        QJsonObject ruleObj;
        ruleObj["condition"] = static_cast<int>(rule.condition);
        ruleObj["value"] = rule.value;
        ruleObj["recommendedStrategy"] = static_cast<int>(rule.recommendedStrategy);
        ruleObj["priority"] = rule.priority;
        rulesArray.append(ruleObj);
    }

    export_obj["rules"] = rulesArray;
    export_obj["exportedAt"] = QDateTime::currentDateTime().toString(Qt::ISODate);

    return export_obj;
}

void ApprovalStrategyManager::importPolicies(const QJsonObject &policies)
{
    // 导入策略
    if (policies.contains("strategies")) {
        QJsonArray strategiesArray = policies.value("strategies").toArray();
        for (const auto &item : strategiesArray) {
            QJsonObject strategyObj = item.toObject();
            ApprovalStrategy strategy;
            strategy.name = strategyObj.value("name").toString();
            strategy.type = static_cast<StrategyType>(strategyObj.value("type").toInt());
            strategy.description = strategyObj.value("description").toString();
            strategy.config = strategyObj.value("config").toObject();
            strategy.isActive = strategyObj.value("isActive").toBool();
            strategy.createdAt = QDateTime::currentDateTime().toString(Qt::ISODate);
            strategy.updatedAt = strategy.createdAt;

            m_strategies.insert(strategy.name, strategy);
        }
    }

    // 导入规则
    if (policies.contains("rules")) {
        QJsonArray rulesArray = policies.value("rules").toArray();
        m_rules.clear();
        for (const auto &item : rulesArray) {
            QJsonObject ruleObj = item.toObject();
            StrategyRule rule;
            rule.condition = static_cast<ConditionType>(ruleObj.value("condition").toInt());
            rule.value = ruleObj.value("value").toString();
            rule.recommendedStrategy = static_cast<StrategyType>(
                ruleObj.value("recommendedStrategy").toInt());
            rule.priority = ruleObj.value("priority").toInt();
            m_rules.append(rule);
        }
    }
}

void ApprovalStrategyManager::resetToDefaults()
{
    m_strategies.clear();
    m_rules.clear();
    m_stats.clear();
    initializeDefaultStrategies();
}
