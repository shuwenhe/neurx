#include "AdvancedHookManager.h"
#include <QDebug>

AdvancedHookManager::AdvancedHookManager(QObject* parent)
    : QObject(parent) {
}

AdvancedHookManager::~AdvancedHookManager() {
}

void AdvancedHookManager::registerHook(const HookRule& rule) {
    m_hooks[rule.id] = rule;
    emit hookRegistered(rule.id);
}

void AdvancedHookManager::unregisterHook(const QString& ruleId) {
    m_hooks.remove(ruleId);
}

void AdvancedHookManager::updateHook(const HookRule& rule) {
    if (m_hooks.contains(rule.id)) {
        m_hooks[rule.id] = rule;
    }
}

QVector<AdvancedHookManager::HookRule> AdvancedHookManager::getHooksByType(HookType type) {
    QVector<HookRule> results;
    for (const auto& hook : m_hooks.values()) {
        if (hook.type == type && hook.enabled) {
            results.append(hook);
        }
    }
    return results;
}

QVector<AdvancedHookManager::HookRule> AdvancedHookManager::getAllHooks() {
    return QVector<HookRule>(m_hooks.values().begin(), m_hooks.values().end());
}

void AdvancedHookManager::executeHooks(HookType type, const QJsonObject& context) {
    auto hooksToExecute = getHooksByType(type);
    
    // Sort by priority (higher first)
    std::sort(hooksToExecute.begin(), hooksToExecute.end(),
              [](const HookRule& a, const HookRule& b) { return a.priority > b.priority; });
    
    for (const auto& hook : hooksToExecute) {
        HookExecution execution;
        execution.ruleId = hook.id;
        execution.action = hook.action;
        execution.executionTime = QDateTime::currentMSecsSinceEpoch();
        execution.success = true;
        m_executionHistory.append(execution);
        emit hookExecuted(hook.id);
    }
}

QVector<AdvancedHookManager::HookExecution> AdvancedHookManager::getExecutionHistory() {
    return m_executionHistory;
}

void AdvancedHookManager::enableHook(const QString& ruleId) {
    if (m_hooks.contains(ruleId)) {
        m_hooks[ruleId].enabled = true;
    }
}

void AdvancedHookManager::disableHook(const QString& ruleId) {
    if (m_hooks.contains(ruleId)) {
        m_hooks[ruleId].enabled = false;
    }
}

void AdvancedHookManager::setPriority(const QString& ruleId, int priority) {
    if (m_hooks.contains(ruleId)) {
        m_hooks[ruleId].priority = priority;
    }
}

AdvancedHookManager::HookStats AdvancedHookManager::getHookStatistics() {
    HookStats stats;
    stats.totalHooks = m_hooks.size();
    stats.enabledHooks = 0;
    stats.disabledHooks = 0;
    stats.totalExecutions = m_executionHistory.size();
    stats.successfulExecutions = 0;

    for (const auto& hook : m_hooks.values()) {
        if (hook.enabled) stats.enabledHooks++;
        else stats.disabledHooks++;
    }

    for (const auto& exec : m_executionHistory) {
        if (exec.success) stats.successfulExecutions++;
    }

    if (stats.totalExecutions > 0) {
        stats.successRate = static_cast<float>(stats.successfulExecutions) / stats.totalExecutions;
    }

    return stats;
}
