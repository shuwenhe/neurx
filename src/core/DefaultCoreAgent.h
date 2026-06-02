#pragma once

#include "CoreAgent.h"
#include <QMap>
#include <QMutex>
#include <memory>

/**
 * @class DefaultCoreAgent
 * @brief Default implementation of CoreAgent
 * 
 * Integrates all 15 subsystems:
 * - Memory, Tools, LLM, Logging
 * - Execution, State, Goals
 * - Skills, Approvals, Sandbox
 * - Plugins, Config, Thread
 * - Test, Integration
 */
class DefaultCoreAgent : public CoreAgent {
    Q_OBJECT
public:
    explicit DefaultCoreAgent(QObject *parent = nullptr);
    ~DefaultCoreAgent() = default;
    
    // Lifecycle Management
    bool initialize(const CoreAgentConfig &config) override;
    bool start() override;
    bool shutdown() override;
    bool isReady() const override;
    
    // Request Processing
    AgentResponse processRequest(const AgentRequest &request) override;
    QString processRequestAsync(const AgentRequest &request,
                               AgentResponseCallback callback = nullptr) override;
    bool cancelRequest(const QString &requestId) override;
    QString getRequestStatus(const QString &requestId) const override;
    QVector<AgentRequest> getPendingRequests() const override;
    
    // State Management
    AgentState getState() const override;
    void setState(AgentState state) override;
    AgentStatistics getStatistics() const override;
    
    // Memory Management
    QString storeMemory(const QString &key, const QVariant &value) override;
    QVariant getMemory(const QString &key) const override;
    QVector<QVariantMap> searchMemories(const QString &query) override;
    bool clearMemory(const QString &key) override;
    int getMemorySize() const override;
    
    // Tool Management
    bool registerTool(const QString &toolName, const QString &toolId) override;
    QVariant executeTool(const QString &toolName, const QVariantMap &params) override;
    QStringList getAvailableTools() const override;
    QVariantMap getToolInfo(const QString &toolName) const override;
    
    // Skill Management
    bool learnSkill(const QString &skillName, const QString &skillDef) override;
    QVariant executeSkill(const QString &skillName, const QVariantMap &params) override;
    QStringList getAvailableSkills() const override;
    QVariantMap getSkillInfo(const QString &skillName) const override;
    bool unlearnSkill(const QString &skillName) override;
    
    // Goal Management
    QString createGoal(const QString &goalName, const QString &description) override;
    bool updateGoal(const QString &goalId, const QVariantMap &updates) override;
    bool completeGoal(const QString &goalId) override;
    QVector<QVariantMap> getActiveGoals() const override;
    float getGoalProgress(const QString &goalId) const override;
    
    // LLM Integration
    QString generateCompletion(const QString &prompt, int maxTokens = 2000) override;
    QString chat(const QString &message) override;
    QString summarizeText(const QString &text) override;
    QString translateText(const QString &text, const QString &targetLanguage) override;
    
    // Execution Management
    QVector<QVariantMap> getExecutionHistory(int limit = 100) const override;
    QVariantMap getExecutionDetails(const QString &executionId) const override;
    
    // Approval Management
    QString requestApproval(const QString &action, const QString &reason) override;
    QVector<QVariantMap> getPendingApprovals() const override;
    bool isApprovalPending(const QString &approvalId) const override;
    
    // Logging and Analytics
    void logEvent(const QString &eventType, const QVariantMap &data) override;
    QVector<QVariantMap> getLogs(int limit = 100) const override;
    QVariantMap getAnalytics() const override;
    
    // Configuration
    CoreAgentConfig getConfiguration() const override;
    bool updateConfiguration(const QString &key, const QVariant &value) override;
    QVariant getConfigValue(const QString &key) const override;
    
    // Health and Diagnostics
    QVariantMap getHealthStatus() const override;
    QString runDiagnostics() override;
    QString getSystemReport() const override;
    QString getVersion() const override;
    QString getAgentId() const override;

private:
    AgentState m_state;
    CoreAgentConfig m_config;
    AgentStatistics m_statistics;
    
    // Subsystem data storage
    QMap<QString, QVariant> m_memory;
    QMap<QString, QVariantMap> m_skills;
    QMap<QString, QVariantMap> m_goals;
    QMap<QString, QVariantMap> m_tools;
    QMap<QString, AgentRequest> m_requests;
    QMap<QString, AgentResponse> m_responses;
    QVector<QVariantMap> m_logs;
    QVector<QVariantMap> m_executionHistory;
    QVector<QVariantMap> m_approvals;
    
    // Conversation history
    QVector<QVariantMap> m_conversationHistory;
    
    mutable QMutex m_mutex;
    
    QDateTime m_startedAt;
    
    // Helper methods
    bool initializeSubsystems();
    bool shutdownSubsystems();
    AgentResponse processRequestInternal(const AgentRequest &request);
    void recordExecution(const AgentRequest &request, const AgentResponse &response);
    void updateStatistics();
};

using DefaultCoreAgentPtr = std::shared_ptr<DefaultCoreAgent>;
