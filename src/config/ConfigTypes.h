#pragma once

#include <QString>
#include <QVariantMap>
#include <QStringList>
#include <QMap>
#include <QDateTime>

/**
 * @class ConfigTypes
 * @brief Configuration type definitions for neurx
 * 
 * Migrated from Codex config system:
 * - Profiles (default, development, production)
 * - Settings with overrides
 * - Agent configuration
 * - Tool permissions and policies
 */

// ── Configuration Profiles ─────────────────────────────────────

enum class ConfigProfile {
    Default,        ///< Default development profile
    Development,    ///< Development environment
    Production,     ///< Production environment
    Testing,        ///< Testing environment
    Custom          ///< User-defined profile
};

// ── Agent Configuration ────────────────────────────────────────

struct AgentConfig {
    QString name{"neurx-agent"};
    QString model{"claude-3.5-sonnet"};
    QString reasoning{"disabled"};
    
    // Execution settings
    int maxRetries{3};
    int executionTimeoutMs{300000}; // 5 minutes
    int maxOutputSize{1000000};     // 1 MB
    
    // Behavior
    bool verboseLogging{false};
    bool strictMode{false};
    bool autoApprove{false};
    
    // Tool settings
    bool enableShellExecution{true};
    bool enableFileOperations{true};
    bool enableNetworkAccess{false};
};

// ── Tool Configuration ─────────────────────────────────────────

struct ToolConfig {
    QString name;
    bool enabled{true};
    QVariantMap settings;
    QStringList permissions;
    int timeoutMs{30000};
    
    // Sandboxing
    struct SandboxPolicy {
        QString mode{"read-only"};
        QStringList allowedPaths;
        QStringList blockedPaths;
    } sandbox;
};

// ── LLM Provider Configuration ──────────────────────────────────

struct LLMConfig {
    QString provider{"anthropic"};
    QString apiKey;
    QString model{"claude-3.5-sonnet"};
    
    // API settings
    int maxTokens{8000};
    double temperature{0.7};
    double topP{1.0};
    
    // Retry policy
    int maxRetries{3};
    int retryDelayMs{1000};
    
    // Endpoint
    QString endpoint;
    int timeoutMs{60000};
};

// ── Storage Configuration ──────────────────────────────────────

struct StorageConfig {
    QString backend{"file-based"};  // file-based, sqlite, postgres
    QString dataDir{"~/.neurx/data"};
    
    // File-based settings
    struct {
        QString threadsDir{"threads"};
        QString checkpointsDir{"checkpoints"};
        QString logsDir{"logs"};
    } filePaths;
    
    // Database settings
    struct {
        QString host{"localhost"};
        int port{5432};
        QString database{"neurx"};
        QString username;
        QString password;
    } database;
};

// ── Approval Policy Configuration ──────────────────────────────

struct ApprovalConfig {
    QString mode{"on-request"};  // never, on-request, granular, always
    QString reviewer{"user"};    // user, auto-review, guardian
    
    // Granular rules
    QMap<QString, QString> toolPolicies;  // tool name -> policy
    QStringList trustedPaths;
    QStringList blockedPaths;
    
    // Auto-approval settings
    bool autoApproveOnRetry{false};
    bool autoApproveReadOnly{true};
};

// ── Logging Configuration ──────────────────────────────────────

struct LoggingConfig {
    QString level{"info"};  // debug, info, warn, error
    QString format{"text"}; // text, json
    QString output{"console"}; // console, file, both
    
    // File settings
    QString logFile{"neurx.log"};
    int maxFileSizeMB{100};
    int maxBackups{10};
    bool colorOutput{true};
    
    // Telemetry
    bool enableTelemetry{false};
    QString telemetryEndpoint;
};

// ── Complete Configuration ─────────────────────────────────────

struct NeurxConfig {
    ConfigProfile profile{ConfigProfile::Default};
    QString version{"1.0"};
    
    // Major subsystems
    AgentConfig agent;
    LLMConfig llm;
    StorageConfig storage;
    ApprovalConfig approval;
    LoggingConfig logging;
    
    // Tools configuration
    QMap<QString, ToolConfig> tools;
    
    // Custom settings (for extensions)
    QVariantMap custom;
    
    // Metadata
    QDateTime loadedAt;
    QString configFile;
    QStringList appliedProfiles;
};

// ── Configuration Errors ───────────────────────────────────────

enum class ConfigError {
    Success = 0,
    FileNotFound,
    InvalidFormat,
    ValidationFailed,
    PermissionDenied,
    ParseError,
    TypeMismatch,
    MissingRequired,
    EnvironmentError
};

// ── Configuration Loader Callback ──────────────────────────────

using ConfigCallback = std::function<void(ConfigError, const NeurxConfig &)>;
