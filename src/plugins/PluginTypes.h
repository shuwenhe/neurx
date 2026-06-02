#pragma once

#include <QString>
#include <QVariantMap>
#include <QStringList>
#include <QDateTime>
#include <QVersionNumber>

/**
 * @class PluginTypes
 * @brief Plugin system type definitions
 * 
 * Migrated from Codex plugin management system:
 * - Plugin metadata and lifecycle
 * - Plugin capabilities and permissions
 * - Marketplace integration
 * - Dependency management
 */

// ── Plugin Metadata ────────────────────────────────────────────

struct PluginMetadata {
    QString id;                          ///< Unique plugin ID (e.g., "org.neurx.plugin.git")
    QString name;                        ///< Human-readable name
    QString version;                     ///< Plugin version (semantic versioning)
    QString description;
    QString author;
    QString license{"MIT"};
    
    // Plugin details
    QString mainFile;                    ///< Main plugin file (e.g., "plugin.so", "plugin.js")
    QString entryPoint{"init"};          ///< Entry function name
    QString category;                    ///< Category: "tool", "model", "skill", "transport"
    
    // Links
    QString homepage;
    QString repository;
    QString documentation;
    QString issueTracker;
    
    // Marketplace
    QString marketplaceId;               ///< ID from marketplace
    QDateTime publishedAt;
    QDateTime lastUpdatedAt;
    int downloadCount{0};
    double rating{0.0};
};

// ── Plugin Capabilities ────────────────────────────────────────

struct PluginCapabilities {
    QStringList tools;                   ///< Exposed tool names
    QStringList models;                  ///< Supported LLM models
    QStringList skills;                  ///< Provided skills
    QStringList transports;              ///< Communication transports
    QStringList permissions;             ///< Required permissions
    
    // Hooks
    bool hasInitHook{false};
    bool hasShutdownHook{false};
    bool hasConfigValidationHook{false};
    bool hasEventHook{false};
};

// ── Plugin Dependency ──────────────────────────────────────────

struct PluginDependency {
    QString pluginId;                    ///< Dependency plugin ID
    QString versionRange;                ///< Semantic version range (e.g., "^1.0.0")
    bool optional{false};
    QString description;
};

// ── Plugin Status ──────────────────────────────────────────────

enum class PluginStatus {
    Available,       ///< Available but not loaded
    Loading,         ///< Currently loading
    Loaded,          ///< Successfully loaded
    Active,          ///< Active and running
    Disabled,        ///< Explicitly disabled
    Failed,          ///< Failed to load
    Unloading,       ///< Currently unloading
    Deprecated       ///< Marked as deprecated
};

// ── Plugin Error Types ─────────────────────────────────────────

enum class PluginError {
    Success = 0,
    NotFound,
    AlreadyLoaded,
    FailedToLoad,
    InvalidManifest,
    DependencyNotMet,
    VersionConflict,
    PermissionDenied,
    CorruptedPlugin,
    NetworkError,
    SecurityViolation
};

// ── Plugin Manifest ────────────────────────────────────────────

struct PluginManifest {
    PluginMetadata metadata;
    PluginCapabilities capabilities;
    QVector<PluginDependency> dependencies;
    
    // Configuration
    QVariantMap defaultConfig;
    QStringList requiredPermissions;
    
    // Constraints
    QStringList supportedPlatforms;      ///< e.g., ["linux", "macos", "windows"]
    QString minNeurxVersion{"1.0.0"};
    
    // Compatibility
    bool requiresRestart{false};
    bool sandboxed{true};                ///< Run in sandbox
    bool trusted{false};                 ///< From trusted source
};

// ── Plugin Instance ────────────────────────────────────────────

struct PluginInstance {
    QString id;
    PluginMetadata metadata;
    PluginStatus status{PluginStatus::Available};
    QString statusMessage;
    
    QString loadPath;                    ///< Actual file path
    void *handle{nullptr};               ///< Dynamic library handle
    
    // Runtime state
    QVariantMap runtimeConfig;           ///< Merged config at runtime
    QDateTime loadedAt;
    QDateTime lastActivityAt;
    int activations{0};
    
    // Health
    bool isHealthy{true};
    QString lastError;
};

// ── Plugin Registry Entry ──────────────────────────────────────

struct PluginRegistryEntry {
    PluginMetadata metadata;
    PluginStatus status{PluginStatus::Available};
    QString installPath;
    QString version;
    bool autoLoad{false};
    bool enabled{true};
    QDateTime installedAt;
};

// ── Marketplace Plugin ─────────────────────────────────────────

struct MarketplacePlugin {
    QString id;
    QString name;
    QString version;
    QString description;
    QString author;
    QString license;
    QString category;
    QString homepage;
    QString repositoryUrl;
    
    // Statistics
    int downloadCount{0};
    double rating{0.0};
    int reviews{0};
    
    // Content
    QDateTime publishedAt;
    QDateTime lastUpdatedAt;
    QString changeLog;
    QStringList screenshots;
    QStringList requirements;
    
    // Installation
    QString downloadUrl;
    QString checksumSha256;
    qint64 fileSizeBytes{0};
    
    bool isFeatured{false};
    bool isVerified{false};
};

// ── Plugin Event ────────────────────────────────────────────────

enum class PluginEventType {
    Loaded,
    Unloaded,
    Activated,
    Deactivated,
    Updated,
    ConfigChanged,
    Error,
    HealthCheck,
    DependencyMissing
};

struct PluginEvent {
    QString pluginId;
    PluginEventType type;
    QDateTime timestamp{QDateTime::currentDateTime()};
    QVariantMap data;
    QString message;
};

// ── Plugin Callbacks ───────────────────────────────────────────

using PluginCallback = std::function<void(PluginError, const PluginInstance &)>;
using PluginListCallback = std::function<void(PluginError, const QVector<PluginInstance> &)>;
using MarketplaceCallback = std::function<void(PluginError, const QVector<MarketplacePlugin> &)>;
