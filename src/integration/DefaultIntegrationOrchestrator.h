#pragma once

#include "IntegrationOrchestrator.h"
#include <QMap>
#include <QMutex>
#include <QTimer>

/**
 * @class DefaultIntegrationOrchestrator
 * @brief Default implementation of the orchestration layer
 * 
 * Features:
 * - Centralized system management
 * - Health monitoring
 * - Workflow execution
 * - Message routing
 * - Circuit breaking
 * - Error recovery
 */
class DefaultIntegrationOrchestrator : public IntegrationOrchestrator {
    Q_OBJECT
public:
    explicit DefaultIntegrationOrchestrator(QObject *parent = nullptr);
    ~DefaultIntegrationOrchestrator() = default;
    
    // System Lifecycle
    void initialize(const IntegrationConfiguration &config,
                   std::function<void(bool success)> callback = nullptr) override;
    void shutdown(bool graceful = true,
                 std::function<void(bool success)> callback = nullptr) override;
    void start(std::function<void(bool success)> callback = nullptr) override;
    void stop(std::function<void(bool success)> callback = nullptr) override;
    void pause(std::function<void(bool success)> callback = nullptr) override;
    void resume(std::function<void(bool success)> callback = nullptr) override;
    void restart(std::function<void(bool success)> callback = nullptr) override;
    
    // State Management
    SystemState getSystemState() const override;
    HealthStatus getHealthStatus() const override;
    SystemMetrics getSystemMetrics() const override;
    void setState(SystemState state,
                 SystemStateChangeCallback callback = nullptr) override;
    
    // Subsystem Management
    void registerSubsystem(SubsystemType type, const QString &name,
                          std::function<void(bool success)> callback = nullptr) override;
    void unregisterSubsystem(SubsystemType type,
                            std::function<void(bool success)> callback = nullptr) override;
    void enableSubsystem(SubsystemType type,
                        std::function<void(bool success)> callback = nullptr) override;
    void disableSubsystem(SubsystemType type,
                         std::function<void(bool success)> callback = nullptr) override;
    SubsystemHealth getSubsystemHealth(SubsystemType type) const override;
    QVector<SubsystemHealth> getAllSubsystemHealth() const override;
    bool isSubsystemAvailable(SubsystemType type) const override;
    void restartSubsystem(SubsystemType type,
                         std::function<void(bool success)> callback = nullptr) override;
    
    // Health Monitoring
    void startHealthChecking(int intervalMs = 5000) override;
    void stopHealthChecking() override;
    SystemMetrics performHealthCheck() override;
    bool checkSubsystemHealth(SubsystemType type) override;
    QString getHealthReport() const override;
    
    // Workflow Execution
    void defineWorkflow(const Workflow &workflow,
                       std::function<void(bool success)> callback = nullptr) override;
    QString executeWorkflow(const QString &workflowId,
                           const RequestContext &context,
                           WorkflowCallback callback = nullptr) override;
    WorkflowExecution getWorkflowExecution(const QString &executionId) const override;
    void cancelWorkflowExecution(const QString &executionId,
                                std::function<void(bool success)> callback = nullptr) override;
    Workflow getWorkflow(const QString &workflowId) const override;
    QVector<Workflow> listWorkflows() const override;
    void deleteWorkflow(const QString &workflowId,
                       std::function<void(bool success)> callback = nullptr) override;
    
    // Message Routing
    QString sendMessage(const SystemMessage &message,
                       MessageCallback callback = nullptr) override;
    void broadcastMessage(const SystemMessage &message,
                         SubsystemType excludeSubsystem = SubsystemType::Custom) override;
    void registerMessageHandler(const QString &messageType,
                               MessageCallback handler) override;
    SystemMessage getMessage(const QString &messageId) const override;
    QVector<SystemMessage> getPendingMessages(SubsystemType subsystem) const override;
    
    // Circuit Breaker
    CircuitBreaker getCircuitBreaker(SubsystemType subsystem) const override;
    void openCircuit(SubsystemType subsystem,
                    std::function<void(bool success)> callback = nullptr) override;
    void closeCircuit(SubsystemType subsystem,
                     std::function<void(bool success)> callback = nullptr) override;
    CircuitBreaker::State getCircuitState(SubsystemType subsystem) const override;
    
    // Dependencies
    void registerDependency(const Dependency &dep,
                           std::function<void(bool success)> callback = nullptr) override;
    QVector<Dependency> getDependencies(SubsystemType subsystem) const override;
    bool checkDependencyHealth(SubsystemType subsystem) const override;
    QVariantMap getDependencyGraph() const override;
    
    // Initialization Sequence
    void setStartupSequence(const StartupSequence &sequence,
                           std::function<void(bool success)> callback = nullptr) override;
    StartupSequence getStartupSequence() const override;
    void executeStartupSequence(std::function<void(bool success)> callback = nullptr) override;
    
    // Shutdown Sequence
    void setShutdownSequence(const ShutdownSequence &sequence,
                            std::function<void(bool success)> callback = nullptr) override;
    ShutdownSequence getShutdownSequence() const override;
    void executeShutdownSequence(std::function<void(bool success)> callback = nullptr) override;
    
    // Resource Management
    void setResourceLimits(int maxMemory, float maxCpu,
                          std::function<void(bool success)> callback = nullptr) override;
    QVariantMap getResourceUsage() const override;
    bool checkResourceAvailability(int requiredMemory, float requiredCpu) const override;
    void optimizeResources(std::function<void(bool success)> callback = nullptr) override;
    
    // Configuration
    void setConfiguration(const IntegrationConfiguration &config,
                         std::function<void(bool success)> callback = nullptr) override;
    IntegrationConfiguration getConfiguration() const override;
    void updateConfiguration(const QString &key, const QVariant &value,
                            std::function<void(bool success)> callback = nullptr) override;
    bool validateConfiguration(const IntegrationConfiguration &config) const override;
    
    // Error Recovery
    void enableAutoRecovery(bool enable) override;
    void triggerRecovery(SubsystemType subsystem,
                        std::function<void(bool success)> callback = nullptr) override;
    QString getLastError() const override;
    QVector<QString> getErrorHistory(int limit = 100) const override;
    void clearErrorHistory(std::function<void(bool success)> callback = nullptr) override;
    
    // Statistics
    QVariantMap getStatistics() const override;
    QVariantMap getSubsystemStatistics(SubsystemType type) const override;
    QString getPerformanceReport() const override;
    
    // Testing & Diagnostics
    QString runDiagnostics() override;
    bool testSubsystem(SubsystemType type) override;
    bool testConnectivity(SubsystemType from, SubsystemType to) override;

private:
    SystemState m_state;
    HealthStatus m_health;
    
    IntegrationConfiguration m_config;
    
    QMap<SubsystemType, SubsystemHealth> m_subsystems;
    QMap<QString, Workflow> m_workflows;
    QMap<QString, WorkflowExecution> m_executions;
    
    QMap<SubsystemType, CircuitBreaker> m_circuitBreakers;
    QVector<Dependency> m_dependencies;
    
    QMap<QString, SystemMessage> m_messages;
    QMap<QString, MessageCallback> m_messageHandlers;
    
    StartupSequence m_startupSeq;
    ShutdownSequence m_shutdownSeq;
    
    SystemMetrics m_metrics;
    
    int m_maxMemory = 1000000;
    float m_maxCpu = 80.0f;
    
    QVector<QString> m_errorHistory;
    QString m_lastError;
    
    bool m_autoRecoveryEnabled = true;
    QTimer *m_healthCheckTimer = nullptr;
    
    mutable QMutex m_mutex;
    
    // Helper methods
    void updateHealth();
    void onHealthCheckTimer();
    void executeWorkflowStep(const WorkflowExecution &exec, const WorkflowStep &step);
    bool checkCircuitBreakerState(SubsystemType subsystem);
};

using DefaultIntegrationOrchestratorPtr = std::shared_ptr<DefaultIntegrationOrchestrator>;
