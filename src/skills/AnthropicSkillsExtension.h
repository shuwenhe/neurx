#pragma once

#include "ClaudeSkillManager.h"
#include "AnthropicSkillsTypes.h"
#include "AnthropicManagers.h"
#include <memory>

/**
 * @class AnthropicSkillsExtension
 * @brief Extends ClaudeSkillManager with Anthropic-specific advanced features
 * 
 * Integrates:
 * - Prompt Caching for cost optimization
 * - Adaptive Thinking for flexible reasoning
 * - Effort Control for token budgeting
 * - Context Compaction for long conversations
 * - Tool Runner for autonomous execution
 * - File API for cross-request file management
 * - Batch Processing for cost-effective async operations
 * - Managed Agents for server-hosted state
 * 
 * Usage:
 * ```cpp
 * auto skillMgr = std::make_unique<ClaudeSkillManager>();
 * auto anthropicExt = std::make_unique<AnthropicSkillsExtension>(skillMgr.get());
 * 
 * // Now use Anthropic features
 * anthropicExt->enablePromptCaching();
 * anthropicExt->enableAdaptiveThinking();
 * anthropicExt->setEffortLevel(EffortLevel::High);
 * ```
 */
class AnthropicSkillsExtension {
public:
    AnthropicSkillsExtension(ClaudeSkillManager *skillManager);
    ~AnthropicSkillsExtension() = default;
    
    // ── Prompt Caching ────────────────────────────────────
    
    /// Enable prompt caching
    void enablePromptCaching(bool enabled = true);
    
    /// Analyze content for caching potential
    bool shouldCacheContent(const QString &content, float &estimatedSavings);
    
    /// Get current cache statistics
    QVariantMap getCacheStatistics() const;
    
    // ── Adaptive Thinking ──────────────────────────────────
    
    /// Enable adaptive thinking
    void enableAdaptiveThinking(bool enabled = true);
    
    /// Set thinking depth
    void setThinkingDepth(ThinkingDepth depth);
    
    /// Assess task complexity and get recommended config
    AdaptiveThinkingConfig assessTask(const QString &task);
    
    /// Get thinking metrics
    QVariantMap getThinkingMetrics() const;
    
    // ── Effort Control ────────────────────────────────────
    
    /// Set effort level for operations
    void setEffortLevel(EffortLevel level);
    
    /// Set token budget
    void setTokenBudget(int totalTokens, int perRequestMax = 50000);
    
    /// Get current budget status
    BudgetStatus getBudgetStatus() const;
    
    /// Check if budget is exceeded
    bool isBudgetExceeded() const;
    
    // ── Context Compaction ────────────────────────────────
    
    /// Enable automatic context compaction
    void enableContextCompaction(bool enabled = true);
    
    /// Set compaction strategy
    void setCompactionStrategy(CompactionStrategy strategy);
    
    /// Compact conversation history
    CompactedContext compactHistory(const QVector<QString> &messages);
    
    /// Get compression metrics
    QVariantMap getCompressionMetrics() const;
    
    // ── Tool Runner (Agentic Loop) ─────────────────────────
    
    /// Enable tool runner for autonomous execution
    void enableToolRunner(bool enabled = true);
    
    /// Register a tool for autonomous execution
    void registerTool(const ToolDefinition &tool);
    
    /// Execute tool with automatic retry logic
    ToolResult executeTool(const QString &toolName,
                          const QVariantMap &parameters);
    
    /// Run full tool loop (agentic loop)
    void runAgentLoop(const QString &query,
                     std::function<void(const QVector<ToolResult> &)> callback);
    
    /// Get tool execution metrics
    QVariantMap getToolMetrics() const;
    
    // ── File API ───────────────────────────────────────────
    
    /// Upload file for cross-request access
    QString uploadFile(const QString &filePath, FileType type);
    
    /// Create file reference with caching
    FileReference createFileReference(const QString &fileId);
    
    /// List uploaded files
    QVector<FileMetadata> listUploadedFiles();
    
    /// Get file storage statistics
    QVariantMap getFileStorageStats() const;
    
    // ── Batch Processing ───────────────────────────────────
    
    /// Enable batch processing mode
    void enableBatchProcessing(bool enabled = true);
    
    /// Create batch job from multiple requests
    BatchJob createBatch(const QVector<AnthropicSkillRequest> &requests);
    
    /// Submit batch for processing
    QString submitBatch(const BatchJob &job);
    
    /// Get batch status
    QString getBatchStatus(const QString &batchId);
    
    /// Calculate cost savings from batch processing
    float calculateBatchSavings(int totalTokens);
    
    // ── Managed Agents ─────────────────────────────────────
    
    /// Create a managed agent instance
    QString createManagedAgent(const ManagedAgentConfig &config);
    
    /// Send message to managed agent
    void sendAgentMessage(const QString &agentId,
                         const QString &message,
                         ManagedAgentCallback callback);
    
    /// Get agent state
    QVariantMap getAgentState(const QString &agentId);
    
    /// Add resource to agent
    bool addAgentResource(const QString &agentId,
                         const ManagedAgentResource &resource);
    
    /// Delete agent
    bool deleteAgent(const QString &agentId);
    
    // ── Integrated Request Execution ───────────────────────
    
    /// Execute skill with full Anthropic feature support
    void executeWithAnthropicFeatures(
        const AnthropicSkillRequest &request,
        std::function<void(bool success, const QVariantMap &result)> callback
    );
    
    /// Get comprehensive feature status
    QVariantMap getFeatureStatus() const;
    
    /// Get comprehensive statistics
    QVariantMap getComprehensiveStats() const;
    
private:
    ClaudeSkillManager *m_skillManager;
    
    // Managers
    std::unique_ptr<PromptCachingManager> m_cachingManager;
    std::unique_ptr<AdaptiveThinkingManager> m_thinkingManager;
    std::unique_ptr<EffortControlManager> m_effortManager;
    std::unique_ptr<ContextCompactionManager> m_compactionManager;
    std::unique_ptr<ToolRunnerFramework> m_toolRunner;
    std::unique_ptr<FileAPIManager> m_fileManager;
    std::unique_ptr<BatchProcessingManager> m_batchManager;
    std::unique_ptr<ManagedAgentOrchestrator> m_agentOrchestrator;
    
    // Feature flags
    bool m_cachingEnabled{false};
    bool m_thinkingEnabled{false};
    bool m_compactionEnabled{false};
    bool m_toolRunnerEnabled{false};
    bool m_batchProcessingEnabled{false};
    
    // Current configuration
    EffortLevel m_currentEffort{EffortLevel::Medium};
    ThinkingDepth m_currentThinkingDepth{ThinkingDepth::Standard};
    CompactionStrategy m_currentCompactionStrategy{CompactionStrategy::Automatic};
    TaskBudget m_currentBudget;
};
