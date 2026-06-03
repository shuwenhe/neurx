#include "DefaultLLMExtensions.h"
#include <QDebug>
#include <QUuid>
#include <QDateTime>
#include <cmath>
#include <algorithm>

DefaultLLMExtensions::DefaultLLMExtensions(QObject *parent)
    : LLMExtensions(parent)
{
    // Initialize default model
    m_defaultModel.modelId = "default";
    m_defaultModel.modelName = "Default Model";
    m_defaultModel.provider = LLMProviderType::OpenAI;
    m_defaultModel.contextWindow = 4096;
    m_defaultModel.maxTokens = 2048;
}

void DefaultLLMExtensions::registerProvider(const ProviderConfig &config,
                                            std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    m_providers[config.provider] = config;
    
    locker.unlock();
    
    if (callback) callback(true);
}

void DefaultLLMExtensions::unregisterProvider(LLMProviderType provider,
                                             std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    if (m_providers.remove(provider) > 0) {
        locker.unlock();
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

ProviderConfig DefaultLLMExtensions::getProviderConfig(LLMProviderType provider) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_providers.find(provider);
    if (it != m_providers.end()) {
        return *it;
    }
    
    return ProviderConfig();
}

QVector<LLMProviderType> DefaultLLMExtensions::getAvailableProviders() const
{
    QMutexLocker locker(&m_mutex);
    return m_providers.keys().toVector();
}

QVector<ModelInfo> DefaultLLMExtensions::getAvailableModels(LLMProviderType provider) const
{
    QVector<ModelInfo> models;
    
    // Return stub models
    ModelInfo model;
    model.modelId = "model-1";
    model.modelName = "Default Model";
    model.provider = provider;
    models.append(model);
    
    return models;
}

ModelInfo DefaultLLMExtensions::getModelInfo(const QString &modelId) const
{
    return ModelInfo();
}

void DefaultLLMExtensions::registerCustomModel(const ModelConfig &config,
                                               std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    m_customModels[config.modelId] = config;
    
    locker.unlock();
    
    if (callback) callback(true);
}

ModelConfig DefaultLLMExtensions::getDefaultModel() const
{
    QMutexLocker locker(&m_mutex);
    return m_defaultModel;
}

void DefaultLLMExtensions::setDefaultModel(const QString &modelId)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_customModels.find(modelId);
    if (it != m_customModels.end()) {
        m_defaultModel = *it;
    }
}

void DefaultLLMExtensions::generateCompletion(const LLMRequest &request,
                                             LLMCallback callback)
{
    QMutexLocker locker(&m_mutex);
    
    LLMResponse response;
    response.responseId = QUuid::createUuid().toString();
    response.requestId = request.requestId;
    response.success = true;
    response.content = "Generated response based on: " + request.prompt.left(50);
    response.inputTokens = estimateTokens(request.prompt);
    response.outputTokens = 100;
    response.totalTokens = response.inputTokens + response.outputTokens;
    response.generatedAt = QDateTime::currentDateTime();
    response.latencyMs = 500;
    
    m_totalRequests++;
    m_totalTokens += response.totalTokens;
    m_requestHistory[request.requestId] = request;
    
    locker.unlock();
    
    emit generationCompleted(response);
    
    if (callback) callback(response);
}

void DefaultLLMExtensions::generateFromTemplate(const PromptTemplate &template_,
                                               const PromptVariables &variables,
                                               LLMCallback callback)
{
    QString renderedPrompt = renderTemplate(template_, variables);
    
    LLMRequest request;
    request.prompt = renderedPrompt;
    
    generateCompletion(request, callback);
}

void DefaultLLMExtensions::chat(const QVector<Message> &messages,
                               const ModelConfig &model,
                               LLMCallback callback)
{
    LLMRequest request;
    request.messages = messages;
    
    generateCompletion(request, callback);
}

void DefaultLLMExtensions::summarizeText(const QString &text,
                                        int maxTokens,
                                        LLMCallback callback)
{
    LLMRequest request;
    request.prompt = "Summarize: " + text;
    request.maxTokens = maxTokens;
    
    generateCompletion(request, callback);
}

void DefaultLLMExtensions::translateText(const QString &text,
                                        const QString &targetLanguage,
                                        LLMCallback callback)
{
    LLMRequest request;
    request.prompt = QString("Translate to %1: %2").arg(targetLanguage, text);
    
    generateCompletion(request, callback);
}

QString DefaultLLMExtensions::generateStreamingCompletion(const LLMRequest &request,
                                                         StreamCallback chunkCallback)
{
    QString streamId = QUuid::createUuid().toString();
    
    QMutexLocker locker(&m_mutex);
    
    // Simulate streaming chunks
    StreamChunk chunk;
    chunk.chunkId = streamId + "-0";
    chunk.content = "Stream response chunk";
    chunk.isFirst = true;
    m_activeStreams[streamId] = chunk;
    
    locker.unlock();
    
    if (chunkCallback) {
        chunkCallback(chunk);
        
        // Simulate final chunk
        chunk.isLast = true;
        chunkCallback(chunk);
    }
    
    return streamId;
}

void DefaultLLMExtensions::cancelStreaming(const QString &streamId,
                                          std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    if (m_activeStreams.remove(streamId) > 0) {
        locker.unlock();
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

bool DefaultLLMExtensions::isStreamActive(const QString &streamId) const
{
    QMutexLocker locker(&m_mutex);
    return m_activeStreams.contains(streamId);
}

void DefaultLLMExtensions::registerFunction(const FunctionDefinition &function,
                                           std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    m_functions[function.functionId] = function;
    
    locker.unlock();
    
    if (callback) callback(true);
}

void DefaultLLMExtensions::unregisterFunction(const QString &functionId,
                                             std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    if (m_functions.remove(functionId) > 0) {
        locker.unlock();
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

QVector<FunctionDefinition> DefaultLLMExtensions::getRegisteredFunctions() const
{
    QMutexLocker locker(&m_mutex);
    return m_functions.values().toVector();
}

void DefaultLLMExtensions::generateWithFunctions(const LLMRequest &request,
                                               const QVector<FunctionDefinition> &functions,
                                               LLMCallback callback)
{
    generateCompletion(request, callback);
}

void DefaultLLMExtensions::executeFunctionCall(const FunctionCall &call,
                                              std::function<void(const QVariant &result)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_functions.find(call.functionName);
    if (it != m_functions.end()) {
        locker.unlock();
        
        emit functionCalled(call);
        
        if (callback) {
            callback(QVariant("Function execution result"));
        }
    } else {
        locker.unlock();
    }
}

void DefaultLLMExtensions::generateEmbedding(const QString &text,
                                            const QString &model,
                                            std::function<void(const QVector<float> &)> callback)
{
    QVector<float> embedding(1536);  // Default embedding size
    for (int i = 0; i < embedding.size(); ++i) {
        embedding[i] = static_cast<float>(qHash(text + QString::number(i))) / 1000.0f;
    }
    
    if (callback) callback(embedding);
}

void DefaultLLMExtensions::generateEmbeddings(const QStringList &texts,
                                             const QString &model,
                                             std::function<void(const QVector<QVector<float>> &)> callback)
{
    QVector<QVector<float>> embeddings;
    
    for (const auto &text : texts) {
        QVector<float> emb(1536);
        for (int i = 0; i < emb.size(); ++i) {
            emb[i] = static_cast<float>(qHash(text + QString::number(i))) / 1000.0f;
        }
        embeddings.append(emb);
    }
    
    if (callback) callback(embeddings);
}

float DefaultLLMExtensions::computeCosineSimilarity(const QVector<float> &emb1,
                                                   const QVector<float> &emb2) const
{
    return computeCosineSimilarityInternal(emb1, emb2);
}

QString DefaultLLMExtensions::createTemplate(const PromptTemplate &template_,
                                            std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    QString templateId = QUuid::createUuid().toString();
    
    PromptTemplate newTemplate = template_;
    newTemplate.templateId = templateId;
    newTemplate.createdAt = QDateTime::currentDateTime();
    
    m_templates[templateId] = newTemplate;
    
    locker.unlock();
    
    if (callback) callback(true);
    
    return templateId;
}

PromptTemplate DefaultLLMExtensions::getTemplate(const QString &templateId) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_templates.find(templateId);
    if (it != m_templates.end()) {
        return *it;
    }
    
    return PromptTemplate();
}

QVector<PromptTemplate> DefaultLLMExtensions::listTemplates() const
{
    QMutexLocker locker(&m_mutex);
    return m_templates.values().toVector();
}

QString DefaultLLMExtensions::renderTemplate(const PromptTemplate &template_,
                                            const PromptVariables &variables) const
{
    QString result = template_.templateContent;
    
    for (const auto &var : template_.variables) {
        QString placeholder = "{{" + var + "}}";
        result.replace(placeholder, variables.get(var, ""));
    }
    
    return result;
}

void DefaultLLMExtensions::updateTemplate(const QString &templateId,
                                         const PromptTemplate &updated,
                                         std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_templates.find(templateId);
    if (it != m_templates.end()) {
        *it = updated;
        it->templateId = templateId;
        locker.unlock();
        
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

void DefaultLLMExtensions::deleteTemplate(const QString &templateId,
                                         std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    if (m_templates.remove(templateId) > 0) {
        locker.unlock();
        if (callback) callback(true);
    } else {
        locker.unlock();
        if (callback) callback(false);
    }
}

int DefaultLLMExtensions::estimateTokens(const QString &text, const QString &modelId) const
{
    return tokenizeEstimate(text);
}

TokenUsage DefaultLLMExtensions::getTokenUsage() const
{
    QMutexLocker locker(&m_mutex);
    
    TokenUsage usage;
    usage.totalTokens = m_totalTokens;
    usage.recordedAt = QDateTime::currentDateTime();
    
    return usage;
}

TokenBudget DefaultLLMExtensions::getTokenBudget() const
{
    QMutexLocker locker(&m_mutex);
    return m_tokenBudget;
}

void DefaultLLMExtensions::setTokenBudget(const TokenBudget &budget,
                                         std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    m_tokenBudget = budget;
    
    locker.unlock();
    
    if (callback) callback(true);
}

bool DefaultLLMExtensions::hasTokenBudget(int tokensNeeded) const
{
    QMutexLocker locker(&m_mutex);
    
    return (m_tokenBudget.dailyLimit - m_tokenBudget.dailyUsed) >= tokensNeeded;
}

QVector<TokenUsage> DefaultLLMExtensions::getTokenHistory(int days) const
{
    QMutexLocker locker(&m_mutex);
    return m_tokenHistory;
}

float DefaultLLMExtensions::estimateCost(const LLMRequest &request) const
{
    int tokens = estimateTokens(request.prompt);
    return (tokens / 1000.0f) * 0.01f;
}

float DefaultLLMExtensions::getTotalCost() const
{
    QMutexLocker locker(&m_mutex);
    return m_totalCost;
}

QVariantMap DefaultLLMExtensions::getCostBreakdown() const
{
    QVariantMap breakdown;
    breakdown["totalCost"] = m_totalCost;
    breakdown["totalRequests"] = m_totalRequests;
    breakdown["totalTokens"] = m_totalTokens;
    
    return breakdown;
}

void DefaultLLMExtensions::setDefaultParameters(float temperature, float topP, int topK)
{
    QMutexLocker locker(&m_mutex);
    
    m_defaultTemperature = temperature;
    m_defaultTopP = topP;
    m_defaultTopK = topK;
}

QVariantMap DefaultLLMExtensions::getDefaultParameters() const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap params;
    params["temperature"] = m_defaultTemperature;
    params["topP"] = m_defaultTopP;
    params["topK"] = m_defaultTopK;
    
    return params;
}

void DefaultLLMExtensions::setSystemPrompt(const QString &prompt)
{
    QMutexLocker locker(&m_mutex);
    m_systemPrompt = prompt;
}

QString DefaultLLMExtensions::getSystemPrompt() const
{
    QMutexLocker locker(&m_mutex);
    return m_systemPrompt;
}

void DefaultLLMExtensions::enableRequestCaching(bool enable)
{
    QMutexLocker locker(&m_mutex);
    m_cachingEnabled = enable;
}

LLMResponse DefaultLLMExtensions::getCachedResponse(const QString &prompt) const
{
    QMutexLocker locker(&m_mutex);
    
    auto it = m_responseCache.find(prompt);
    if (it != m_responseCache.end()) {
        return *it;
    }
    
    return LLMResponse();
}

void DefaultLLMExtensions::clearCache(std::function<void(bool success)> callback)
{
    QMutexLocker locker(&m_mutex);
    
    m_responseCache.clear();
    
    locker.unlock();
    
    if (callback) callback(true);
}

void DefaultLLMExtensions::enableResponseOptimization(bool enable)
{
    QMutexLocker locker(&m_mutex);
    m_optimizationEnabled = enable;
}

void DefaultLLMExtensions::setRateLimit(int requestsPerMinute)
{
    QMutexLocker locker(&m_mutex);
    m_rateLimit = requestsPerMinute;
}

int DefaultLLMExtensions::getCurrentRequestRate() const
{
    QMutexLocker locker(&m_mutex);
    return m_totalRequests;
}

void DefaultLLMExtensions::waitForRateLimit(std::function<void()> callback)
{
    if (callback) callback();
}

QString DefaultLLMExtensions::getLastError() const
{
    QMutexLocker locker(&m_mutex);
    return m_lastError;
}

void DefaultLLMExtensions::enableAutoRetry(int maxRetries, int backoffMs)
{
    QMutexLocker locker(&m_mutex);
    
    m_maxRetries = maxRetries;
    m_backoffMs = backoffMs;
}

void DefaultLLMExtensions::retryLastRequest(LLMCallback callback)
{
    generateCompletion(m_lastRequest, callback);
}

QVariantMap DefaultLLMExtensions::getRequestStatistics() const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap stats;
    stats["totalRequests"] = m_totalRequests;
    stats["totalTokens"] = m_totalTokens;
    stats["requestHistory"] = m_requestHistory.size();
    
    return stats;
}

QVariantMap DefaultLLMExtensions::getPerformanceMetrics() const
{
    QVariantMap metrics;
    metrics["averageLatency"] = 500;
    metrics["successRate"] = 0.99f;
    
    return metrics;
}

QVariantMap DefaultLLMExtensions::getModelUsageStats() const
{
    QVariantMap stats;
    stats["defaultModel"] = m_defaultModel.modelName;
    stats["customModels"] = m_customModels.size();
    
    return stats;
}

QVariantMap DefaultLLMExtensions::getProviderHealth() const
{
    QMutexLocker locker(&m_mutex);
    
    QVariantMap health;
    
    for (auto it = m_providers.begin(); it != m_providers.end(); ++it) {
        health[QString::number(static_cast<int>(it.key()))] = "healthy";
    }
    
    return health;
}

QString DefaultLLMExtensions::getServiceStatus() const
{
    return "operational";
}

float DefaultLLMExtensions::computeCosineSimilarityInternal(const QVector<float> &emb1,
                                                          const QVector<float> &emb2) const
{
    if (emb1.isEmpty() || emb2.isEmpty() || emb1.size() != emb2.size()) {
        return 0.0f;
    }
    
    float dotProduct = 0.0f;
    float mag1 = 0.0f;
    float mag2 = 0.0f;
    
    for (int i = 0; i < emb1.size(); ++i) {
        dotProduct += emb1[i] * emb2[i];
        mag1 += emb1[i] * emb1[i];
        mag2 += emb2[i] * emb2[i];
    }
    
    mag1 = std::sqrt(mag1);
    mag2 = std::sqrt(mag2);
    
    if (mag1 > 0.0f && mag2 > 0.0f) {
        return dotProduct / (mag1 * mag2);
    }
    
    return 0.0f;
}

int DefaultLLMExtensions::tokenizeEstimate(const QString &text) const
{
    // Simple estimation: ~4 chars per token
    return text.length() / 4 + 1;
}

#include "moc_DefaultLLMExtensions.cpp"
