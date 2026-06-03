#pragma once

#include "LLMTypes.h"
#include <QObject>
#include <memory>

/**
 * @class LLMExtensions
 * @brief Language model integration and management
 * 
 * Handles:
 * - Multi-provider LLM support
 * - Prompt templates
 * - Token management and budgeting
 * - Function calling
 * - Streaming responses
 * - Cost tracking
 */
class LLMExtensions : public QObject {
    Q_OBJECT
public:
    explicit LLMExtensions(QObject *parent = nullptr) : QObject(parent) {}
    virtual ~LLMExtensions() = default;

    // ── Provider Management ─────────────────────────────
    
    /// Register provider
    virtual void registerProvider(const ProviderConfig &config,
                                 std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Unregister provider
    virtual void unregisterProvider(LLMProviderType provider,
                                   std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get provider configuration
    virtual ProviderConfig getProviderConfig(LLMProviderType provider) const = 0;
    
    /// Get available providers
    virtual QVector<LLMProviderType> getAvailableProviders() const = 0;
    
    // ── Model Management ────────────────────────────────
    
    /// Get available models
    virtual QVector<ModelInfo> getAvailableModels(LLMProviderType provider = LLMProviderType::OpenAI) const = 0;
    
    /// Get model info
    virtual ModelInfo getModelInfo(const QString &modelId) const = 0;
    
    /// Register custom model
    virtual void registerCustomModel(const ModelConfig &config,
                                    std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get default model
    virtual ModelConfig getDefaultModel() const = 0;
    
    /// Set default model
    virtual void setDefaultModel(const QString &modelId) = 0;
    
    // ── Text Generation ────────────────────────────────
    
    /// Generate completion
    virtual void generateCompletion(const LLMRequest &request,
                                   LLMCallback callback = nullptr) = 0;
    
    /// Generate with template
    virtual void generateFromTemplate(const PromptTemplate &template_,
                                     const PromptVariables &variables,
                                     LLMCallback callback = nullptr) = 0;
    
    /// Chat/conversation
    virtual void chat(const QVector<Message> &messages,
                     const ModelConfig &model,
                     LLMCallback callback = nullptr) = 0;
    
    /// Summarize text
    virtual void summarizeText(const QString &text,
                              int maxTokens = 500,
                              LLMCallback callback = nullptr) = 0;
    
    /// Translate text
    virtual void translateText(const QString &text,
                              const QString &targetLanguage,
                              LLMCallback callback = nullptr) = 0;
    
    // ── Streaming ───────────────────────────────────────
    
    /// Generate with streaming
    virtual QString generateStreamingCompletion(const LLMRequest &request,
                                               StreamCallback chunkCallback = nullptr) = 0;
    
    /// Cancel streaming
    virtual void cancelStreaming(const QString &streamId,
                                std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Check stream status
    virtual bool isStreamActive(const QString &streamId) const = 0;
    
    // ── Function Calling ────────────────────────────────
    
    /// Register function
    virtual void registerFunction(const FunctionDefinition &function,
                                 std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Unregister function
    virtual void unregisterFunction(const QString &functionId,
                                   std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get registered functions
    virtual QVector<FunctionDefinition> getRegisteredFunctions() const = 0;
    
    /// Generate with functions
    virtual void generateWithFunctions(const LLMRequest &request,
                                      const QVector<FunctionDefinition> &functions,
                                      LLMCallback callback = nullptr) = 0;
    
    /// Execute function call
    virtual void executeFunctionCall(const FunctionCall &call,
                                    std::function<void(const QVariant &result)> callback = nullptr) = 0;
    
    // ── Embeddings ──────────────────────────────────────
    
    /// Generate embedding
    virtual void generateEmbedding(const QString &text,
                                  const QString &model = "",
                                  std::function<void(const QVector<float> &)> callback = nullptr) = 0;
    
    /// Generate multiple embeddings
    virtual void generateEmbeddings(const QStringList &texts,
                                   const QString &model = "",
                                   std::function<void(const QVector<QVector<float>> &)> callback = nullptr) = 0;
    
    /// Compute similarity
    virtual float computeCosineSimilarity(const QVector<float> &emb1,
                                         const QVector<float> &emb2) const = 0;
    
    // ── Prompt Templates ────────────────────────────────
    
    /// Create prompt template
    virtual QString createTemplate(const PromptTemplate &template_,
                                  std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get template
    virtual PromptTemplate getTemplate(const QString &templateId) const = 0;
    
    /// List templates
    virtual QVector<PromptTemplate> listTemplates() const = 0;
    
    /// Render template
    virtual QString renderTemplate(const PromptTemplate &template_,
                                  const PromptVariables &variables) const = 0;
    
    /// Update template
    virtual void updateTemplate(const QString &templateId,
                               const PromptTemplate &updated,
                               std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Delete template
    virtual void deleteTemplate(const QString &templateId,
                               std::function<void(bool success)> callback = nullptr) = 0;
    
    // ── Token Management ────────────────────────────────
    
    /// Get token count
    virtual int estimateTokens(const QString &text, const QString &modelId = "") const = 0;
    
    /// Get token usage
    virtual TokenUsage getTokenUsage() const = 0;
    
    /// Get token budget
    virtual TokenBudget getTokenBudget() const = 0;
    
    /// Set token budget
    virtual void setTokenBudget(const TokenBudget &budget,
                               std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Check token budget
    virtual bool hasTokenBudget(int tokensNeeded) const = 0;
    
    /// Get token history
    virtual QVector<TokenUsage> getTokenHistory(int days = 7) const = 0;
    
    // ── Cost Tracking ───────────────────────────────────
    
    /// Get estimated cost
    virtual float estimateCost(const LLMRequest &request) const = 0;
    
    /// Get total cost
    virtual float getTotalCost() const = 0;
    
    /// Get cost breakdown
    virtual QVariantMap getCostBreakdown() const = 0;
    
    // ── Configuration ───────────────────────────────────
    
    /// Set default parameters
    virtual void setDefaultParameters(float temperature, float topP, int topK) = 0;
    
    /// Get default parameters
    virtual QVariantMap getDefaultParameters() const = 0;
    
    /// Set system prompt
    virtual void setSystemPrompt(const QString &prompt) = 0;
    
    /// Get system prompt
    virtual QString getSystemPrompt() const = 0;
    
    // ── Caching & Optimization ─────────────────────────
    
    /// Enable request caching
    virtual void enableRequestCaching(bool enable) = 0;
    
    /// Get cached response
    virtual LLMResponse getCachedResponse(const QString &prompt) const = 0;
    
    /// Clear cache
    virtual void clearCache(std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Enable response optimization
    virtual void enableResponseOptimization(bool enable) = 0;
    
    // ── Rate Limiting ───────────────────────────────────
    
    /// Set rate limit
    virtual void setRateLimit(int requestsPerMinute) = 0;
    
    /// Get current request rate
    virtual int getCurrentRequestRate() const = 0;
    
    /// Wait for rate limit
    virtual void waitForRateLimit(std::function<void()> callback = nullptr) = 0;
    
    // ── Error Handling & Retry ──────────────────────────
    
    /// Get last error
    virtual QString getLastError() const = 0;
    
    /// Enable auto-retry
    virtual void enableAutoRetry(int maxRetries, int backoffMs = 1000) = 0;
    
    /// Retry last request
    virtual void retryLastRequest(LLMCallback callback = nullptr) = 0;
    
    // ── Statistics ──────────────────────────────────────
    
    /// Get request statistics
    virtual QVariantMap getRequestStatistics() const = 0;
    
    /// Get performance metrics
    virtual QVariantMap getPerformanceMetrics() const = 0;
    
    /// Get model usage statistics
    virtual QVariantMap getModelUsageStats() const = 0;
    
    // ── Monitoring ──────────────────────────────────────
    
    /// Get provider health
    virtual QVariantMap getProviderHealth() const = 0;
    
    /// Get service status
    virtual QString getServiceStatus() const = 0;

signals:
    /// Generation completed signal
    void generationCompleted(const LLMResponse &response);
    
    /// Stream chunk received signal
    void streamChunkReceived(const StreamChunk &chunk);
    
    /// Token usage signal
    void tokenUsageRecorded(const TokenUsage &usage);
    
    /// Function called signal
    void functionCalled(const FunctionCall &call);
    
    /// Error signal
    void errorOccurred(const QString &error);
    
    /// Rate limit reached signal
    void rateLimitReached();
};

using LLMExtensionsPtr = std::shared_ptr<LLMExtensions>;
