#pragma once

#ifndef NEURX_DEFAULT_SKILL_MANAGER_H
#define NEURX_DEFAULT_SKILL_MANAGER_H

#include "SkillManager.h"
#include <QMap>
#include <QVector>
#include <QMutex>

/**
 * @class DefaultSkillManager
 * @brief Default skill manager implementation
 * 
 * Features:
 * - Skill registration and discovery
 * - Context-aware availability checking
 * - Parameter validation
 * - LLM context rendering
 * - Skill invocation history
 */
class DefaultSkillManager : public SkillManager {
    Q_OBJECT
public:
    explicit DefaultSkillManager(QObject *parent = nullptr);
    ~DefaultSkillManager() = default;
    
    // Discovery
    void registerSkill(const SkillCapability &skill,
                      std::function<void(bool success)> callback) override;
    void unregisterSkill(const QString &skillId,
                        std::function<void(bool success)> callback) override;
    QVector<SkillCapability> getAllSkills() const override;
    SkillCapability getSkill(const QString &skillId) const override;
    QVector<SkillCapability> searchSkills(const SkillFilter &filter) const override;
    
    // Availability
    QVector<SkillAvailability> checkAvailability(const QVariantMap &context) const override;
    SkillAvailability checkSkillAvailability(const QString &skillId,
                                             const QVariantMap &context) const override;
    QVector<SkillCapability> getAvailableSkills(const QVariantMap &context) const override;
    
    // Invocation
    void invokeSkill(const SkillInvocation &invocation,
                    SkillCallback callback) override;
    void invokeSkills(const QVector<SkillInvocation> &invocations,
                     std::function<void(const QVector<SkillResult> &results)> callback) override;
    void cancelSkillInvocation(const QString &invocationId,
                              std::function<void(bool success)> callback) override;
    
    // Context
    void updateContext(const QVariantMap &context) override;
    QVariantMap getCurrentContext() const override;
    
    // LLM Integration
    QVector<SkillMention> getSkillsForLLMContext(const QVariantMap &context,
                                                 int maxSkills = 10) const override;
    QString renderSkillsForLLM(const QVector<SkillMention> &mentions) const override;
    QVector<SkillCapability> getRelevantSkills(const QString &userQuery,
                                               const QVariantMap &context,
                                               int maxResults = 5) const override;
    
    // Configuration
    void setSkillPolicy(const QString &skillId,
                       SkillPolicy policy) override;
    SkillPolicy getSkillPolicy(const QString &skillId) const override;
    void setSkillEnabled(const QString &skillId, bool enabled) override;
    bool isSkillEnabled(const QString &skillId) const override;
    
    // History
    QVector<SkillResult> getSkillHistory(const QString &skillId,
                                         int limit = 100) const override;
    QVector<SkillResult> getInvocationHistory(int limit = 100) const override;
    void clearHistory(std::function<void(bool success)> callback) override;
    
    // Statistics
    QVariantMap getSkillStats(const QString &skillId) const override;
    QVariantMap getAllStats() const override;
    
    // Validation
    bool validateSkillParameters(const QString &skillId,
                                const QVariantMap &parameters,
                                QString &errorMsg) override;
    QVariantMap getParameterSchema(const QString &skillId) const override;

private:
    struct SkillEntry {
        SkillCapability capability;
        SkillPolicy policy{SkillPolicy::Auto};
        bool enabled{true};
        int invocationCount{0};
        int totalTokensUsed{0};
        int successCount{0};
        int errorCount{0};
        QDateTime lastInvokedAt;
    };
    
    QMap<QString, SkillEntry> m_skills;
    QVariantMap m_context;
    QVector<SkillResult> m_invocationHistory;
    mutable QMutex m_mutex;
    
    // Helpers
    bool validateParameter(const SkillParameter &param, const QVariant &value);
    int calculateRelevanceScore(const SkillCapability &skill,
                               const QString &query,
                               const QVariantMap &context) const;
    QString formatSkillForLLM(const SkillMention &mention) const;
};

using DefaultSkillManagerPtr = std::shared_ptr<DefaultSkillManager>;

#endif // NEURX_DEFAULT_SKILL_MANAGER_H
