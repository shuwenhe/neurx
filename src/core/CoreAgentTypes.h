#pragma once

#include <QString>
#include <QVector>
#include <QMap>
#include <QVariantMap>
#include <QDateTime>
#include <functional>

/**
 * Core agent types for system integration
 */

// ── Agent State ─────────────────────────────────────

enum class AgentState {
    Uninitialized,     // Not yet initialized
    Initializing,      // Initializing subsystems
    Ready,             // Ready to process requests
    Processing,        // Processing request
    Idle,              // Idle, waiting for requests
    Paused,            // Paused
    Error,             // Error state
    Shutdown           // Shutdown
};

// ── Agent Configuration ─────────────────────────────

struct CoreAgentConfig {
    QString agentId;
    QString agentName = "NeurxAgent";
    QString version = "1.0.0";
    
    // Feature flags
    bool enableMemory = true;
    bool enableTools = true;
    bool enableLLM = true;
    bool enableLogging = true;
    bool enableApprovals = true;
    bool enableSandbox = true;
    bool enablePlugins = true;
    bool enableSkills = true;
    
    // Initialization
    int initTimeoutMs = 30000;
    bool autoStart = true;
    
    // Performance
    int maxConcurrentRequests = 10;
    int requestTimeoutMs = 60000;
    
    // Storage
    QString dataPath = "./agent_data";
    QString configPath = "./config";
    QString logPath = "./logs";
    
    // LLM settings
    QString defaultLLMProvider = "openai";
    QString defaultModel = "gpt-4";
    
    // Custom settings
    QVariantMap customSettings;
};

// ── Agent Statistics ────────────────────────────────

struct AgentStatistics {
    // Overall stats
    int totalRequests = 0;
    int successfulRequests = 0;
    int failedRequests = 0;
    float successRate = 0.0f;
    
    // Performance stats
    float averageLatency = 0.0f;    // ms
    float peakLatency = 0.0f;       // ms
    float minLatency = 0.0f;        // ms
    
    // Resource stats
    int peakMemory = 0;             // bytes
    float averageCpu = 0.0f;        // %
    
    // Subsystem stats
    int memorySize = 0;             // Memory entries
    int toolsLoaded = 0;            // Tools loaded
    int skillsLearned = 0;          // Skills learned
    int goalsActive = 0;            // Active goals
    
    QDateTime startedAt;
    QDateTime lastRequestAt;
    qint64 uptime = 0;              // ms
};

// ── Request ─────────────────────────────────────────

struct AgentRequest {
    QString requestId;
    QString userId;
    QString prompt;
    
    QStringList requiredSkills;
    QStringList requiredTools;
    
    int maxTokens = 2000;
    QString priority = "normal";     // low, normal, high, critical
    
    bool requiresApproval = false;
    QVariantMap context;
    
    QDateTime createdAt;
};

// ── Response ────────────────────────────────────────

struct AgentResponse {
    QString responseId;
    QString requestId;
    
    QString result;
    QVariantMap data;
    
    bool success = true;
    QString error;
    int errorCode = 0;
    
    int tokensUsed = 0;
    float cost = 0.0f;
    
    qint64 processingTimeMs = 0;
    
    QDateTime createdAt;
    QDateTime completedAt;
};

// ── Callbacks ───────────────────────────────────────

using AgentStateChangeCallback = std::function<void(AgentState oldState, AgentState newState)>;
using AgentRequestCallback = std::function<void(const AgentRequest &request)>;
using AgentResponseCallback = std::function<void(const AgentResponse &response)>;
using AgentErrorCallback = std::function<void(int errorCode, const QString &message)>;

#endif // COREAGENTTYPE_H
