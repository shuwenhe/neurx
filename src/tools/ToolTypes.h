#pragma once

#include <QString>
#include <QVector>
#include <QMap>
#include <QVariantMap>
#include <QDateTime>
#include <functional>

/**
 * Tool registry types for tool orchestration and management
 */

// ── Tool Categories ────────────────────────────────────

enum class ToolCategory {
    FileSystem,     // File operations
    DataProcessing, // Data transformation
    Computation,    // Calculations
    Communication,  // API calls, messaging
    Database,       // Database operations
    DevOps,         // Deployment, infrastructure
    CodeAnalysis,   // Code inspection
    Integration,    // Third-party integrations
    Custom          // Custom user tools
};

// ── Tool Parameter Types ───────────────────────────────

enum class ParameterType {
    String,
    Integer,
    Float,
    Boolean,
    Date,
    Time,
    DateTime,
    Array,
    Object,
    File,
    Path,
    URL,
    Email,
    Phone,
    Custom
};

/// Tool parameter definition
struct ToolParameter {
    QString name;
    ParameterType type;
    QString description;
    QVariant defaultValue;
    bool required = true;
    QVector<QVariant> enumValues;  // Valid values if enum
    QVariant minValue;             // Min value for numeric
    QVariant maxValue;             // Max value for numeric
    QString pattern;               // Regex pattern for validation
    QStringList examples;          // Example values
};

/// Tool return value definition
struct ToolReturn {
    ParameterType type;
    QString description;
    QVariant example;
};

// ── Tool Metadata ──────────────────────────────────────

struct ToolMetadata {
    QString toolId;                // Unique identifier
    QString name;                  // Display name
    QString version;               // Semantic version
    QString description;           // What it does
    QString category;              // Tool category
    
    QString author;                // Creator
    QString license;               // License type
    QString repository;            // Source code
    QString documentation;         // Help/docs URL
    
    QStringList tags;              // Search tags
    QStringList keywords;          // Search keywords
    
    QDateTime createdAt;           // Creation time
    QDateTime updatedAt;           // Last update
    int downloadCount = 0;         // Download stats
    float rating = 0.0f;           // User rating
};

/// Tool capability definition
struct ToolCapability {
    QString name;                  // Capability name
    QString description;           // What it does
    
    QVector<ToolParameter> parameters;  // Input parameters
    ToolReturn returnType;         // Return type
    
    float executionTime = 0.0f;    // Expected execution time (ms)
    bool async = false;            // Async execution
    bool requiresApproval = false; // Needs user approval
    
    QStringList requiredPermissions;    // Required permissions
    QStringList environmentRequirements; // OS/dependencies
};

// ── Tool Instance ──────────────────────────────────────

enum class ToolStatus {
    Available,    // Ready to use
    Loading,      // Being loaded
    Loaded,       // Loaded
    Active,       // Active
    Disabled,     // Disabled
    Failed,       // Failed to load
    Deprecated    // Deprecated version
};

enum class ToolError {
    Success = 0,
    NotFound,
    InvalidParameters,
    ExecutionFailed,
    PermissionDenied,
    Timeout,
    EnvironmentNotAvailable,
    DependencyMissing,
    VersionMismatch,
    InvalidConfiguration,
    ResourceExhausted
};

struct ToolInstance {
    QString toolId;
    QString instanceId;            // Unique instance ID
    ToolStatus status;
    
    ToolMetadata metadata;
    QVector<ToolCapability> capabilities;
    
    QString configPath;            // Configuration file
    QVariantMap config;            // Configuration data
    
    int maxConcurrentExecutions = 1;
    int currentExecutions = 0;
    
    QDateTime loadedAt;
    QDateTime lastUsedAt;
    int executionCount = 0;
    float averageExecutionTime = 0.0f;
    
    QString errorMessage;          // Last error
};

/// Tool execution result
struct ToolExecutionResult {
    QString toolId;
    QString executionId;
    
    bool success;
    ToolError errorCode;
    QString errorMessage;
    
    QVariant result;               // Execution result
    QVariantMap metadata;          // Execution metadata
    
    qint64 executionTime;          // Time taken (ms)
    int tokensUsed = 0;            // LLM tokens
    
    QDateTime startedAt;
    QDateTime completedAt;
    
    QString stdout;                // Standard output
    QString stderr;                // Standard error
};

// ── Tool Registry ──────────────────────────────────────

struct ToolRegistry {
    QString registryId;
    QString name;
    
    int totalTools = 0;
    int availableTools = 0;
    int activeTools = 0;
    
    QDateTime createdAt;
    QDateTime lastUpdatedAt;
};

// ── Tool Filter & Search ───────────────────────────────

struct ToolQuery {
    QString searchText;            // Free text search
    QStringList categories;        // Filter by category
    QStringList tags;              // Filter by tags
    bool onlyAvailable = true;     // Only available tools
    bool onlyLoaded = false;       // Only loaded tools
    int limit = 50;
    int offset = 0;
};

struct ToolSearchResult {
    ToolInstance tool;
    float relevanceScore;          // Search relevance
};

// ── Tool Chain Execution ───────────────────────────────

enum class ChainStrategy {
    Sequential,  // Run one after another
    Parallel,    // Run simultaneously
    Conditional, // Run based on conditions
    Looped       // Run in a loop
};

struct ToolChainStep {
    QString stepId;
    QString toolId;
    int stepNumber;
    
    QVariantMap parameters;        // Tool parameters
    QString condition;             // Condition to execute
    bool continueOnError = false;  // Skip on error
    
    int timeout = 30000;           // Timeout (ms)
    int maxRetries = 0;            // Retry count
};

struct ToolChain {
    QString chainId;
    QString name;
    QString description;
    
    ChainStrategy strategy;
    QVector<ToolChainStep> steps;
    
    QVariantMap globalParameters;  // Shared parameters
    
    bool requiresApproval = false;
    
    QDateTime createdAt;
};

// ── Tool Permissions ───────────────────────────────────

enum class Permission {
    Read,          // Read access
    Write,         // Write access
    Execute,       // Execute capability
    Delete,        // Delete capability
    Admin          // Administrative access
};

struct ToolPermission {
    QString toolId;
    QString principalId;           // User/role ID
    QVector<Permission> permissions;
    
    QDateTime grantedAt;
    QDateTime expiresAt;           // Optional expiration
};

// ── Tool Marketplace ───────────────────────────────────

struct MarketplaceTool {
    QString toolId;
    ToolMetadata metadata;
    
    QString repositoryUrl;
    QString installCommand;
    
    float rating = 0.0f;
    int downloads = 0;
    int favoriteCount = 0;
    
    QStringList versions;          // Available versions
    QString latestVersion;
    
    bool verified = false;         // Verified by maintainers
};

// ── Tool Hooks ─────────────────────────────────────────

enum class ToolHookType {
    BeforeExecution,
    AfterExecution,
    OnError,
    OnSuccess,
    OnTimeout
};

struct ToolHook {
    QString hookId;
    QString toolId;
    ToolHookType type;
    
    QString scriptPath;            // Hook script
    QString scriptLanguage;        // python, javascript, etc
    
    QStringList triggerConditions;
};

// ── Statistics & Monitoring ────────────────────────────

struct ToolStatistics {
    QString toolId;
    
    int totalExecutions = 0;
    int successfulExecutions = 0;
    int failedExecutions = 0;
    
    float successRate = 0.0f;
    float averageExecutionTime = 0.0f;
    float maxExecutionTime = 0.0f;
    float minExecutionTime = 0.0f;
    
    int averageTokensUsed = 0;
    
    QDateTime collectedAt;
};

// ── Callbacks ──────────────────────────────────────────

using ToolCallback = std::function<void(const ToolExecutionResult &)>;
using ToolListCallback = std::function<void(const QVector<ToolInstance> &)>;
using ToolSearchCallback = std::function<void(const QVector<ToolSearchResult> &)>;
using ToolErrorCallback = std::function<void(const QString &error)>;

#endif // TOOLTYPES_H
