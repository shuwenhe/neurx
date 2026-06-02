#pragma once

#include <QString>
#include <QVariantMap>
#include <QStringList>
#include <QDateTime>

/**
 * @class SkillTypes
 * @brief Skill system type definitions
 * 
 * Migrated from Codex skills system:
 * - Skill declarations and metadata
 * - Capability definitions
 * - Context and parameter handling
 * - Availability and filtering
 */

// ── Skill Parameter ────────────────────────────────────────────

struct SkillParameter {
    QString name;
    QString description;
    QString type;           ///< "string", "number", "boolean", "object", "array"
    bool required{true};
    QVariant defaultValue;
    QStringList enumValues; ///< Valid values if enum type
    QString pattern;        ///< Regex pattern for validation
};

// ── Skill Metadata ────────────────────────────────────────────

struct SkillMetadata {
    QString id;                          ///< Unique skill ID
    QString name;                        ///< Display name
    QString description;                 ///< What the skill does
    QString version{"1.0.0"};
    QString category;                    ///< e.g., "analysis", "writing", "coding"
    
    QString author;
    QString icon;                        ///< Icon URL
    QString color;                       ///< UI color
    
    // Documentation
    QString documentation;
    QString exampleUsage;
    QStringList tags;
};

// ── Skill Input/Output ─────────────────────────────────────────

struct SkillInput {
    QString description;
    QVector<SkillParameter> parameters;
    QString format;                      ///< JSON schema or description
};

struct SkillOutput {
    QString description;
    QString type;                        ///< Expected output type
    QString format;                      ///< JSON schema
};

// ── Skill Capability ──────────────────────────────────────────

struct SkillCapability {
    QString skillId;
    QString name;
    QString description;
    SkillInput input;
    SkillOutput output;
    
    // Constraints
    int costTokens{0};                   ///< Estimated token cost
    int maxDurationMs{30000};
    int maxAttemptsPerSession{10};
    
    // Permissions required
    QStringList requiredPermissions;
    
    // Context requirements
    QStringList requiredContext;         ///< e.g., ["workspace", "file-tree"]
};

// ── Skill Filter ──────────────────────────────────────────────

struct SkillFilter {
    QString query;                       ///< Search query
    QStringList categories;              ///< Filter by categories
    QStringList tags;                    ///< Filter by tags
    bool availableOnly{true};
    bool matchFunction{true};            ///< Include function skills
    bool matchContextual{true};          ///< Include contextual skills
    int maxResults{10};
};

// ── Skill Availability ────────────────────────────────────────

struct SkillAvailability {
    QString skillId;
    bool available{true};
    QString unavailableReason;           ///< Why it's unavailable
    
    // Context availability
    bool availableInContext{true};
    QStringList missingContext;
    
    // Permission availability
    bool hasPermissions{true};
    QStringList missingPermissions;
};

// ── Skill Invocation ────────────────────────────────────────────

struct SkillInvocation {
    QString skillId;
    QString invocationId;               ///< Unique invocation ID
    QVariantMap parameters;
    QString context;                    ///< Current context
    QDateTime invokedAt{QDateTime::currentDateTime()};
};

// ── Skill Result ────────────────────────────────────────────────

struct SkillResult {
    QString skillId;
    QString invocationId;
    bool success{true};
    QVariant output;
    QString errorMessage;
    int tokensUsed{0};
    int durationMs{0};
    QDateTime completedAt{QDateTime::currentDateTime()};
};

// ── Skill Mention (in LLM context) ─────────────────────────────

struct SkillMention {
    QString skillId;
    QString skillName;
    QString description;
    QString usage;                      ///< How to use it
    bool mentioned{false};
    int relevanceScore{0};              ///< 0-100
};

// ── Skill Policy ────────────────────────────────────────────────

enum class SkillPolicy {
    Auto,                               ///< Automatically suggest
    OnDemand,                           ///< Only on explicit request
    Hidden,                             ///< Don't show to user
    Disabled                            ///< Cannot be used
};

// ── Skill Notification ─────────────────────────────────────────

struct SkillNotification {
    QString skillId;
    QString message;
    QString type;                       ///< "info", "warning", "error"
    QDateTime timestamp{QDateTime::currentDateTime()};
};

// ── Skill Callbacks ────────────────────────────────────────────

using SkillCallback = std::function<void(const SkillResult &result)>;
using SkillsListCallback = std::function<void(const QVector<SkillCapability> &skills)>;
using SkillAvailabilityCallback = std::function<void(const QVector<SkillAvailability> &available)>;
