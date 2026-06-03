#pragma once

#include <QString>
#include <QVariantMap>
#include <QVector>
#include <QMap>
#include <memory>
#include <functional>

/**
 * @class AnthropicSkillsTypes
 * @brief Anthropic-specific skills features and types
 * 
 * Extends Claude Skills with Anthropic's advanced features:
 * - Prompt Caching for cost optimization
 * - Adaptive Thinking for flexible reasoning
 * - Effort Control for token budgeting
 * - Context Compaction for long conversations
 * - Tool Runner for autonomous execution
 * - Managed Agents for server-hosted state
 */

// ── Prompt Caching ────────────────────────────────────────

enum class CacheControlType {
    EphemeralCache,      ///< Temporary cache (5 min TTL)
    StandardCache        ///< Standard cache (default behavior)
};

struct CacheControl {
    CacheControlType type{CacheControlType::StandardCache};
    int ttlSeconds{300};  ///< Time to live for ephemeral
};

struct CachedContent {
    QString type;           ///< "text", "document", "image"
    QString content;
    CacheControl caching;
    bool inputTokensUsed{false};
    bool cacheCreationTokens{0};
    bool cacheReadTokens{0};
};

// ── Adaptive Thinking ──────────────────────────────────────

enum class ThinkingDepth {
    Auto,        ///< Automatic based on complexity
    Shallow,     ///< ~5K tokens
    Standard,    ///< ~15K tokens
    Deep         ///< ~30K tokens
};

struct AdaptiveThinkingConfig {
    bool enabled{false};
    ThinkingDepth budgetTokens{ThinkingDepth::Standard};
    int maxThinkingTokens{30000};
    bool exposeThinking{true};  ///< Include thinking in response
};

// ── Effort Control ────────────────────────────────────────

enum class EffortLevel {
    Low,        ///< Minimal computation (~1K tokens)
    Medium,     ///< Balanced (~5K tokens)
    High,       ///< Comprehensive (~15K tokens)
    Max,        ///< Maximum effort (~30K tokens)
    XHigh       ///< Extended effort (~50K tokens)
};

struct EffortControlConfig {
    EffortLevel level{EffortLevel::Medium};
    bool respectBudgets{true};
    int maxTokensPerRequest{100000};
};

// ── Context Compaction ──────────────────────────────────────

enum class CompactionStrategy {
    None,              ///< No compaction
    Automatic,         ///< Let Claude decide
    MaxCompression,    ///< Maximize compression
    MinQualityLoss     ///< Minimize quality loss
};

struct CompactionConfig {
    CompactionStrategy strategy{CompactionStrategy::None};
    int messageWindow{20};          ///< Messages to keep uncompressed
    bool compactKVCache{true};
    QString betaHeader{"compact-2026-01-12"};
};

struct CompactedContext {
    QString compactedContent;
    int originalTokens{0};
    int compactedTokens{0};
    float compressionRatio{0.0};
};

// ── Tool Runner (Agentic Loop) ─────────────────────────────

enum class ToolUseMode {
    NoTools,           ///< No tool use
    SingleRequest,     ///< Max 1 tool call per request
    Iterative,         ///< Multiple iterations with tools
    Autonomous         ///< Full autonomous tool loop
};

struct ToolDefinition {
    QString name;
    QString description;
    QVariantMap inputSchema;  ///< JSON Schema
    QString category;         ///< "retrieve", "compute", "transform", etc.
    int maxCallsPerRequest{10};
};

struct ToolResult {
    QString toolName;
    QString toolUseId;
    bool success{true};
    QVariant result;
    QString errorMessage;
    int tokensUsed{0};
};

struct ToolRunnerConfig {
    ToolUseMode mode{ToolUseMode::NoTools};
    int maxIterations{10};
    int maxRetries{3};
    bool parallelToolCalls{true};
    QVector<ToolDefinition> tools;
};

// ── File API (Cross-Request File Management) ───────────────

enum class FileType {
    Document,    ///< .docx, .pdf, .xlsx, .pptx
    Image,       ///< .jpg, .png, .gif, .webp
    Video,       ///< .mp4, .webm, .mov
    Audio,       ///< .mp3, .wav, .m4a
    Code,        ///< .py, .js, .cpp, etc.
    Data         ///< .json, .csv, .xml, etc.
};

struct FileMetadata {
    QString fileId;
    QString fileName;
    FileType type;
    int fileSizeBytes{0};
    QDateTime uploadedAt;
    QString mimeType;
    QStringList tags;
};

struct FileReference {
    QString fileId;
    QString fileName;
    bool useCache{true};
    QString cacheControl;
};

// ── Task Budgets (Token Spending Control) ──────────────────

struct TaskBudget {
    int totalTokenBudget{100000};
    int tokensSpentSoFar{0};
    int maxTokensPerRequest{50000};
    int warningThreshold{80000};  ///< Alert at 80% usage
    bool strictEnforcement{false};
};

struct BudgetStatus {
    int totalBudget{0};
    int used{0};
    int remaining{0};
    float usagePercent{0.0};
    bool budgetExceeded{false};
};

// ── Managed Agents ────────────────────────────────────────

enum class AgentResourceType {
    CodeExecutor,      ///< Python, Node.js execution
    FileStorage,       ///< File system access
    WebBrowser,        ///< Web browsing capability
    DatabaseAccess,    ///< Database queries
    APIEndpoint        ///< Custom API integration
};

struct ManagedAgentResource {
    AgentResourceType type;
    QString resourceId;
    QString resourceName;
    QVariantMap configuration;
    bool active{true};
};

struct ManagedAgentConfig {
    QString agentId;
    QString agentName;
    QString instructions;
    QVector<ManagedAgentResource> resources;
    QString modelId;
    QVariantMap systemPrompt;
    bool persistent{true};  ///< Keep state between requests
};

// ── Batch Processing (Async Processing) ────────────────────

struct BatchRequest {
    QString requestId;
    QString customId;  ///< Client-provided ID for tracking
    QString model;
    QVariantMap params;
    QDateTime createdAt;
};

struct BatchJob {
    QString batchId;
    QString status;     ///< "processing", "completed", "failed"
    QVector<BatchRequest> requests;
    int processedRequests{0};
    int failedRequests{0};
    QDateTime createdAt;
    QDateTime completedAt;
    QString resultUrl;  ///< S3 URL to results
};

// ── Skill Execution Request ────────────────────────────────

struct AnthropicSkillRequest {
    QString skillId;
    
    // Caching strategy
    bool usePromptCaching{false};
    CacheControl cacheConfig;
    
    // Thinking capabilities
    AdaptiveThinkingConfig thinking;
    
    // Effort control
    EffortControlConfig effort;
    
    // Context management
    CompactionConfig compaction;
    
    // Tool usage
    ToolRunnerConfig tools;
    
    // File management
    QVector<FileReference> fileReferences;
    
    // Budget control
    TaskBudget budget;
    
    // Execution parameters
    QVariantMap skillParameters;
    QString userInput;
    int timeoutMs{30000};
};

// ── Callbacks ──────────────────────────────────────────────

using ToolResultCallback = std::function<void(const ToolResult &result)>;
using CompactionCallback = std::function<void(const CompactedContext &)>;
using BudgetAlertCallback = std::function<void(const BudgetStatus &)>;
using ManagedAgentCallback = std::function<void(bool success, const QString &response)>;
using BatchJobCallback = std::function<void(const BatchJob &job)>;
