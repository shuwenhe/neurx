#pragma once

#include "ClaudeSkillTypes.h"
#include "SkillDiscoveryEngine.h"
#include "SkillEnvironmentManager.h"
#include <QString>
#include <QObject>
#include <QMap>
#include <QVector>
#include <memory>
#include <functional>

/**
 * @class ClaudeSkillManager
 * @brief Complete Claude-style skill management system
 * 
 * Provides:
 * - Tier 1: Lightweight skill listings (names, descriptions)
 * - Tier 2: Full skill views with complete metadata
 * - Tier 3: Full content with markdown body
 * - Environment variable management
 * - Progressive context generation for LLMs
 * - Platform-aware filtering
 * - Change detection and hot-reload
 */
class ClaudeSkillManager : public QObject {
    Q_OBJECT
public:
    ClaudeSkillManager(QObject *parent = nullptr);
    virtual ~ClaudeSkillManager() = default;
    
    // ── Initialization ─────────────────────────────────────
    
    /// Initialize skill system with base directory
    /// Returns: error message if any, empty string on success
    virtual QString initialize(const QString &skillsDirectory);
    
    /// Set current platform for compatibility filtering
    virtual void setPlatform(Platform platform);
    
    /// Get current platform
    virtual Platform getPlatform() const;
    
    // ── Tier 1: Skills List (lightweight) ──────────────────
    
    /// Get all available skills (name, description, tags only)
    virtual void getSkillsList(ClaudeSkillsListCallback callback);
    
    /// Search skills (Tier 1)
    virtual void searchSkills(
        const QString &query,
        const QStringList &tags = QStringList(),
        int maxResults = 10,
        ClaudeSkillSearchCallback callback = nullptr
    );
    
    // ── Tier 2: Skill View (full metadata) ─────────────────
    
    /// Get complete skill information
    virtual void getSkillView(
        const QString &skillId,
        ClaudeSkillViewCallback callback
    );
    
    // ── Tier 3: Full Content ──────────────────────────────
    
    /// Get skill with complete markdown body
    virtual ClaudeSkill getSkillWithContent(const QString &skillId);

    /// Get full markdown instructions for a skill
    virtual QString skillInstructions(const QString &skillId) const;
    
    // ── Environment Variables ──────────────────────────────
    
    /// Check if skill has all required environment variables
    virtual bool areEnvironmentVariablesReady(const QString &skillId);
    
    /// Collect missing environment variables for skill
    virtual void collectEnvironmentVariables(
        const QString &skillId,
        DefaultSkillEnvironmentManager::EnvPromptCallback promptCallback,
        DefaultSkillEnvironmentManager::EnvSecretCallback secretCallback,
        DefaultSkillEnvironmentManager::EnvCollectedCallback resultCallback
    );
    
    // ── Availability ──────────────────────────────────────
    
    /// Check availability for all skills
    virtual void checkAllAvailability(ClaudeSkillAvailabilityCallback callback);
    
    /// Check availability for specific skill
    virtual SkillAvailabilityCheck checkSkillAvailability(const QString &skillId);
    
    /// Get all available skills for current context
    virtual QVector<SkillCapability> getAvailableSkills();
    
    // ── LLM Context Generation ────────────────────────────
    
    /// Generate skill context for LLM (with tier selection)
    /// Tier 1: ~50 tokens (names + descriptions)
    /// Tier 2: ~500 tokens (full metadata)
    /// Tier 3: ~1500 tokens (with examples)
    virtual void generateSkillContextForLLM(
        int tier = 1,                                  ///< 1, 2, or 3
        int maxSkills = 10,
        const QVariantMap &currentContext = QVariantMap(),
        ClaudeSkillContextCallback callback = nullptr
    );
    
    /// Get context string formatted for inclusion in LLM prompt
    virtual QString getSkillsContextMarkdown(
        int tier = 1,
        int maxSkills = 10
    );
    
    // ── Skill Execution (optional) ─────────────────────────
    
    /// Execute a skill with parameters
    virtual void executeSkill(
        const SkillExecutionRequest &request,
        ClaudeSkillExecutionCallback callback
    );
    
    // ── Refreshing ─────────────────────────────────────────
    
    /// Reload skills from disk
    virtual void refresh(std::function<void(int count, const QString &error)> callback);
    
    /// Check for modified skills on disk
    virtual void checkForModifications();
    
    // ── Querying ───────────────────────────────────────────
    
    /// Get skill by ID (may return empty if not found)
    virtual ClaudeSkill getSkill(const QString &skillId) const;
    
    /// Get all skills
    virtual QVector<ClaudeSkill> getAllSkills() const;
    
    /// Get skill count
    virtual int getSkillCount() const;
    
    /// Get skills by category
    virtual QVector<ClaudeSkill> getSkillsByCategory(const QString &category) const;
    
    /// Get skills by tag
    virtual QVector<ClaudeSkill> getSkillsByTag(const QString &tag) const;
    
    // ── Statistics ──────────────────────────────────────────
    
    /// Get manager statistics
    virtual QVariantMap getStatistics() const;
    
    // ── Signals ────────────────────────────────────────────
    
signals:
    /// Emitted when skills are discovered/reloaded
    void skillsDiscovered(int count);
    
    /// Emitted when a skill is modified on disk
    void skillModified(const QString &skillId);
    
    /// Emitted when a skill becomes available/unavailable
    void skillAvailabilityChanged(const QString &skillId, bool available);
    
private:
    /// Format skills for Tier 1 context
    QString formatTier1Context(const QVector<SkillListingItem> &skills) const;
    
    /// Format skills for Tier 2 context
    QString formatTier2Context(const QVector<SkillViewItem> &skills) const;
    
    /// Format skills for Tier 3 context (with examples)
    QString formatTier3Context(const QVector<ClaudeSkill> &skills) const;
    
    // Members
    QString m_skillsDirectory;
    Platform m_platform{Platform::Any};
    
    QMap<QString, ClaudeSkill> m_skills;
    std::unique_ptr<SkillDiscoveryEngine> m_discoveryEngine;
    std::unique_ptr<SkillEnvironmentManager> m_envManager;
    
    QMap<QString, SkillAvailabilityCheck> m_availabilityCache;
};
