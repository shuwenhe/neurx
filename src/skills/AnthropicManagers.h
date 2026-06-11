#pragma once

#include "AnthropicSkillsTypes.h"
#include <QString>
#include <QMap>
#include <QVector>
#include <memory>

/**
 * @class PromptCachingManager
 * @brief Manages prompt caching for cost optimization
 * 
 * Features:
 * - Identify cacheable content patterns
 * - Calculate cache cost savings
 * - Manage cache lifecycle
 * - Track cache hit rates
 */
class PromptCachingManager {
public:
    PromptCachingManager() = default;
    virtual ~PromptCachingManager() = default;
    
    /// Analyze content for caching suitability
    virtual bool analyzeContentForCaching(const QString &content,
                                         int &estimatedTokens,
                                         float &estimatedSavings) = 0;
    
    /// Get optimal caching strategy for content type
    virtual CacheControl getOptimalCacheStrategy(const QString &contentType) = 0;
    
    /// Calculate cost savings from caching
    virtual void calculateCacheSavings(int cachedTokens,
                                      int reusageCount,
                                      float &tokenSavings,
                                      float &costSavings) = 0;
    
    /// Track cache hit rate
    virtual void recordCacheHit(const QString &contentHash, bool hit) = 0;
    
    /// Get cache statistics
    virtual QVariantMap getCacheStats() const = 0;
};

/**
 * @class AdaptiveThinkingManager
 * @brief Manages adaptive thinking for flexible reasoning
 * 
 * Features:
 * - Assess task complexity
 * - Auto-allocate thinking budget
 * - Manage thinking exposure settings
 * - Monitor thinking token usage
 */
class AdaptiveThinkingManager {
public:
    AdaptiveThinkingManager() = default;
    virtual ~AdaptiveThinkingManager() = default;
    
    /// Auto-determine optimal thinking depth for task
    virtual ThinkingDepth assessTaskComplexity(const QString &task,
                                               const QString &context = "") = 0;
    
    /// Get recommended thinking config for task
    virtual AdaptiveThinkingConfig getRecommendedConfig(const QString &taskType) = 0;
    
    /// Estimate thinking token usage
    virtual int estimateThinkingTokens(ThinkingDepth depth) = 0;
    
    /// Track thinking token usage
    virtual void recordThinkingUsage(ThinkingDepth depth, int tokensUsed) = 0;
    
    /// Get thinking effectiveness metrics
    virtual QVariantMap getEffectivenessMetrics() const = 0;
};

/**
 * @class EffortControlManager
 * @brief Manages effort levels for token budgeting
 * 
 * Features:
 * - Recommend effort level based on task
 * - Track token budgets
 * - Enforce spending limits
 * - Provide budget alerts
 */
class EffortControlManager {
public:
    EffortControlManager() = default;
    virtual ~EffortControlManager() = default;
    
    /// Recommend effort level for task
    virtual EffortLevel getRecommendedEffort(const QString &task,
                                            int availableTokens) = 0;
    
    /// Get token estimate for effort level
    virtual int estimateTokensForEffort(EffortLevel level) = 0;
    
    /// Enforce budget limits
    virtual bool enforceTokenBudget(const TaskBudget &budget,
                                   int requestedTokens,
                                   QString &reason) = 0;
    
    /// Get current budget status
    virtual BudgetStatus getBudgetStatus(const TaskBudget &budget) = 0;
    
    /// Alert on budget threshold
    virtual void checkBudgetThreshold(const TaskBudget &budget,
                                     BudgetAlertCallback callback) = 0;
};

/**
 * @class ContextCompactionManager
 * @brief Manages context compression for long conversations
 * 
 * Features:
 * - Compress message history
 * - Preserve important context
 * - Calculate compression ratios
 * - Manage compaction strategies
 */
class ContextCompactionManager {
public:
    ContextCompactionManager() = default;
    virtual ~ContextCompactionManager() = default;
    
    /// Compact conversation history
    virtual CompactedContext compactContext(
        const QVector<QString> &messages,
        const CompactionConfig &config
    ) = 0;
    
    /// Decide if compaction is needed
    virtual bool shouldCompact(int messageCount, int totalTokens) = 0;
    
    /// Get recommended compaction strategy
    virtual CompactionStrategy getRecommendedStrategy(const QString &conversationType) = 0;
    
    /// Estimate compression ratio
    virtual float estimateCompressionRatio(const CompactionStrategy &strategy) = 0;
    
    /// Track compaction metrics
    virtual QVariantMap getCompressionMetrics() const = 0;
};

/**
 * @class ToolRunnerFramework
 * @brief Autonomous tool execution framework (agentic loop)
 * 
 * Features:
 * - Orchestrate tool calls
 * - Handle tool results
 * - Manage iteration loops
 * - Track tool performance
 */
class ToolRunnerFramework {
public:
    using ToolExecutor = std::function<ToolResult(const QString &toolName, const QVariantMap &params)>;
    
    ToolRunnerFramework() = default;
    virtual ~ToolRunnerFramework() = default;
    
    /// Register available tools
    virtual void registerTool(const ToolDefinition &tool) = 0;
    
    /// Execute tool with automatic retries
    virtual ToolResult executeTool(const QString &toolName,
                                  const QVariantMap &parameters,
                                  ToolExecutor executor) = 0;
    
    /// Run autonomous tool loop
    virtual void runToolLoop(const ToolRunnerConfig &config,
                            const QString &initialQuery,
                            ToolExecutor executor,
                            std::function<void(const QVector<ToolResult> &)> callback) = 0;
    
    /// Validate tool parameters against schema
    virtual bool validateToolParams(const QString &toolName,
                                   const QVariantMap &params,
                                   QString &error) = 0;
    
    /// Get tool performance metrics
    virtual QVariantMap getToolMetrics() const = 0;
};

/**
 * @class FileAPIManager
 * @brief Manages file uploads and cross-request file references
 * 
 * Features:
 * - Upload and manage files
 * - Track file references
 * - Apply cache control to files
 * - Handle file cleanup
 */
class FileAPIManager {
public:
    FileAPIManager() = default;
    virtual ~FileAPIManager() = default;
    
    /// Upload file to API
    virtual QString uploadFile(const QString &filePath,
                              FileType type,
                              const QString &description = "") = 0;
    
    /// Get file metadata
    virtual FileMetadata getFileMetadata(const QString &fileId) = 0;
    
    /// Create file reference with cache control
    virtual FileReference createFileReference(const QString &fileId,
                                             bool useCache = true) = 0;
    
    /// Delete file
    virtual bool deleteFile(const QString &fileId) = 0;
    
    /// List uploaded files
    virtual QVector<FileMetadata> listFiles() = 0;
    
    /// Get file storage statistics
    virtual QVariantMap getStorageStats() const = 0;
};

/**
 * @class BatchProcessingManager
 * @brief Manages batch processing for cost-effective async operations
 * 
 * Features:
 * - Create and submit batch jobs
 * - Track job status
 * - Handle batch results
 * - Calculate cost savings (50% discount)
 */
class BatchProcessingManager {
public:
    BatchProcessingManager() = default;
    virtual ~BatchProcessingManager() = default;
    
    /// Create a batch job
    virtual BatchJob createBatchJob(const QVector<AnthropicSkillRequest> &requests) = 0;
    
    /// Submit batch for processing
    virtual QString submitBatch(const BatchJob &job) = 0;
    
    /// Get batch status
    virtual QString getBatchStatus(const QString &batchId) = 0;
    
    /// Retrieve batch results
    virtual void retrieveBatchResults(const QString &batchId,
                                     BatchJobCallback callback) = 0;
    
    /// Calculate batch cost savings
    virtual float calculateCostSavings(int totalTokens) = 0;
    
    /// Get batch processing metrics
    virtual QVariantMap getBatchMetrics() const = 0;
};

/**
 * @class ManagedAgentOrchestrator
 * @brief Orchestrates server-hosted managed agents
 * 
 * Features:
 * - Create and manage agent instances
 * - Handle agent communication
 * - Manage agent resources
 * - Track agent state
 */
class ManagedAgentOrchestrator {
public:
    ManagedAgentOrchestrator() = default;
    virtual ~ManagedAgentOrchestrator() = default;
    
    /// Create a managed agent
    virtual QString createAgent(const ManagedAgentConfig &config) = 0;
    
    /// Send message to agent
    virtual void sendMessage(const QString &agentId,
                            const QString &message,
                            ManagedAgentCallback callback) = 0;
    
    /// Get agent state
    virtual QVariantMap getAgentState(const QString &agentId) = 0;
    
    /// Add resource to agent
    virtual bool addResource(const QString &agentId,
                            const ManagedAgentResource &resource) = 0;
    
    /// Delete agent
    virtual bool deleteAgent(const QString &agentId) = 0;
    
    /// List active agents
    virtual QVector<QString> listAgents() = 0;
};
