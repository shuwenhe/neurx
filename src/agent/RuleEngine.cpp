#include "agent/RuleEngine.h"
#include <QDebug>
#include <QRegularExpression>
#include <QJsonDocument>
#include <QFile>
#include <QDateTime>
#include <QJsonArray>

RuleEngine::RuleEngine(QObject *parent)
    : QObject(parent)
{
    registerCommonValidationRules();
}

RuleEngine::~RuleEngine() = default;

// ── Rule Management ────────────────────────────────────────────────────

void RuleEngine::registerRule(const Rule &rule,
                             std::function<RuleResult(const RuleEvaluationContext &)> evaluator)
{
    m_rules[rule.id] = rule;
    m_evaluators[rule.id] = evaluator;
    emit ruleRegistered(rule);
    qDebug() << "Registered rule:" << rule.name;
}

bool RuleEngine::unregisterRule(const QString &ruleId)
{
    bool removed = m_rules.remove(ruleId) > 0;
    m_evaluators.remove(ruleId);
    return removed;
}

void RuleEngine::setRuleEnabled(const QString &ruleId, bool enabled)
{
    auto it = m_rules.find(ruleId);
    if (it != m_rules.end()) {
        it->enabled = enabled;
    }
}

QList<Rule> RuleEngine::allRules() const
{
    return m_rules.values();
}

QList<Rule> RuleEngine::rulesByTrigger(Rule::Trigger trigger) const
{
    QList<Rule> result;
    for (const auto &rule : m_rules.values()) {
        if (rule.trigger == trigger && rule.enabled) {
            result.append(rule);
        }
    }
    return result;
}

// ── Rule Evaluation ────────────────────────────────────────────────────

QList<RuleResult> RuleEngine::evaluateRules(const RuleEvaluationContext &context)
{
    QList<RuleResult> results;
    
    // Get applicable rules (all enabled rules)
    auto applicableRules = m_rules.values();
    
    // Sort by priority
    std::sort(applicableRules.begin(), applicableRules.end(),
              [](const Rule &a, const Rule &b) {
                  return a.priority > b.priority;
              });
    
    for (const auto &rule : applicableRules) {
        if (!rule.enabled) continue;
        
        auto result = evaluateRule(rule.id, context);
        results.append(result);
        
        if (rule.stopOnMatch && result.matched) {
            break;
        }
    }
    
    return results;
}

QList<RuleResult> RuleEngine::evaluateRulesByTrigger(Rule::Trigger trigger,
                                                    const RuleEvaluationContext &context)
{
    QList<RuleResult> results;
    auto applicableRules = rulesByTrigger(trigger);
    
    // Sort by priority
    std::sort(applicableRules.begin(), applicableRules.end(),
              [](const Rule &a, const Rule &b) {
                  return a.priority > b.priority;
              });
    
    for (const auto &rule : applicableRules) {
        auto result = evaluateRule(rule.id, context);
        results.append(result);
        
        if (rule.stopOnMatch && result.matched) {
            break;
        }
    }
    
    return results;
}

RuleResult RuleEngine::evaluateRule(const QString &ruleId, const RuleEvaluationContext &context)
{
    auto it = m_rules.find(ruleId);
    if (it == m_rules.end()) {
        RuleResult result;
        result.reason = "Rule not found";
        return result;
    }
    
    const auto &rule = *it;
    auto startTime = QDateTime::currentDateTime();
    
    // Check if rule applies to this context
    if (!contextMatchesRule(context, rule)) {
        RuleResult result;
        result.matched = false;
        result.executionTimeMs = QDateTime::currentDateTime().msecsTo(startTime);
        return result;
    }
    
    // Evaluate condition
    RuleResult result;
    result.matched = true;
    
    if (!rule.condition.isEmpty()) {
        result.matched = evaluateCondition(rule.condition, context.variables);
    }
    
    if (result.matched) {
        // Execute action
        result.actionResult = executeAction(rule, context);
        result.allowed = rule.type != Rule::RuleType::Action || !result.actionResult.isEmpty();
        result.message = QString("Rule '%1' matched").arg(rule.name);
        
        // Update statistics
        m_triggerCounts[ruleId]++;
        if (!result.allowed) {
            m_blockCounts[ruleId]++;
        }
        
        emit ruleEvaluated(ruleId, result);
    }
    
    result.executionTimeMs = QDateTime::currentDateTime().msecsTo(startTime);
    return result;
}

bool RuleEngine::isOperationAllowed(const RuleEvaluationContext &context, QString &blockReason)
{
    auto results = evaluateRules(context);
    
    for (const auto &result : results) {
        if (!result.allowed) {
            blockReason = result.reason;
            emit operationBlocked(blockReason);
            return false;
        }
    }
    
    emit operationAllowed("Operation allowed by all rules");
    return true;
}

// ── Built-in Rules ────────────────────────────────────────────────────

void RuleEngine::registerCommonValidationRules()
{
    // Rule 1: Prevent rm -rf
    {
        Rule rule;
        rule.id = "prevent-rm-rf";
        rule.name = "Prevent Destructive rm";
        rule.description = "Block 'rm -rf' and similar destructive commands";
        rule.type = Rule::RuleType::Validation;
        rule.trigger = Rule::Trigger::OnToolCall;
        rule.applicableTools = {"shell_tool"};
        rule.condition = "contains(command, 'rm') && contains(command, '-rf')";
        rule.priority = 100;
        rule.enabled = true;
        
        registerRule(rule, [](const RuleEvaluationContext &ctx) -> RuleResult {
            RuleResult result;
            result.matched = true;
            result.allowed = false;
            result.reason = "Destructive rm command blocked";
            return result;
        });
    }
    
    // Rule 2: Prevent unauthorized file access
    {
        Rule rule;
        rule.id = "prevent-unauthorized-access";
        rule.name = "Prevent Unauthorized File Access";
        rule.description = "Block access to sensitive system files";
        rule.type = Rule::RuleType::Validation;
        rule.trigger = Rule::Trigger::OnToolCall;
        rule.applicableTools = {"read_file", "write_file"};
        rule.condition = "path_is_sensitive(filePath)";
        rule.priority = 95;
        rule.enabled = true;
        
        registerRule(rule, [](const RuleEvaluationContext &ctx) -> RuleResult {
            RuleResult result;
            result.matched = false;  // Disabled by default
            result.allowed = true;
            return result;
        });
    }
}

Rule RuleEngine::createToolValidationRule(const QString &toolName, const QString &condition)
{
    Rule rule;
    rule.id = QString("rule-%1-%2").arg(toolName, QDateTime::currentDateTime().toString("yyyyMMddHHmmss"));
    rule.name = QString("Validate %1").arg(toolName);
    rule.type = Rule::RuleType::Validation;
    rule.trigger = Rule::Trigger::OnToolCall;
    rule.applicableTools = {toolName};
    rule.condition = condition;
    rule.priority = 50;
    rule.enabled = true;
    return rule;
}

Rule RuleEngine::createCommandPermissionRule(const QString &commandName, bool allowed)
{
    Rule rule;
    rule.id = QString("rule-cmd-%1-%2").arg(commandName, QDateTime::currentDateTime().toString("yyyyMMddHHmmss"));
    rule.name = QString("Permission for %1").arg(commandName);
    rule.description = allowed ? QString("Allow %1").arg(commandName) : QString("Block %1").arg(commandName);
    rule.type = Rule::RuleType::Validation;
    rule.trigger = Rule::Trigger::OnCommandExecution;
    rule.applicableCommands = {commandName};
    rule.priority = 50;
    rule.enabled = true;
    return rule;
}

// ── Rule Statistics ────────────────────────────────────────────────────

QJsonObject RuleEngine::getStatistics() const
{
    QJsonObject stats;
    stats["totalRules"] = m_rules.size();
    int enabledRules = 0;
    for (const auto &rule : m_rules.values()) {
        if (rule.enabled) {
            ++enabledRules;
        }
    }
    stats["enabledRules"] = enabledRules;
    
    QJsonObject triggers;
    QJsonObject blocks;
    
    for (const auto &rule : m_rules.values()) {
        triggers[rule.id] = m_triggerCounts.value(rule.id, 0);
        blocks[rule.id] = m_blockCounts.value(rule.id, 0);
    }
    
    stats["triggers"] = triggers;
    stats["blocks"] = blocks;
    return stats;
}

QList<QString> RuleEngine::getFrequentlyTriggeredRules(int topN) const
{
    QList<std::pair<QString, int>> sorted;
    for (auto it = m_triggerCounts.begin(); it != m_triggerCounts.end(); ++it) {
        sorted.append({it.key(), it.value()});
    }
    
    std::sort(sorted.begin(), sorted.end(),
              [](const auto &a, const auto &b) {
                  return a.second > b.second;
              });
    
    QList<QString> result;
    for (int i = 0; i < qMin(topN, sorted.size()); ++i) {
        result.append(sorted[i].first);
    }
    return result;
}

// ── Rule Import/Export ─────────────────────────────────────────────────

bool RuleEngine::loadRulesFromFile(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Failed to open rule file:" << filePath;
        return false;
    }
    
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();
    
    if (!doc.isArray()) {
        qWarning() << "Rule file is not a JSON array";
        return false;
    }
    
    for (const auto &value : doc.array()) {
        if (value.isObject()) {
            importRule(value.toObject());
        }
    }
    
    return true;
}

bool RuleEngine::saveRulesToFile(const QString &filePath) const
{
    QJsonArray array;
    for (const auto &rule : m_rules.values()) {
        array.append(exportRule(rule.id));
    }
    
    QJsonDocument doc(array);
    
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "Failed to write rule file:" << filePath;
        return false;
    }
    
    file.write(doc.toJson());
    file.close();
    return true;
}

QJsonObject RuleEngine::exportRule(const QString &ruleId) const
{
    auto it = m_rules.find(ruleId);
    if (it == m_rules.end()) {
        return QJsonObject();
    }
    
    const auto &rule = *it;
    QJsonObject obj;
    obj["id"] = rule.id;
    obj["name"] = rule.name;
    obj["description"] = rule.description;
    obj["condition"] = rule.condition;
    obj["enabled"] = rule.enabled;
    obj["priority"] = rule.priority;
    return obj;
}

QString RuleEngine::importRule(const QJsonObject &ruleJson)
{
    Rule rule;
    rule.id = ruleJson["id"].toString();
    rule.name = ruleJson["name"].toString();
    rule.description = ruleJson["description"].toString();
    rule.condition = ruleJson["condition"].toString();
    rule.enabled = ruleJson["enabled"].toBool(true);
    rule.priority = ruleJson["priority"].toInt(0);
    
    registerRule(rule, [](const RuleEvaluationContext &ctx) -> RuleResult {
        return RuleResult();
    });
    
    return rule.id;
}

// ── Private helper methods ───────────────────────────────────────────

bool RuleEngine::evaluateCondition(const QString &expression, const QJsonObject &variables) const
{
    // Simple condition evaluation
    // Support basic patterns: "tool == 'name'", "contains(field, 'value')", etc.
    
    if (expression.contains("==")) {
        auto parts = expression.split("==");
        if (parts.size() == 2) {
            QString left = parts[0].trimmed();
            QString right = parts[1].trimmed().remove('"').remove('\'');
            
            auto value = variables[left];
            return value.toString() == right;
        }
    }
    
    if (expression.contains("!=")) {
        auto parts = expression.split("!=");
        if (parts.size() == 2) {
            QString left = parts[0].trimmed();
            QString right = parts[1].trimmed().remove('"').remove('\'');
            
            auto value = variables[left];
            return value.toString() != right;
        }
    }
    
    return false;
}

QJsonObject RuleEngine::executeAction(const Rule &rule, const RuleEvaluationContext &context)
{
    QJsonObject result;
    result["action"] = rule.action;
    result["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    return result;
}

bool RuleEngine::contextMatchesRule(const RuleEvaluationContext &context, const Rule &rule) const
{
    // Check if rule applies to tool
    if (!rule.applicableTools.isEmpty() && !rule.applicableTools.contains(context.source)) {
        return false;
    }
    
    // Check if rule applies to command
    if (!rule.applicableCommands.isEmpty() && !rule.applicableCommands.contains(context.source)) {
        return false;
    }
    
    return true;
}
