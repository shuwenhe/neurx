#pragma once

#include "CoreAgentTypes.h"
#include <QObject>
#include <memory>

/**
 * @class CoreAgent
 * @brief Central interface for the agent system
 * 
 * Integrates all subsystems and provides a unified API for:
 * - Request processing
 * - Memory management
 * - Tool execution
 * - LLM interaction
 * - Skill management
 * - Goal tracking
 * - State management
 */
class CoreAgent : public QObject {
    Q_OBJECT
public:
    explicit CoreAgent(QObject *parent = nullptr) : QObject(parent) {}
    virtual ~CoreAgent() = default;
    
    // ── Lifecycle Management ────────────────────────────
    
    /// Initialize agent with configuration
    virtual bool initialize(const CoreAgentConfig &config) = 0;
    
    /// Start the agent
    virtual bool start() = 0;
    
    /// Shutdown the agent
    virtual bool shutdown() = 0;
    
    /// Check if agent is ready
    virtual bool isReady() const = 0;
    
    // ── Request Processing ──────────────────────────────
    
    /// Process a single request
    virtual AgentResponse processRequest(const AgentRequest &request) = 0;
    
    /// Process request asynchronously
    virtual QString processRequestAsync(const AgentRequest &request,
                                        AgentResponseCallback callback = nullptr) = 0;
    
    /// Cancel a request
    virtual bool cancelRequest(const QString &requestId) = 0;
    
    /// Get request status
    virtual QString getRequestStatus(const QString &requestId) const = 0;
    
    /// Get pending requests
    virtual QVector<AgentRequest> getPendingRequests() const = 0;
    
    // ── State Management ────────────────────────────────
    
    /// Get agent state
    virtual AgentState getState() const = 0;
    
    /// Set agent state
    virtual void setState(AgentState state) = 0;
    
    /// Get agent statistics
    virtual AgentStatistics getStatistics() const = 0;
    
    // ── Memory Management ───────────────────────────────
    
    /// Store memory
    virtual QString storeMemory(const QString &key, const QVariant &value) = 0;
    
    /// Retrieve memory
    virtual QVariant getMemory(const QString &key) const = 0;
    
    /// Search memories
    virtual QVector<QVariantMap> searchMemories(const QString &query) = 0;
    
    /// Clear memory
    virtual bool clearMemory(const QString &key) = 0;
    
    /// Get memory statistics
    virtual int getMemorySize() const = 0;
    
    // ── Tool Management ────────────────────────────────
    
    /// Register a tool
    virtual bool registerTool(const QString &toolName, const QString &toolId) = 0;
    
    /// Execute a tool
    virtual QVariant executeTool(const QString &toolName, const QVariantMap &params) = 0;
    
    /// Get available tools
    virtual QStringList getAvailableTools() const = 0;
    
    /// Get tool info
    virtual QVariantMap getToolInfo(const QString &toolName) const = 0;
    
    // ── Skill Management ────────────────────────────────
    
    /// Learn a skill
    virtual bool learnSkill(const QString &skillName, const QString &skillDef) = 0;
    
    /// Execute a skill
    virtual QVariant executeSkill(const QString &skillName, const QVariantMap &params) = 0;
    
    /// Get available skills
    virtual QStringList getAvailableSkills() const = 0;
    
    /// Get skill info
    virtual QVariantMap getSkillInfo(const QString &skillName) const = 0;
    
    /// Unlearn a skill
    virtual bool unlearnSkill(const QString &skillName) = 0;
    
    // ── Goal Management ────────────────────────────────
    
    /// Create a goal
    virtual QString createGoal(const QString &goalName, const QString &description) = 0;
    
    /// Update goal
    virtual bool updateGoal(const QString &goalId, const QVariantMap &updates) = 0;
    
    /// Complete goal
    virtual bool completeGoal(const QString &goalId) = 0;
    
    /// Get active goals
    virtual QVector<QVariantMap> getActiveGoals() const = 0;
    
    /// Track goal progress
    virtual float getGoalProgress(const QString &goalId) const = 0;
    
    // ── LLM Integration ────────────────────────────────
    
    /// Generate completion
    virtual QString generateCompletion(const QString &prompt, int maxTokens = 2000) = 0;
    
    /// Chat interaction
    virtual QString chat(const QString &message) = 0;
    
    /// Summarize text
    virtual QString summarizeText(const QString &text) = 0;
    
    /// Translate text
    virtual QString translateText(const QString &text, const QString &targetLanguage) = 0;
    
    // ── Execution Management ────────────────────────────
    
    /// Get execution history
    virtual QVector<QVariantMap> getExecutionHistory(int limit = 100) const = 0;
    
    /// Get execution details
    virtual QVariantMap getExecutionDetails(const QString &executionId) const = 0;
    
    // ── Approval Management ─────────────────────────────
    
    /// Request approval
    virtual QString requestApproval(const QString &action, const QString &reason) = 0;
    
    /// Get pending approvals
    virtual QVector<QVariantMap> getPendingApprovals() const = 0;
    
    /// Check approval status
    virtual bool isApprovalPending(const QString &approvalId) const = 0;
    
    // ── Logging and Analytics ───────────────────────────
    
    /// Log event
    virtual void logEvent(const QString &eventType, const QVariantMap &data) = 0;
    
    /// Get logs
    virtual QVector<QVariantMap> getLogs(int limit = 100) const = 0;
    
    /// Get analytics
    virtual QVariantMap getAnalytics() const = 0;
    
    // ── Configuration ───────────────────────────────────
    
    /// Get configuration
    virtual CoreAgentConfig getConfiguration() const = 0;
    
    /// Update configuration
    virtual bool updateConfiguration(const QString &key, const QVariant &value) = 0;
    
    /// Get config value
    virtual QVariant getConfigValue(const QString &key) const = 0;
    
    // ── Health and Diagnostics ──────────────────────────
    
    /// Get health status
    virtual QVariantMap getHealthStatus() const = 0;
    
    /// Run diagnostics
    virtual QString runDiagnostics() = 0;
    
    /// Get system report
    virtual QString getSystemReport() const = 0;
    
    /// Get version
    virtual QString getVersion() const = 0;
    
    /// Get agent ID
    virtual QString getAgentId() const = 0;

signals:
    /// State changed
    void stateChanged(AgentState oldState, AgentState newState);
    
    /// Request received
    void requestReceived(const AgentRequest &request);
    
    /// Response generated
    void responseGenerated(const AgentResponse &response);
    
    /// Error occurred
    void errorOccurred(int errorCode, const QString &message);
    
    /// Goal completed
    void goalCompleted(const QString &goalId);
    
    /// Skill learned
    void skillLearned(const QString &skillName);
};

using CoreAgentPtr = std::shared_ptr<CoreAgent>;
