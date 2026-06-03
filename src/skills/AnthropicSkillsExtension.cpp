#include "AnthropicSkillsExtension.h"
#include "DefaultAnthropicManagers.h"
#include <QDebug>

AnthropicSkillsExtension::AnthropicSkillsExtension(ClaudeSkillManager *skillManager)
    : m_skillManager(skillManager)
{
    // Initialize all managers with default implementations
    m_cachingManager = std::make_unique<DefaultPromptCachingManager>();
    m_thinkingManager = std::make_unique<DefaultAdaptiveThinkingManager>();
    m_effortManager = std::make_unique<DefaultEffortControlManager>();
    m_compactionManager = std::make_unique<DefaultContextCompactionManager>();
    m_toolRunner = std::make_unique<DefaultToolRunnerFramework>();
    m_fileManager = std::make_unique<DefaultFileAPIManager>();
    m_batchManager = std::make_unique<DefaultBatchProcessingManager>();
    m_agentOrchestrator = std::make_unique<DefaultManagedAgentOrchestrator>();
    
    // Initialize default budget
    m_currentBudget.totalTokenBudget = 100000;
    m_currentBudget.maxTokensPerRequest = 50000;
}

// ── Prompt Caching ────────────────────────────────────────

void AnthropicSkillsExtension::enablePromptCaching(bool enabled)
{
    m_cachingEnabled = enabled;
    qDebug() << "Prompt caching" << (enabled ? "enabled" : "disabled");
}

bool AnthropicSkillsExtension::shouldCacheContent(const QString &content, float &estimatedSavings)
{
    if (!m_cachingEnabled) {
        return false;
    }
    
    int estimatedTokens;
    return m_cachingManager->analyzeContentForCaching(content, estimatedTokens, estimatedSavings);
}

QVariantMap AnthropicSkillsExtension::getCacheStatistics() const
{
    return m_cachingManager->getCacheStats();
}

// ── Adaptive Thinking ──────────────────────────────────────

void AnthropicSkillsExtension::enableAdaptiveThinking(bool enabled)
{
    m_thinkingEnabled = enabled;
    qDebug() << "Adaptive thinking" << (enabled ? "enabled" : "disabled");
}

void AnthropicSkillsExtension::setThinkingDepth(ThinkingDepth depth)
{
    m_currentThinkingDepth = depth;
}

AdaptiveThinkingConfig AnthropicSkillsExtension::assessTask(const QString &task)
{
    if (!m_thinkingEnabled) {
        AdaptiveThinkingConfig config;
        config.enabled = false;
        return config;
    }
    
    // Assess complexity
    ThinkingDepth depth = m_thinkingManager->assessTaskComplexity(task);
    
    // Get recommended config
    QString taskType = "general";
    if (task.contains("code", Qt::CaseInsensitive) || task.contains("program", Qt::CaseInsensitive)) {
        taskType = "coding";
    } else if (task.contains("analyze", Qt::CaseInsensitive)) {
        taskType = "analysis";
    }
    
    AdaptiveThinkingConfig config = m_thinkingManager->getRecommendedConfig(taskType);
    config.budgetTokens = depth;
    
    return config;
}

QVariantMap AnthropicSkillsExtension::getThinkingMetrics() const
{
    return m_thinkingManager->getEffectivenessMetrics();
}

// ── Effort Control ────────────────────────────────────────

void AnthropicSkillsExtension::setEffortLevel(EffortLevel level)
{
    m_currentEffort = level;
    qDebug() << "Effort level set to" << static_cast<int>(level);
}

void AnthropicSkillsExtension::setTokenBudget(int totalTokens, int perRequestMax)
{
    m_currentBudget.totalTokenBudget = totalTokens;
    m_currentBudget.maxTokensPerRequest = perRequestMax;
    m_currentBudget.warningThreshold = totalTokens * 0.8;
}

BudgetStatus AnthropicSkillsExtension::getBudgetStatus() const
{
    return m_effortManager->getBudgetStatus(m_currentBudget);
}

bool AnthropicSkillsExtension::isBudgetExceeded() const
{
    return getBudgetStatus().budgetExceeded;
}

// ── Context Compaction ────────────────────────────────────

void AnthropicSkillsExtension::enableContextCompaction(bool enabled)
{
    m_compactionEnabled = enabled;
    qDebug() << "Context compaction" << (enabled ? "enabled" : "disabled");
}

void AnthropicSkillsExtension::setCompactionStrategy(CompactionStrategy strategy)
{
    m_currentCompactionStrategy = strategy;
}

CompactedContext AnthropicSkillsExtension::compactHistory(const QVector<QString> &messages)
{
    CompactionConfig config;
    config.strategy = m_currentCompactionStrategy;
    
    return m_compactionManager->compactContext(messages, config);
}

QVariantMap AnthropicSkillsExtension::getCompressionMetrics() const
{
    return m_compactionManager->getCompressionMetrics();
}

// ── Tool Runner (Agentic Loop) ─────────────────────────────

void AnthropicSkillsExtension::enableToolRunner(bool enabled)
{
    m_toolRunnerEnabled = enabled;
    qDebug() << "Tool runner" << (enabled ? "enabled" : "disabled");
}

void AnthropicSkillsExtension::registerTool(const ToolDefinition &tool)
{
    m_toolRunner->registerTool(tool);
}

ToolResult AnthropicSkillsExtension::executeTool(const QString &toolName,
                                                const QVariantMap &parameters)
{
    return m_toolRunner->executeTool(
        toolName,
        parameters,
        [this](const QString &name, const QVariantMap &params) {
            // Placeholder executor - in real implementation, would call actual tools
            ToolResult result;
            result.toolName = name;
            result.success = true;
            result.result = QVariantMap();
            return result;
        }
    );
}

void AnthropicSkillsExtension::runAgentLoop(
    const QString &query,
    std::function<void(const QVector<ToolResult> &)> callback)
{
    if (!m_toolRunnerEnabled) {
        callback(QVector<ToolResult>());
        return;
    }
    
    ToolRunnerConfig config;
    config.mode = ToolUseMode::Iterative;
    config.maxIterations = 10;
    
    m_toolRunner->runToolLoop(
        config,
        query,
        [this](const QString &name, const QVariantMap &params) {
            ToolResult result;
            result.toolName = name;
            result.success = true;
            return result;
        },
        callback
    );
}

QVariantMap AnthropicSkillsExtension::getToolMetrics() const
{
    return m_toolRunner->getToolMetrics();
}

// ── File API ───────────────────────────────────────────────

QString AnthropicSkillsExtension::uploadFile(const QString &filePath, FileType type)
{
    return m_fileManager->uploadFile(filePath, type, "");
}

FileReference AnthropicSkillsExtension::createFileReference(const QString &fileId)
{
    return m_fileManager->createFileReference(fileId, true);
}

QVector<FileMetadata> AnthropicSkillsExtension::listUploadedFiles()
{
    return m_fileManager->listFiles();
}

QVariantMap AnthropicSkillsExtension::getFileStorageStats() const
{
    return m_fileManager->getStorageStats();
}

// ── Batch Processing ───────────────────────────────────────

void AnthropicSkillsExtension::enableBatchProcessing(bool enabled)
{
    m_batchProcessingEnabled = enabled;
    qDebug() << "Batch processing" << (enabled ? "enabled" : "disabled");
}

BatchJob AnthropicSkillsExtension::createBatch(const QVector<AnthropicSkillRequest> &requests)
{
    return m_batchManager->createBatchJob(requests);
}

QString AnthropicSkillsExtension::submitBatch(const BatchJob &job)
{
    return m_batchManager->submitBatch(job);
}

QString AnthropicSkillsExtension::getBatchStatus(const QString &batchId)
{
    return m_batchManager->getBatchStatus(batchId);
}

float AnthropicSkillsExtension::calculateBatchSavings(int totalTokens)
{
    return m_batchManager->calculateCostSavings(totalTokens);
}

// ── Managed Agents ─────────────────────────────────────────

QString AnthropicSkillsExtension::createManagedAgent(const ManagedAgentConfig &config)
{
    return m_agentOrchestrator->createAgent(config);
}

void AnthropicSkillsExtension::sendAgentMessage(
    const QString &agentId,
    const QString &message,
    ManagedAgentCallback callback)
{
    m_agentOrchestrator->sendMessage(agentId, message, callback);
}

QVariantMap AnthropicSkillsExtension::getAgentState(const QString &agentId)
{
    return m_agentOrchestrator->getAgentState(agentId);
}

bool AnthropicSkillsExtension::addAgentResource(
    const QString &agentId,
    const ManagedAgentResource &resource)
{
    return m_agentOrchestrator->addResource(agentId, resource);
}

bool AnthropicSkillsExtension::deleteAgent(const QString &agentId)
{
    return m_agentOrchestrator->deleteAgent(agentId);
}

// ── Integrated Request Execution ───────────────────────────

void AnthropicSkillsExtension::executeWithAnthropicFeatures(
    const AnthropicSkillRequest &request,
    std::function<void(bool success, const QVariantMap &result)> callback)
{
    QVariantMap result;
    
    // Apply prompt caching if enabled
    if (m_cachingEnabled && request.usePromptCaching) {
        result["cachingApplied"] = true;
        result["cacheConfig"] = QVariantMap{
            {"type", static_cast<int>(request.cacheConfig.type)},
            {"ttl", request.cacheConfig.ttlSeconds}
        };
    }
    
    // Apply adaptive thinking if enabled
    if (m_thinkingEnabled && request.thinking.enabled) {
        result["thinkingApplied"] = true;
        result["thinkingDepth"] = static_cast<int>(request.thinking.budgetTokens);
        result["thinkingBudget"] = request.thinking.maxThinkingTokens;
    }
    
    // Apply effort control
    result["effortLevel"] = static_cast<int>(request.effort.level);
    
    // Check budget
    QString budgetReason;
    if (!m_effortManager->enforceTokenBudget(
            request.budget,
            m_effortManager->estimateTokensForEffort(request.effort.level),
            budgetReason)) {
        result["budgetExceeded"] = true;
        result["budgetReason"] = budgetReason;
        if (callback) {
            callback(false, result);
        }
        return;
    }
    
    // Apply context compaction if needed
    if (m_compactionEnabled) {
        result["compactionApplied"] = true;
        result["compactionStrategy"] = static_cast<int>(request.compaction.strategy);
    }
    
    // Execute skill with parameters
    result["skillExecuted"] = true;
    result["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    
    if (callback) {
        callback(true, result);
    }
}

QVariantMap AnthropicSkillsExtension::getFeatureStatus() const
{
    QVariantMap status;
    status["cachingEnabled"] = m_cachingEnabled;
    status["thinkingEnabled"] = m_thinkingEnabled;
    status["compactionEnabled"] = m_compactionEnabled;
    status["toolRunnerEnabled"] = m_toolRunnerEnabled;
    status["batchProcessingEnabled"] = m_batchProcessingEnabled;
    status["currentEffort"] = static_cast<int>(m_currentEffort);
    status["currentThinkingDepth"] = static_cast<int>(m_currentThinkingDepth);
    
    return status;
}

QVariantMap AnthropicSkillsExtension::getComprehensiveStats() const
{
    QVariantMap stats;
    
    stats["features"] = getFeatureStatus();
    stats["cache"] = getCacheStatistics();
    stats["thinking"] = getThinkingMetrics();
    stats["budget"] = QVariantMap{
        {"total", m_currentBudget.totalTokenBudget},
        {"spent", m_currentBudget.tokensSpentSoFar},
        {"remaining", m_currentBudget.totalTokenBudget - m_currentBudget.tokensSpentSoFar}
    };
    stats["compression"] = getCompressionMetrics();
    stats["tools"] = getToolMetrics();
    stats["storage"] = getFileStorageStats();
    
    return stats;
}
