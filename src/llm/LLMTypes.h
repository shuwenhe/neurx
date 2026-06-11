#pragma once

#include <QString>
#include <QVector>
#include <QMap>
#include <QVariantMap>
#include <QDateTime>
#include <functional>

/**
 * LLM extension types for language model integration
 */

// ── LLM Model Types ───────────────────────────────────

enum class LLMModelType {
    Chat,           // Chat/conversation models
    Completion,     // Text completion
    Embedding,      // Embedding models
    ImageGeneration,// Image generation
    CodeGeneration, // Code generation
    Summarization,  // Summarization
    Translation,    // Translation
    CustomModel     // Custom models
};

enum class LLMProviderType {
    OpenAI,         // OpenAI (ChatGPT, GPT-4)
    Anthropic,      // Anthropic (Claude)
    Google,         // Google (Gemini, PaLM)
    Meta,           // Meta (Llama)
    LocalLLM,       // Local models
    Custom          // Custom provider
};

// ── Model Configuration ────────────────────────────────

struct ModelConfig {
    QString modelId;               // Model identifier
    QString modelName;             // Display name
    LLMModelType modelType;
    LLMProviderType provider;
    
    QString version;               // Model version
    int contextWindow = 4096;      // Max tokens
    int maxTokens = 2048;          // Max output tokens
    
    float temperature = 0.7f;      // Creativity (0.0-1.0)
    float topP = 0.9f;             // Nucleus sampling
    int topK = 40;                 // Top-K sampling
    
    float costPer1kInputTokens = 0.0f;    // Pricing
    float costPer1kOutputTokens = 0.0f;
    
    bool supportsStreaming = true;
    bool supportsFunctions = false;        // Function calling
    bool supportsVision = false;           // Image understanding
    
    QDateTime releasedAt;
    QString documentation;
    
    QVariantMap customParameters;  // Provider-specific params
};

// ── Prompt Templates ───────────────────────────────────

enum class PromptRole {
    System,      // System instructions
    User,        // User message
    Assistant,   // Assistant response
    Function     // Function result
};

struct Message {
    PromptRole role;
    QString content;
    QString name;                  // Function name if function role
    QVariantMap metadata;          // Additional metadata
};

struct PromptTemplate {
    QString templateId;
    QString name;
    QString description;
    
    QString templateContent;              // Template with {{variables}}
    QStringList variables;         // Variable names
    QStringList requiredVariables;
    
    QString systemPrompt;          // Default system prompt
    
    int expectedTokens = 0;        // Estimated tokens
    QString purpose;               // What it's for
    
    QDateTime createdAt;
};

/// Prompt variables
struct PromptVariables {
    QMap<QString, QString> variables;
    
    QString get(const QString &key, const QString &defaultValue = "") const {
        auto it = variables.find(key);
        if (it != variables.end()) {
            return *it;
        }
        return defaultValue;
    }
};

// ── LLM Request/Response ───────────────────────────────

struct CodexLLMRequest {
    QString requestId;
    ModelConfig model;
    
    QString prompt;                // Raw prompt
    PromptTemplate template_;      // Template if used
    PromptVariables variables;     // Template variables
    
    QVector<Message> messages;     // Multi-turn messages
    
    bool stream = false;           // Streaming response
    int maxTokens = 0;             // Override model max
    float temperature = -1.0f;     // Override model temp (-1 = use default)
    
    QStringList stopSequences;     // Stop generation at these
    
    QVariantMap metadata;          // Request metadata
    int retryCount = 0;            // Auto-retry count
    int timeoutMs = 30000;         // Request timeout
};

struct CodexLLMResponse {
    QString responseId;
    QString requestId;
    
    bool success;
    QString error;
    
    QString content;               // Generated text
    QVector<Message> messages;     // Message history
    
    int inputTokens = 0;           // Tokens used
    int outputTokens = 0;
    int totalTokens = 0;
    
    float cost = 0.0f;             // Estimated cost
    
    QDateTime generatedAt;
    qint64 latencyMs = 0;          // Response time
    
    float confidence = 0.0f;       // Confidence score (0-1)
    QStringList warnings;          // Warnings
};

// Backward-compatible aliases used throughout the existing codebase.
using LLMRequest = CodexLLMRequest;
using LLMResponse = CodexLLMResponse;

// ── Streaming ──────────────────────────────────────────

struct StreamChunk {
    QString chunkId;
    QString content;
    int tokenCount = 0;
    
    bool isFirst = false;
    bool isLast = false;
    
    QDateTime receivedAt;
};

// ── Token Management ───────────────────────────────────

struct TokenUsage {
    QString requestId;
    
    int inputTokens = 0;
    int outputTokens = 0;
    int totalTokens = 0;
    
    float inputCost = 0.0f;
    float outputCost = 0.0f;
    float totalCost = 0.0f;
    
    QDateTime recordedAt;
};

struct TokenBudget {
    QString budgetId;
    
    int dailyLimit = 100000;       // Daily token limit
    int weeklyLimit = 500000;      // Weekly limit
    int monthlyLimit = 2000000;    // Monthly limit
    
    int dailyUsed = 0;
    int weeklyUsed = 0;
    int monthlyUsed = 0;
    
    float dailySpent = 0.0f;       // Daily cost
    float monthlyBudget = 100.0f;  // Monthly budget
    float monthlySpent = 0.0f;
    
    QDateTime resetAt;
};

// ── Function Calling ───────────────────────────────────

enum class FunctionParameterType {
    String,
    Integer,
    Number,
    Boolean,
    Object,
    Array
};

struct FunctionParameter {
    QString name;
    FunctionParameterType type;
    QString description;
    bool required = false;
    QVariant defaultValue;
};

struct FunctionDefinition {
    QString functionId;
    QString name;
    QString description;
    
    QVector<FunctionParameter> parameters;
    QString returnDescription;
    
    QString implementation;        // Function implementation
    QString language;              // Implementation language
};

struct FunctionCall {
    QString toolCallId;
    QString functionName;
    QVariantMap arguments;
};

// ── Embeddings ─────────────────────────────────────────

struct EmbeddingRequest {
    QString requestId;
    QString input;
    QString model;                 // Embedding model
    int dimensions = 1536;         // Embedding dimensions
};

struct EmbeddingResponse {
    QString responseId;
    QString requestId;
    
    QVector<float> embedding;
    int tokenCount = 0;
    float cost = 0.0f;
};

// ── Model Information ──────────────────────────────────

struct ModelInfo {
    QString modelId;
    QString modelName;
    LLMProviderType provider;
    
    QString description;
    QStringList capabilities;      // Capabilities
    
    int contextWindow = 0;
    int maxTokens = 0;
    
    QDateTime releasedAt;
    bool isDeprecated = false;
    QDateTime deprecationDate;
    
    float costPer1kTokens = 0.0f;
};

// ── Provider Configuration ─────────────────────────────

struct ProviderConfig {
    LLMProviderType provider;
    QString apiKey;
    QString apiBaseUrl;
    QVariantMap settings;          // Provider-specific settings
    
    int requestsPerMinute = 100;   // Rate limiting
    int maxConcurrentRequests = 10;
    
    bool enabled = true;
};

// ── Callbacks ──────────────────────────────────────────

using LLMCallback = std::function<void(const LLMResponse &)>;
using TokenCallback = std::function<void(const TokenUsage &)>;
using StreamCallback = std::function<void(const StreamChunk &)>;
using ModelListCallback = std::function<void(const QVector<ModelInfo> &)>;
