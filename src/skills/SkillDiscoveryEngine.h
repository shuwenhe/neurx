#pragma once

#include "ClaudeSkillTypes.h"
#include <QString>
#include <QVector>
#include <QMap>
#include <memory>
#include <functional>

/**
 * @class SkillDiscoveryEngine
 * @brief Discovers and loads Claude-style skills from the filesystem
 * 
 * Responsibilities:
 * - Recursive directory scanning for SKILL.md files
 * - YAML frontmatter parsing
 * - Platform compatibility filtering
 * - Change detection and caching
 */
class SkillDiscoveryEngine {
public:
    using DiscoveryCallback = std::function<void(const QVector<ClaudeSkill> &skills, const QString &error)>;
    
    SkillDiscoveryEngine();
    virtual ~SkillDiscoveryEngine() = default;
    
    // ── Discovery ──────────────────────────────────────────
    
    /// Discover all skills in a directory
    virtual void discoverSkills(
        const QString &baseDirectory,
        const Platform &currentPlatform,
        bool recursive,
        DiscoveryCallback callback
    ) = 0;
    
    /// Discover skills asynchronously (non-blocking)
    virtual void discoverSkillsAsync(
        const QString &baseDirectory,
        const Platform &currentPlatform,
        bool recursive,
        DiscoveryCallback callback
    ) = 0;
    
    // ── Individual Skill Loading ───────────────────────────
    
    /// Load a specific skill from file
    virtual ClaudeSkill loadSkill(const QString &filePath, const Platform &platform) = 0;
    
    /// Reload skill if file changed
    virtual void reloadSkillIfModified(ClaudeSkill &skill, const Platform &platform) = 0;
    
    // ── Parsing ────────────────────────────────────────────
    
    /// Parse YAML frontmatter from SKILL.md content
    virtual ClaudeSkillMetadata parseYamlFrontmatter(const QString &fileContent) = 0;
    
    /// Parse markdown body after frontmatter
    virtual QString parseMarkdownBody(const QString &fileContent) = 0;
    
    // ── Validation ─────────────────────────────────────────
    
    /// Validate if skill is compatible with platform
    virtual bool isPlatformCompatible(const ClaudeSkill &skill, const Platform &platform) = 0;
    
    /// Validate skill metadata completeness
    virtual QStringList validateSkillMetadata(const ClaudeSkillMetadata &metadata) = 0;
    
    // ── Caching ────────────────────────────────────────────
    
    /// Clear the discovery cache
    virtual void clearCache() = 0;
    
    /// Get cache statistics
    virtual QVariantMap getCacheStats() const = 0;
};

/**
 * @class DefaultSkillDiscoveryEngine
 * @brief Default implementation of SkillDiscoveryEngine
 */
class DefaultSkillDiscoveryEngine : public SkillDiscoveryEngine {
public:
    DefaultSkillDiscoveryEngine();
    ~DefaultSkillDiscoveryEngine() override = default;
    
    void discoverSkills(
        const QString &baseDirectory,
        const Platform &currentPlatform,
        bool recursive,
        DiscoveryCallback callback
    ) override;
    
    void discoverSkillsAsync(
        const QString &baseDirectory,
        const Platform &currentPlatform,
        bool recursive,
        DiscoveryCallback callback
    ) override;
    
    ClaudeSkill loadSkill(const QString &filePath, const Platform &platform) override;
    void reloadSkillIfModified(ClaudeSkill &skill, const Platform &platform) override;
    
    ClaudeSkillMetadata parseYamlFrontmatter(const QString &fileContent) override;
    QString parseMarkdownBody(const QString &fileContent) override;
    
    bool isPlatformCompatible(const ClaudeSkill &skill, const Platform &platform) override;
    QStringList validateSkillMetadata(const ClaudeSkillMetadata &metadata) override;
    
    void clearCache() override;
    QVariantMap getCacheStats() const override;
    
private:
    /// Find all SKILL.md files recursively
    QStringList findSkillFiles(const QString &baseDirectory, bool recursive) const;
    
    /// Parse YAML frontmatter (between --- delimiters)
    bool extractYamlFrontmatter(const QString &fileContent,
                               QString &yamlContent,
                               QString &bodyContent) const;
    
    /// Parse YAML key-value pairs (simplified - no nested structures)
    QMap<QString, QVariant> parseYamlMap(const QString &yamlContent) const;
    
    /// Parse environment variables from YAML
    QVector<EnvironmentVariableDef> parseEnvironmentVariables(const QVariant &yamlVar) const;
    
    /// Parse prerequisites from YAML
    QVector<Prerequisite> parsePrerequisites(const QVariant &yamlVar) const;
    
    /// Calculate file checksum for change detection
    QString calculateChecksum(const QString &filePath) const;
    
    // Cache
    QMap<QString, ClaudeSkill> m_skillCache;
    QMap<QString, QDateTime> m_fileModificationTimes;
};
