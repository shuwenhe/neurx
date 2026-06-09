#pragma once

#include <QString>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class AdvancedHookManager
 * @brief Advanced hook management and behavioral control
 */

class AdvancedHookManager : public QObject {
    Q_OBJECT

public:
    enum HookType {
        PreAction,
        PostAction,
        PreToolUse,
        PostToolUse,
        SessionStart,
        SessionEnd,
        ConversationAnalysis,
        OutputGeneration
    };

    struct HookRule {
        QString id;
        HookType type;
        QString triggerCondition;
        QString action;
        QString description;
        int priority;  // 0-100, higher = executed first
        bool enabled;
    };

    struct HookExecution {
        QString ruleId;
        QString action;
        qint64 executionTime;
        bool success;
        QString result;
    };

    explicit AdvancedHookManager(QObject* parent = nullptr);
    ~AdvancedHookManager();

    void registerHook(const HookRule& rule);
    void unregisterHook(const QString& ruleId);
    void updateHook(const HookRule& rule);

    QVector<HookRule> getHooksByType(HookType type);
    QVector<HookRule> getAllHooks();

    void executeHooks(HookType type, const QJsonObject& context);
    QVector<HookExecution> getExecutionHistory();

    void enableHook(const QString& ruleId);
    void disableHook(const QString& ruleId);
    void setPriority(const QString& ruleId, int priority);

    struct HookStats {
        int totalHooks;
        int enabledHooks;
        int disabledHooks;
        int totalExecutions;
        int successfulExecutions;
        float successRate;
    };
    HookStats getHookStatistics();

signals:
    void hookRegistered(const QString& ruleId);
    void hookExecuted(const QString& ruleId);
    void hookTriggered(const QString& ruleId, const QString& action);
    void behaviorPrevented();

private:
    QMap<QString, HookRule> m_hooks;
    QVector<HookExecution> m_executionHistory;
};
