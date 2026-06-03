#pragma once

#include "SkillTypes.h"
#include <QString>
#include <QVariantMap>
#include <QStringList>
#include <QDateTime>
#include <QMap>
#include <memory>

/**
 * @class ClaudeSkillTypes
 * @brief Claude-style skill system type definitions
 * 
 * Implements the Claude Skills system with:
 * - Markdown + YAML frontmatter skills format
 * - Progressive skill disclosure (list → view → full)
 * - Environment variable management
 * - Platform-aware filtering
 * - Callback-based LLM context generation
 */

// ── Environment Variable Definition ────────────────────────────

struct EnvironmentVariableDef {
    QString name;                        ///< e.g., "API_KEY"
    QString prompt;                      ///< Prompt to show user
    QString help;                        ///< Help text / link
    QString defaultValue;
    bool required{false};
    bool secret{false};                  ///< Should be masked (password-like)
    QString pattern;                     ///< Regex pattern for validation
};

// ── Platform Support ───────────────────────────────────────────

enum class Platform {
    Linux,
    macOS,
    Windows,
    Any
};

inline QString platformToString(Platform p) {
    switch(p) {
        case Platform::Linux: return "linux";
        case Platform::macOS: return "macos";
        case Platform::Windows: return "windows";
        case Platform::Any: return "any";
    }
    return "any";
}

inline Platform stringToPlatform(const QString &s) {
    QString lower = s.toLower();
    if (lower == "linux") return Platform::Linux;
    if (lower == "macos" || lower == "darwin") return Platform::macOS;
    if (lower == "windows") return Platform::Windows;
    return Platform::Any;
}

// ── Prerequisite Definition ────────────────────────────────────

struct Prerequisite {
    QString type;                        ///< "package", "command", "tool"
    QString name;
    QString version;                     ///< Min version
    QString installCommand;              ///< How to install
    QString checkCommand;                ///< How to verify installation
};

// ── Claude Skill Metadata ──────────────────────────────────────

struct ClaudeSkillMetadata {
    // ── Core Identity ──────────────────────────────────────
    QString skillId;                     ///< e.g., "spotify", "git-integration"
    QString name;
    QString description;                 ///< Brief description (≤1024 chars)
    QString version;                     ///< Semantic version
    
    // ── Categorization ─────────────────────────────────────
    QStringList platforms;               ///< [linux, macos, windows]
    QStringList tags;                    ///< [docker, ai, integration]
    QString category;                    ///< [analysis, coding, integration, etc.]
    
    // ── Implementation ─────────────────────────────────────
    QString author;
    QString maintainer;
    QStringList keywords;
    
    // ── Documentation ──────────────────────────────────────
    QString documentation;               ///< Full markdown content
    QString exampleUsage;
    QString changelog;
    QString licenseId;                   ///< SPDX identifier
    
    // ── Availability Control ───────────────────────────────
    bool enabled{true};
    bool deprecated{false};
    QString deprecationMessage;
    
    // ── Metadata Tier ──────────────────────────────────────
    // Tier 1: Lightweight listing
    struct Tier1 {
        QString skillId;
        QString name;
        QString description;
        QStringList tags;
        QString category;
    };
    
    // Tier 2: Full view (includes below)
    // Tier 3: With file references (links to external resources)
};

// ── Claude Skill Definition ────────────────────────────────────

struct ClaudeSkill {
    // ── Frontmatter Metadata ───────────────────────────────
    ClaudeSkillMetadata metadata;
    
    // ── Environment & Configuration ────────────────────────
    QVector<EnvironmentVariableDef> requiredEnvironmentVariables;
    QVector<Prerequisite> prerequisites;
    QMap<QString, QString> tags;         ///< Hermes metadata tags
    
    // ── Execution Context ──────────────────────────────────
    QStringList relatedSkills;           ///< IDs of related skills
    QStringList linkedTools;             ///< Tool IDs this skill uses
    QString filePath;                    ///< Path to SKILL.md file
    
    // ── Capabilities ───────────────────────────────────────
    SkillCapability capability;
    
    // ── Content Tiers (lazy-loaded) ────────────────────────
    QString markdownContent;             ///< Full markdown body
    QString htmlContent;                 ///< Rendered HTML (optional)
    
    // ── Metadata ───────────────────────────────────────────
    QDateTime discoveredAt;
    QDateTime modifiedAt;
    QString checksum;                    ///< For change detection
    bool isModified{false};              ///< If file changed on disk
};

// ── Skill Listing Item (Tier 1 - lightweight) ─────────────────

struct SkillListingItem {
    QString skillId;
    QString name;
    QString description;
    QStringList tags;
    QString category;
    bool available{true};
    QStringList incompatiblePlatforms;   ///< Platforms where unavailable
};

// ── Skill View Item (Tier 2 - full metadata) ──────────────────

struct SkillViewItem {
    SkillListingItem basicInfo;
    
    // Complete metadata
    QString version;
    QString author;
    QString maintainer;
    QString licenseId;
    bool deprecated{false};
    
    // Configuration requirements
    QVector<EnvironmentVariableDef> environmentVariables;
    QVector<Prerequisite> prerequisites;
    
    // Related information
    QStringList relatedSkills;
    
    // Content
    QString markdownContent;
};

// ── Skill Search Result ────────────────────────────────────────

struct SkillSearchResult {
    QVector<SkillListingItem> results;
    int totalCount{0};
    int matchedCount{0};
    QString query;
};

// ── Skill Discovery Context ────────────────────────────────────

struct SkillDiscoveryContext {
    QString baseDirectory;               ///< Root skills directory
    Platform currentPlatform;
    QString currentUser;
    QMap<QString, QString> environmentVariables;
    bool recursiveSearch{true};
    bool includeDisabled{false};
};

// ── Environment Variable Collector ────────────────────────────

struct EnvironmentVariableCollector {
    using PromptCallback = std::function<QString(
        const QString &name,
        const QString &prompt,
        const QString &help
    )>;
    
    using SecretCallback = std::function<QString(
        const QString &name,
        const QString &prompt
    )>;
    
    PromptCallback promptForValue;
    SecretCallback promptForSecret;
};

// ── Skill Availability Check ───────────────────────────────────

struct SkillAvailabilityCheck {
    QString skillId;
    bool platformSupported{true};
    bool prerequisitesMet{true};
    bool environmentReady{true};
    
    QStringList missingEnvironmentVariables;
    QStringList unsatisfiedPrerequisites;
    QString platformReason;              ///< Why unsupported on this platform
};

// ── Skill Mention for LLM (Claude-optimized) ──────────────────

struct ClaudeSkillMention {
    QString skillId;
    QString name;
    QString description;
    QString shortUsage;                  ///< How to invoke in markdown
    int relevanceScore{0};               ///< 0-100
    bool hasRequiredContext{true};
    QString contextMissingReason;
};

// ── Skill Context Generation ──────────────────────────────────

struct SkillContextForLLM {
    QVector<ClaudeSkillMention> availableSkills;
    QString contextMarkdown;             ///< Formatted for LLM consumption
    int totalTokens{0};
    
    // Tier 1: Just names/descriptions (~50 tokens)
    QString tier1Context;
    
    // Tier 2: Full instructions (~500 tokens)
    QString tier2Context;
    
    // Tier 3: With examples and edge cases (~1500 tokens)
    QString tier3Context;
};

// ── Skill Execution Request ────────────────────────────────────

struct SkillExecutionRequest {
    QString skillId;
    QString executionId;
    QMap<QString, QString> providedEnvironmentVariables;
    QVariantMap parameters;
    QVariantMap context;
    QString userRequestContext;          ///< Why user is calling this
    bool validatePrerequisites{true};
    int timeoutMs{30000};
};

// ── Skill Execution Result ─────────────────────────────────────

struct SkillExecutionResult {
    QString skillId;
    QString executionId;
    bool success{true};
    int exitCode{0};
    
    QString stdOut;
    QString stdErr;
    QVariant parsedOutput;
    
    int durationMs{0};
    int tokensUsed{0};
    
    QDateTime completedAt;
    QString errorMessage;
    QString warningMessage;
};

// ── Callbacks ──────────────────────────────────────────────────

using ClaudeSkillsListCallback = std::function<void(const QVector<SkillListingItem> &)>;
using ClaudeSkillViewCallback = std::function<void(const SkillViewItem &)>;
using ClaudeSkillSearchCallback = std::function<void(const SkillSearchResult &)>;
using ClaudeSkillAvailabilityCallback = std::function<void(const QVector<SkillAvailabilityCheck> &)>;
using ClaudeSkillExecutionCallback = std::function<void(const SkillExecutionResult &)>;
using ClaudeSkillContextCallback = std::function<void(const SkillContextForLLM &)>;
