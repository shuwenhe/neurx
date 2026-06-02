#pragma once

#include <QString>
#include <QVector>
#include <QVariantMap>
#include <QDateTime>
#include <functional>

/**
 * @file LLMProviderTypes.h
 * @brief LLM提供商类型定义
 */

// ── LLM模型类型 ────────────────────────────────

enum class LLMModel {
    Claude3_5_Sonnet,      // Claude 3.5 Sonnet (最强)
    Claude3_Opus,          // Claude 3 Opus
    Claude3_Sonnet,        // Claude 3 Sonnet
    Claude3_Haiku,         // Claude 3 Haiku (最快)
    
    GPT4_Turbo,            // GPT-4 Turbo
    GPT4,                  // GPT-4
    GPT35_Turbo,           // GPT-3.5 Turbo (最快)
    
    DeepSeek,              // DeepSeek 模型
    Llama2,                // Llama 2
    Unknown                // 未知模型
};

// ── 响应质量等级 ────────────────────────────

enum class ResponseQuality {
    Poor,      // 质量差（<50%可用性）
    Fair,      // 一般（50-70%）
    Good,      // 良好（70-85%）
    Excellent  // 优秀（>85%）
};

// ── LLM API响应 ────────────────────────────────

struct LLMResponse {
    QString id;                    // 响应ID（用于追踪）
    QString content;               // 响应内容
    QString model;                 // 使用的模型
    int inputTokens;               // 输入token数
    int outputTokens;              // 输出token数
    int totalTokens;               // 总token数
    
    float costUSD;                 // API调用成本（美元）
    int latencyMs;                 // 响应延迟（毫秒）
    
    QDateTime timestamp;           // 响应时间戳
    ResponseQuality quality;       // 响应质量评估
    QString qualityReason;         // 质量评估原因
    
    bool success;                  // 是否成功
    QString error;                 // 错误信息
};

// ── LLM分析结果 ────────────────────────────────

struct LLMAnalysisResult {
    QString analysisId;
    QString code;
    QString model;
    
    // 分析结果
    QVector<QString> issues;       // 发现的问题
    QVector<QString> suggestions;  // 改进建议
    QVector<QString> risks;        // 风险评估
    
    int bugCount;
    int securityIssueCount;
    int performanceIssueCount;
    
    float overallScore;            // 总体评分(0-100)
    QString explanation;           // 详细解释
    
    // 成本和性能
    int tokensUsed;
    float costUSD;
    int latencyMs;
    
    QDateTime analyzedAt;
};

// ── LLM生成结果 ────────────────────────────────

struct LLMGeneratedCode {
    QString generationId;
    QString code;
    QString explanation;
    QString model;
    
    QVector<QString> keyPoints;
    QVector<QString> bestPractices;
    QString codeStyle;             // 代码风格说明
    
    // 质量指标
    float estimatedQuality;        // 估计质量(0-100)
    float codeCompleteness;        // 完整性(0-100)
    bool hasErrorHandling;         // 是否包含错误处理
    bool hasDocumentation;         // 是否包含文档
    bool hasTests;                 // 是否包含测试
    
    // 成本和性能
    int tokensUsed;
    float costUSD;
    int latencyMs;
    
    QDateTime generatedAt;
};

// ── LLM修复建议 ────────────────────────────────

struct LLMFixSuggestion {
    QString suggestionId;
    QString issue;
    QString fixedCode;
    QString explanation;
    
    float riskLevel;               // 修复风险(0-1)
    float benefitScore;            // 收益分数(0-100)
    int estimatedChanges;          // 估计改变行数
    
    QVector<QString> sideEffects;  // 可能的副作用
    QVector<QString> alternatives; // 替代方案
    
    QString model;
    QDateTime suggestedAt;
};

// ── LLM提供商配置 ────────────────────────────

struct LLMProviderConfig {
    QString apiKey;                // API密钥
    QString apiEndpoint;           // API端点（可选，用于自定义）
    
    LLMModel defaultModel;         // 默认模型
    LLMModel fallbackModel;        // 备用模型
    
    int maxRetries;                // 最大重试次数
    int timeoutMs;                 // 超时时间（毫秒）
    int maxTokens;                 // 最大token数
    
    float temperature;             // 温度(0-2)：越高越创意
    bool enableCaching;            // 是否启用缓存
    int cacheExpireMinutes;        // 缓存过期时间（分钟）
    
    bool enableFallback;           // 失败时是否使用本地方案
    bool enableCostLimit;          // 是否限制成本
    float maxCostPerRequestUSD;    // 单个请求最大成本
};

// ── 缓存项 ────────────────────────────────────

struct LLMCacheEntry {
    QString hash;                  // 输入哈希值
    LLMResponse response;          // 缓存的响应
    QDateTime createdAt;
    QDateTime expiresAt;
    int hitCount;                  // 命中次数
};

// ── LLM统计信息 ────────────────────────────────

struct LLMStatistics {
    int totalRequests;             // 总请求数
    int successCount;              // 成功数
    int failureCount;              // 失败数
    float successRate;             // 成功率
    
    int totalTokensUsed;           // 总token数
    float totalCostUSD;            // 总成本
    
    int averageLatencyMs;          // 平均延迟
    int minLatencyMs;
    int maxLatencyMs;
    
    int cacheHits;                 // 缓存命中
    float cacheHitRate;            // 缓存命中率
    
    QVector<QString> topErrors;    // 常见错误
    QVector<LLMModel> usedModels;  // 使用过的模型
};

// ── 回调类型定义 ────────────────────────────────

using LLMResponseCallback = std::function<void(const LLMResponse&)>;
using LLMAnalysisCallback = std::function<void(const LLMAnalysisResult&)>;
using LLMGenerationCallback = std::function<void(const LLMGeneratedCode&)>;
using LLMProgressCallback = std::function<void(const QString& message, int progress)>;

#endif // LLMPROVIDERTYPES_H
