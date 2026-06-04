#pragma once

#include "HookSystem.h"
#include <QMap>
#include <QMutex>
#include <QElapsedTimer>

namespace neurx {

/**
 * @class DefaultHookSystem
 * @brief Default implementation of the hook system
 */
class DefaultHookSystem : public HookSystem {
    Q_OBJECT
    
public:
    explicit DefaultHookSystem(QObject* parent = nullptr);
    ~DefaultHookSystem() override = default;
    
    // HookSystem interface
    QString registerHook(const HookDefinition& definition,
                        HookHandler handler) override;
    bool unregisterHook(const QString& hookId) override;
    bool hasHook(const QString& hookId) const override;
    bool setHookEnabled(const QString& hookId, bool enabled) override;
    
    QList<HookDefinition> getAllHooks() const override;
    QList<HookDefinition> getHooksByType(HookType type) const override;
    HookDefinition getHookDefinition(const QString& hookId) const override;
    
    bool triggerHook(HookEvent& event) override;
    bool triggerHooksByType(HookType type, const QVariantMap& data) override;
    bool matchesFilters(const HookDefinition& definition,
                       const HookEvent& event) const override;
    
    QVariantMap getHookStats(const QString& hookId) const override;
    QVariantMap getAllHooksStats() const override;
    
    // Built-in hooks
    void registerBuiltInHooks();
    
private:
    struct HookEntry {
        HookDefinition definition;
        HookHandler handler;
        bool enabled;
        
        // Statistics
        int executionCount;
        int successCount;
        int failureCount;
        qint64 totalExecutionTimeMs;
        QDateTime lastExecuted;
        QString lastError;
    };
    
    // Hook storage
    QMap<QString, HookEntry> m_hooks;
    QMultiMap<HookType, QString> m_hooksByType; // type -> hook ID
    mutable QMutex m_mutex;
    
    // Helper methods
    bool evaluateCondition(const QString& condition,
                          const HookEvent& event) const;
    bool matchesFilePatterns(const QStringList& patterns,
                            const QString& filePath) const;
    bool matchesToolPatterns(const QStringList& patterns,
                            const QString& toolName) const;
    HookResult executeHook(HookEntry& entry, HookEvent& event);
    void updateStats(HookEntry& entry, const HookResult& result);
    
    // Built-in hook handlers
    HookResult handleSecurityHook(HookEvent& event);
    HookResult handleLoggingHook(HookEvent& event);
    HookResult handleSessionTrackingHook(HookEvent& event);
};

} // namespace neurx
