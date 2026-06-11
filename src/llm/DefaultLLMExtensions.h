#pragma once

#include "llm/LLMExtensions.h"
#include <QMap>
#include <QMutex>

/**
 * @class DefaultLLMExtensions
 * @brief Default LLM integration implementation
 * 
 * Features:
 * - Multi-provider support
 * - Prompt templates
 * - Token management
 * - Function calling
 * - Streaming responses
 */
class DefaultLLMExtensions : public LLMExtensions {
    Q_OBJECT
public:
    explicit DefaultLLMExtensions(QObject *parent = nullptr);
    ~DefaultLLMExtensions() = default;
    
    // Provider Management
    void registerProvider(const ProviderConfig &config,
                         std::function<void(bool success)> callback = nullptr) override;
    void unregisterProvider(LLMProviderType provider,
                           std::function<void(bool success)> callback = nullptr) override;
    ProviderConfig getProviderConfig(LLMProviderType provider) const override;
    QVector<LLMProviderType> getAvailableProviders() const override;
    
    // Model Management
    QVector<ModelInfo> getAvailableModels(LLMProviderType provider = LLMProviderType::OpenAI) const override;
    ModelInfo getModelInfo(const QString &modelId) const override;
    void registerCustomModel(const ModelConfig &config,
                            std::function<void(bool success)> callback = nullptr) override;
    ModelConfig getDefaultModel() const override;
    void setDefaultModel(const QString &modelId) override;
    
    // Text Generation
    void generateCompletion(const LLMRequest &request,
                           LLMCallback callback = nullptr) override;
    void generateFromTemplate(const PromptTemplate &template_,
                             const PromptVariables &variables,
                             LLMCallback callback = nullptr) override;
    void chat(const QVector<Message> &messages,
             const ModelConfig &model,
             LLMCallback callback = nullptr) override;
    void summarizeText(const QString &text,
                      int maxTokens = 500,
                      LLMCallback callback = nullptr) override;
    void translateText(const QString &text,
                      const QString &targetLanguage,
                      LLMCallback callback = nullptr) override;
    
    // Streaming
    QString generateStreamingCompletion(const LLMRequest &request,
                                       StreamCallback chunkCallback = nullptr) override;
    void cancelStreaming(const QString &streamId,
                        std::function<void(bool success)> callback = nullptr) override;
    bool isStreamActive(const QString &streamId) const override;
    
    // Function Calling
    void registerFunction(const FunctionDefinition &function,
                         std::function<void(bool success)> callback = nullptr) override;
    void unregisterFunction(const QString &functionId,
                           std::function<void(bool success)> callback = nullptr) override;
    QVector<FunctionDefinition> getRegisteredFunctions() const override;
    void generateWithFunctions(const LLMRequest &request,
                              const QVector<FunctionDefinition> &functions,
                              LLMCallback callback = nullptr) override;
    void executeFunctionCall(const FunctionCall &call,
                            std::function<void(const QVariant &result)> callback = nullptr) override;
    
    // Embeddings
    void generateEmbedding(const QString &text,
                          const QString &model = "",
                          std::function<void(const QVector<float> &)> callback = nullptr) override;
    void generateEmbeddings(const QStringList &texts,
                           const QString &model = "",
                           std::function<void(const QVector<QVector<float>> &)> callback = nullptr) override;
    float computeCosineSimilarity(const QVector<float> &emb1,
                                 const QVector<float> &emb2) const override;
    
    // Prompt Templates
    QString createTemplate(const PromptTemplate &template_,
                          std::function<void(bool success)> callback = nullptr) override;
    PromptTemplate getTemplate(const QString &templateId) const override;
    QVector<PromptTemplate> listTemplates() const override;
    QString renderTemplate(const PromptTemplate &template_,
                          const PromptVariables &variables) const override;
    void updateTemplate(const QString &templateId,
                       const PromptTemplate &updated,
                       std::function<void(bool success)> callback = nullptr) override;
    void deleteTemplate(const QString &templateId,
                       std::function<void(bool success)> callback = nullptr) override;
    
    // Token Management
    int estimateTokens(const QString &text, const QString &modelId = "") const override;
    TokenUsage getTokenUsage() const override;
    TokenBudget getTokenBudget() const override;
    void setTokenBudget(const TokenBudget &budget,
                       std::function<void(bool success)> callback = nullptr) override;
    bool hasTokenBudget(int tokensNeeded) const override;
    QVector<TokenUsage> getTokenHistory(int days = 7) const override;
    
    // Cost Tracking
    float estimateCost(const LLMRequest &request) const override;
    float getTotalCost() const override;
    QVariantMap getCostBreakdown() const override;
    
    // Configuration
    void setDefaultParameters(float temperature, float topP, int topK) override;
    QVariantMap getDefaultParameters() const override;
    void setSystemPrompt(const QString &prompt) override;
    QString getSystemPrompt() const override;
    
    // Caching & Optimization
    void enableRequestCaching(bool enable) override;
    LLMResponse getCachedResponse(const QString &prompt) const override;
    void clearCache(std::function<void(bool success)> callback = nullptr) override;
    void enableResponseOptimization(bool enable) override;
    
    // Rate Limiting
    void setRateLimit(int requestsPerMinute) override;
    int getCurrentRequestRate() const override;
    void waitForRateLimit(std::function<void()> callback = nullptr) override;
    
    // Error Handling & Retry
    QString getLastError() const override;
    void enableAutoRetry(int maxRetries, int backoffMs = 1000) override;
    void retryLastRequest(LLMCallback callback = nullptr) override;
    
    // Statistics
    QVariantMap getRequestStatistics() const override;
    QVariantMap getPerformanceMetrics() const override;
    QVariantMap getModelUsageStats() const override;
    
    // Monitoring
    QVariantMap getProviderHealth() const override;
    QString getServiceStatus() const override;

private:
    QMap<LLMProviderType, ProviderConfig> m_providers;
    QMap<QString, ModelConfig> m_customModels;
    QMap<QString, PromptTemplate> m_templates;
    QMap<QString, FunctionDefinition> m_functions;
    QMap<QString, LLMResponse> m_responseCache;
    QMap<QString, StreamChunk> m_activeStreams;
    QMap<QString, LLMRequest> m_requestHistory;
    
    QVector<TokenUsage> m_tokenHistory;
    TokenBudget m_tokenBudget;
    
    ModelConfig m_defaultModel;
    QString m_systemPrompt;
    
    float m_defaultTemperature = 0.7f;
    float m_defaultTopP = 0.9f;
    int m_defaultTopK = 40;
    
    float m_totalCost = 0.0f;
    int m_totalRequests = 0;
    int m_totalTokens = 0;
    
    bool m_cachingEnabled = false;
    bool m_optimizationEnabled = false;
    int m_maxRetries = 3;
    int m_backoffMs = 1000;
    int m_rateLimit = 100;
    
    QString m_lastError;
    LLMRequest m_lastRequest;
    
    mutable QMutex m_mutex;
    
    // Helper methods
    float computeCosineSimilarityInternal(const QVector<float> &emb1, const QVector<float> &emb2) const;
    int tokenizeEstimate(const QString &text) const;
};

using DefaultLLMExtensionsPtr = std::shared_ptr<DefaultLLMExtensions>;
