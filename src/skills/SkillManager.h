#pragma once

#ifndef NEURX_SKILL_MANAGER_H
#define NEURX_SKILL_MANAGER_H

#include "SkillTypes.h"
#include <QObject>
#include <memory>

/**
 * @class SkillManager
 * @brief Skill management interface
 * 
 * Handles:
 * - Skill discovery and registration
 * - Availability checking
 * - Skill invocation
 * - Context-aware suggestions
 * - Skill mention rendering for LLM
 */
class SkillManager : public QObject {
    Q_OBJECT
public:
    explicit SkillManager(QObject *parent = nullptr) : QObject(parent) {}
    virtual ~SkillManager() = default;
    
    // ── Discovery ──────────────────────────────────────────────
    
    /// Register skill
    virtual void registerSkill(const SkillCapability &skill,
                              std::function<void(bool success)> callback) = 0;
    
    /// Unregister skill
    virtual void unregisterSkill(const QString &skillId,
                               std::function<void(bool success)> callback) = 0;
    
    /// Get all registered skills
    virtual QVector<SkillCapability> getAllSkills() const = 0;
    
    /// Get skill by ID
    virtual SkillCapability getSkill(const QString &skillId) const = 0;
    
    /// Search skills
    virtual QVector<SkillCapability> searchSkills(const SkillFilter &filter) const = 0;
    
    // ── Availability ──────────────────────────────────────────
    
    /// Check availability for all skills
    virtual QVector<SkillAvailability> checkAvailability(const QVariantMap &context) const = 0;
    
    /// Check availability for specific skill
    virtual SkillAvailability checkSkillAvailability(const QString &skillId,
                                                     const QVariantMap &context) const = 0;
    
    /// Get skills available in current context
    virtual QVector<SkillCapability> getAvailableSkills(const QVariantMap &context) const = 0;
    
    // ── Invocation ─────────────────────────────────────────────
    
    /// Invoke skill with parameters
    virtual void invokeSkill(const SkillInvocation &invocation,
                            SkillCallback callback) = 0;
    
    /// Invoke multiple skills
    virtual void invokeSkills(const QVector<SkillInvocation> &invocations,
                             std::function<void(const QVector<SkillResult> &results)> callback) = 0;
    
    /// Cancel skill invocation
    virtual void cancelSkillInvocation(const QString &invocationId,
                                      std::function<void(bool success)> callback) = 0;
    
    // ── Context ────────────────────────────────────────────────
    
    /// Update context
    virtual void updateContext(const QVariantMap &context) = 0;
    
    /// Get current context
    virtual QVariantMap getCurrentContext() const = 0;
    
    // ── LLM Integration ────────────────────────────────────────
    
    /// Get skills to mention in LLM context
    virtual QVector<SkillMention> getSkillsForLLMContext(const QVariantMap &context,
                                                         int maxSkills = 10) const = 0;
    
    /// Render skill mentions as text for LLM
    virtual QString renderSkillsForLLM(const QVector<SkillMention> &mentions) const = 0;
    
    /// Get relevant skills for user query
    virtual QVector<SkillCapability> getRelevantSkills(const QString &userQuery,
                                                       const QVariantMap &context,
                                                       int maxResults = 5) const = 0;
    
    // ── Configuration ──────────────────────────────────────────
    
    /// Set skill policy
    virtual void setSkillPolicy(const QString &skillId,
                               SkillPolicy policy) = 0;
    
    /// Get skill policy
    virtual SkillPolicy getSkillPolicy(const QString &skillId) const = 0;
    
    /// Enable/disable skill
    virtual void setSkillEnabled(const QString &skillId, bool enabled) = 0;
    
    /// Check if skill is enabled
    virtual bool isSkillEnabled(const QString &skillId) const = 0;
    
    // ── History & Tracking ────────────────────────────────────
    
    /// Get skill invocation history
    virtual QVector<SkillResult> getSkillHistory(const QString &skillId,
                                                 int limit = 100) const = 0;
    
    /// Get all invocation history
    virtual QVector<SkillResult> getInvocationHistory(int limit = 100) const = 0;
    
    /// Clear history
    virtual void clearHistory(std::function<void(bool success)> callback) = 0;
    
    // ── Statistics ────────────────────────────────────────────
    
    /// Get skill statistics
    virtual QVariantMap getSkillStats(const QString &skillId) const = 0;
    
    /// Get all statistics
    virtual QVariantMap getAllStats() const = 0;
    
    // ── Validation ─────────────────────────────────────────────
    
    /// Validate skill parameters
    virtual bool validateSkillParameters(const QString &skillId,
                                        const QVariantMap &parameters,
                                        QString &errorMsg) = 0;
    
    /// Get parameter schema
    virtual QVariantMap getParameterSchema(const QString &skillId) const = 0;

signals:
    /// Skill invoked signal
    void skillInvoked(const QString &skillId, const SkillInvocation &invocation);
    
    /// Skill completed signal
    void skillCompleted(const QString &skillId, const SkillResult &result);
    
    /// Skill error signal
    void skillError(const QString &skillId, const QString &errorMessage);
    
    /// Skill registered signal
    void skillRegistered(const QString &skillId);
    
    /// Skill unregistered signal
    void skillUnregistered(const QString &skillId);
    
    /// Context changed signal
    void contextChanged(const QVariantMap &newContext);
    
    /// Skill notification signal
    void skillNotification(const SkillNotification &notification);
};

using SkillManagerPtr = std::shared_ptr<SkillManager>;

#endif // NEURX_SKILL_MANAGER_H
