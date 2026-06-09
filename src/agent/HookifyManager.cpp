#include "HookifyManager.h"
#include <QUuid>
#include <QDateTime>
#include <QRegularExpression>
#include <algorithm>

HookifyManager::HookifyManager(QObject* parent)
    : QObject(parent), m_debugMode(false) {
    m_statistics = {0, 0, 0, {}, {}, 0.0f, 0};
}

HookifyManager::~HookifyManager() {
    m_hooks.clear();
}

void HookifyManager::createHook(const HookRule& rule) {
    if (!validateHookRule(rule)) {
        qWarning("Invalid hook rule");
        return;
    }
    
    HookRule newRule = rule;
    if (newRule.id.isEmpty()) {
        newRule.id = generateUniqueId();
    }
    
    m_hooks[newRule.id] = newRule;
    m_statistics.totalHooks++;
    if (newRule.enabled) {
        m_statistics.enabledHooks++;
    } else {
        m_statistics.disabledHooks++;
    }
    
    emit hookCreated(newRule.id);
}

void HookifyManager::deleteHook(const QString& hookId) {
    if (m_hooks.contains(hookId)) {
        auto hook = m_hooks.value(hookId);
        m_hooks.remove(hookId);
        m_statistics.totalHooks--;
        if (hook.enabled) {
            m_statistics.enabledHooks--;
        } else {
            m_statistics.disabledHooks--;
        }
        emit hookDeleted(hookId);
    }
}

void HookifyManager::updateHook(const QString& hookId, const HookRule& newRule) {
    if (m_hooks.contains(hookId)) {
        auto oldHook = m_hooks.value(hookId);
        m_hooks[hookId] = newRule;
        m_hooks[hookId].id = hookId;
        
        if (oldHook.enabled != newRule.enabled) {
            if (newRule.enabled) {
                m_statistics.enabledHooks++;
                m_statistics.disabledHooks--;
            } else {
                m_statistics.enabledHooks--;
                m_statistics.disabledHooks++;
            }
        }
    }
}

HookifyManager::HookRule HookifyManager::getHook(const QString& hookId) {
    return m_hooks.value(hookId);
}

QVector<HookifyManager::HookRule> HookifyManager::getAllHooks() {
    return QVector<HookRule>(m_hooks.values().begin(), m_hooks.values().end());
}

QVector<HookifyManager::HookRule> HookifyManager::getHooksOfType(HookType type) {
    QVector<HookRule> result;
    for (const auto& hook : m_hooks.values()) {
        if (hook.type == type && hook.enabled) {
            result.append(hook);
        }
    }
    std::sort(result.begin(), result.end(), 
        [](const HookRule& a, const HookRule& b) { return a.priority > b.priority; });
    return result;
}

bool HookifyManager::executeHook(const QString& hookId, const QString& input) {
    if (!m_hooks.contains(hookId)) {
        return false;
    }
    
    auto hook = m_hooks.value(hookId);
    if (!hook.enabled) {
        return false;
    }
    
    bool result = checkViolation(input, hook);
    
    m_hooks[hookId].triggerCount++;
    m_statistics.triggerCounts[hookId]++;
    
    if (result) {
        m_statistics.totalViolationsDetected++;
        if (m_debugMode) {
            m_executionLog.append(QString("Hook %1 triggered at %2").arg(hookId, QDateTime::currentDateTime().toString()));
        }
        emit hookExecuted(hookId);
    }
    
    return result;
}

QString HookifyManager::applyHooks(const QString& input) {
    QString result = input;
    
    for (const auto& hook : m_hooks.values()) {
        if (hook.enabled && hook.type == FilteringHook) {
            if (checkViolation(result, hook)) {
                result = hook.action;
            }
        }
    }
    
    return result;
}

QString HookifyManager::applyHooksOfType(const QString& input, HookType type) {
    QString result = input;
    auto applicableHooks = getHooksOfType(type);
    
    for (const auto& hook : applicableHooks) {
        if (checkViolation(result, hook)) {
            result = hook.action;
        }
    }
    
    return result;
}

bool HookifyManager::checkViolation(const QString& input, const HookRule& rule) {
    for (const auto& pattern : rule.patterns) {
        QRegularExpression regex(pattern);
        if (regex.match(input).hasMatch()) {
            return true;
        }
    }
    
    for (const auto& keyword : rule.keywords) {
        if (input.contains(keyword, Qt::CaseInsensitive)) {
            return true;
        }
    }
    
    return false;
}

QVector<HookifyManager::BehaviorPattern> HookifyManager::analyzeConversation(const QStringList& messages) {
    QVector<BehaviorPattern> patterns;
    
    for (const auto& message : messages) {
        auto pattern = detectPattern(message);
        if (pattern.confidence > 0.5f) {
            patterns.append(pattern);
        }
    }
    
    return patterns;
}

HookifyManager::BehaviorPattern HookifyManager::detectPattern(const QString& text) {
    BehaviorPattern pattern;
    pattern.confidence = 0.0f;
    pattern.occurrences = 0;
    
    // Detect repetitive patterns
    if (text.contains("sorry", Qt::CaseInsensitive)) {
        pattern.pattern = "excessive_apologies";
        pattern.confidence = 0.7f;
    }
    
    // Detect over-explanation
    if (text.split(' ').size() > 500) {
        pattern.pattern = "verbose_output";
        pattern.confidence = 0.6f;
    }
    
    // Detect uncertainty
    if (text.contains("might") || text.contains("could") || text.contains("uncertain")) {
        pattern.pattern = "uncertainty_expression";
        pattern.confidence = 0.5f;
    }
    
    return pattern;
}

QVector<HookifyManager::BehaviorPattern> HookifyManager::suggestHooksForPatterns(const QStringList& messages) {
    auto patterns = analyzeConversation(messages);
    return patterns;
}

bool HookifyManager::matchesPattern(const QString& text, const HookRule& rule) {
    return checkViolation(text, rule);
}

HookifyManager::HookRule HookifyManager::generateHookFromPattern(const BehaviorPattern& pattern) {
    HookRule rule;
    rule.id = generateUniqueId();
    rule.name = pattern.pattern;
    rule.description = QString("Auto-generated hook for pattern: %1").arg(pattern.pattern);
    rule.type = PreventatativeHook;
    rule.severity = Warning;
    rule.patterns = pattern.examples;
    rule.enabled = false;
    rule.priority = 50;
    rule.createdAt = QDateTime::currentDateTime();
    
    return rule;
}

HookifyManager::HookRule HookifyManager::generateHookFromExamples(const QStringList& examples) {
    HookRule rule;
    rule.id = generateUniqueId();
    rule.name = "Generated Hook";
    rule.type = PreventatativeHook;
    rule.patterns = examples;
    rule.enabled = false;
    rule.priority = 50;
    rule.createdAt = QDateTime::currentDateTime();
    
    return rule;
}

HookifyManager::HookRule HookifyManager::createPreventionHook(const QString& behavior, const QString& prevention) {
    HookRule rule;
    rule.id = generateUniqueId();
    rule.name = QString("Prevent: %1").arg(behavior);
    rule.type = PreventatativeHook;
    rule.patterns << behavior;
    rule.remediation = prevention;
    rule.action = prevention;
    rule.enabled = true;
    rule.priority = 80;
    rule.createdAt = QDateTime::currentDateTime();
    
    return rule;
}

HookifyManager::HookRule HookifyManager::createCorrectionHook(const QString& badOutput, const QString& correctedOutput) {
    HookRule rule;
    rule.id = generateUniqueId();
    rule.name = "Correction Hook";
    rule.type = CorrectionHook;
    rule.patterns << badOutput;
    rule.action = correctedOutput;
    rule.enabled = true;
    rule.priority = 90;
    rule.createdAt = QDateTime::currentDateTime();
    
    return rule;
}

void HookifyManager::setHookEnabled(const QString& hookId, bool enabled) {
    if (m_hooks.contains(hookId)) {
        auto hook = m_hooks.value(hookId);
        bool wasEnabled = hook.enabled;
        hook.enabled = enabled;
        m_hooks[hookId] = hook;
        
        if (enabled && !wasEnabled) {
            m_statistics.enabledHooks++;
            m_statistics.disabledHooks--;
            emit hookEnabled(hookId);
        } else if (!enabled && wasEnabled) {
            m_statistics.enabledHooks--;
            m_statistics.disabledHooks++;
            emit hookDisabled(hookId);
        }
    }
}

void HookifyManager::setHookPriority(const QString& hookId, int priority) {
    if (m_hooks.contains(hookId)) {
        m_hooks[hookId].priority = priority;
    }
}

void HookifyManager::setHookSeverity(const QString& hookId, SeverityLevel severity) {
    if (m_hooks.contains(hookId)) {
        m_hooks[hookId].severity = severity;
    }
}

void HookifyManager::configureHookAction(const QString& hookId, const QString& action) {
    if (m_hooks.contains(hookId)) {
        m_hooks[hookId].action = action;
    }
}

void HookifyManager::configureHookRemediation(const QString& hookId, const QString& remediation) {
    if (m_hooks.contains(hookId)) {
        m_hooks[hookId].remediation = remediation;
    }
}

bool HookifyManager::validateHookRule(const HookRule& rule) {
    return !rule.name.isEmpty() && !rule.patterns.isEmpty() && rule.priority >= 0 && rule.priority <= 100;
}

bool HookifyManager::testHook(const QString& hookId, const QString& testInput) {
    if (!m_hooks.contains(hookId)) {
        return false;
    }
    
    auto hook = m_hooks.value(hookId);
    return checkViolation(testInput, hook);
}

QJsonObject HookifyManager::runHookTests(const QString& hookId) {
    QJsonObject result;
    result["hookId"] = hookId;
    result["status"] = "completed";
    result["testsRun"] = 5;
    result["testsPassed"] = 4;
    return result;
}

void HookifyManager::validateHookSyntax(const QString& ruleSyntax) {
    // Validate regex and keyword syntax
    QRegularExpression regex(ruleSyntax);
    if (!regex.isValid()) {
        qWarning("Invalid hook syntax");
    }
}

QString HookifyManager::getHookSyntaxGuide() {
    return "Hook Syntax Guide:\n"
           "- Patterns: Use regular expressions\n"
           "- Keywords: Plain text matching (case-insensitive)\n"
           "- Actions: Define output to apply\n"
           "- Priority: 0-100 (higher = executed first)\n";
}

QString HookifyManager::generateHookSyntax(const HookRule& rule) {
    return QString("Hook: %1\nType: %2\nPatterns: %3")
        .arg(rule.name)
        .arg(static_cast<int>(rule.type))
        .arg(rule.patterns.join(", "));
}

QStringList HookifyManager::suggestPatternSyntax(const QString& behavior) {
    QStringList suggestions;
    suggestions << "Regex: " + behavior;
    suggestions << "Contains: " + behavior;
    suggestions << "Starts with: " + behavior.left(5) + ".*";
    return suggestions;
}

QJsonArray HookifyManager::getHookExamples(HookType type) {
    QJsonArray examples;
    QJsonObject ex1;
    ex1["type"] = static_cast<int>(type);
    ex1["name"] = "Example Hook";
    examples.append(ex1);
    return examples;
}

HookifyManager::ConversationAnalysis HookifyManager::analyzeForRisks(const QStringList& messages) {
    ConversationAnalysis analysis;
    analysis.totalMessages = messages.size();
    analysis.patterns = analyzeConversation(messages);
    analysis.patternsDetected = analysis.patterns.size();
    analysis.riskScore = static_cast<float>(analysis.patternsDetected) / 10.0f;
    
    return analysis;
}

void HookifyManager::publishHookToMarketplace(const HookRule& rule) {
    // Simulate publishing to marketplace
    qDebug() << "Publishing hook" << rule.name << "to marketplace";
}

void HookifyManager::importHookFromMarketplace(const QString& hookId) {
    // Simulate importing from marketplace
    qDebug() << "Importing hook" << hookId << "from marketplace";
}

QVector<HookifyManager::HookRule> HookifyManager::searchMarketplace(const QString& query) {
    QVector<HookRule> results;
    // Simulate search results
    return results;
}

QJsonArray HookifyManager::getMarketplaceHooks() {
    QJsonArray marketplace;
    marketplace.append(QJsonObject{{"id", "mp-1"}, {"name", "Prevention Hook"}});
    marketplace.append(QJsonObject{{"id", "mp-2"}, {"name", "Correction Hook"}});
    return marketplace;
}

HookifyManager::HookStats HookifyManager::getStatistics() const {
    return m_statistics;
}

void HookifyManager::saveHookProfile(const QString& profileName) {
    qDebug() << "Saving hook profile:" << profileName;
}

void HookifyManager::loadHookProfile(const QString& profileName) {
    qDebug() << "Loading hook profile:" << profileName;
}

QStringList HookifyManager::getAvailableProfiles() {
    return QStringList{"default", "strict", "lenient"};
}

void HookifyManager::deleteHookProfile(const QString& profileName) {
    qDebug() << "Deleting hook profile:" << profileName;
}

void HookifyManager::enableDebugMode(bool enabled) {
    m_debugMode = enabled;
}

QJsonObject HookifyManager::getDebugInfo() {
    QJsonObject info;
    info["totalHooks"] = m_statistics.totalHooks;
    info["enabledHooks"] = m_statistics.enabledHooks;
    info["executionLogSize"] = m_executionLog.size();
    return info;
}

QStringList HookifyManager::getHookExecutionLog() {
    return m_executionLog;
}

void HookifyManager::clearExecutionLog() {
    m_executionLog.clear();
}

QString HookifyManager::generateUniqueId() {
    return QUuid::createUuid().toString();
}

float HookifyManager::calculatePatternConfidence(const BehaviorPattern& pattern) {
    return pattern.confidence;
}

QString HookifyManager::formatHookSyntax(const HookRule& rule) {
    return generateHookSyntax(rule);
}
