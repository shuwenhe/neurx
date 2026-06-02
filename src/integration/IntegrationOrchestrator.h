#pragma once

#include "IntegrationTypes.h"
#include <QObject>
#include <memory>

/**
 * @class IntegrationOrchestrator
 * @brief Central orchestration for all agent subsystems
 * 
 * Handles:
 * - System initialization and shutdown
 * - Subsystem health monitoring
 * - Workflow execution
 * - Message routing
 * - Resource management
 * - Error recovery
 */
class IntegrationOrchestrator : public QObject {
    Q_OBJECT
public:
    virtual ~IntegrationOrchestrator() = default;
    
    // ── System Lifecycle ────────────────────────────────
    
    /// Initialize the system
    virtual void initialize(const IntegrationConfiguration &config,
                           std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Shutdown the system
    virtual void shutdown(bool graceful = true,
                         std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Start the system
    virtual void start(std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Stop the system
    virtual void stop(std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Pause the system
    virtual void pause(std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Resume the system
    virtual void resume(std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Restart the system
    virtual void restart(std::function<void(bool success)> callback = nullptr) = 0;
    
    // ── State Management ────────────────────────────────
    
    /// Get current system state
    virtual SystemState getSystemState() const = 0;
    
    /// Get current health status
    virtual HealthStatus getHealthStatus() const = 0;
    
    /// Get system metrics
    virtual SystemMetrics getSystemMetrics() const = 0;
    
    /// Set state (internal)
    virtual void setState(SystemState state,
                         StateChangeCallback callback = nullptr) = 0;
    
    // ── Subsystem Management ────────────────────────────
    
    /// Register subsystem
    virtual void registerSubsystem(SubsystemType type, const QString &name,
                                  std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Unregister subsystem
    virtual void unregisterSubsystem(SubsystemType type,
                                    std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Enable subsystem
    virtual void enableSubsystem(SubsystemType type,
                                std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Disable subsystem
    virtual void disableSubsystem(SubsystemType type,
                                 std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get subsystem health
    virtual SubsystemHealth getSubsystemHealth(SubsystemType type) const = 0;
    
    /// Get all subsystems health
    virtual QVector<SubsystemHealth> getAllSubsystemHealth() const = 0;
    
    /// Check subsystem availability
    virtual bool isSubsystemAvailable(SubsystemType type) const = 0;
    
    /// Restart subsystem
    virtual void restartSubsystem(SubsystemType type,
                                 std::function<void(bool success)> callback = nullptr) = 0;
    
    // ── Health Monitoring ───────────────────────────────
    
    /// Start health check
    virtual void startHealthChecking(int intervalMs = 5000) = 0;
    
    /// Stop health check
    virtual void stopHealthChecking() = 0;
    
    /// Perform health check
    virtual SystemMetrics performHealthCheck() = 0;
    
    /// Check subsystem health
    virtual bool checkSubsystemHealth(SubsystemType type) = 0;
    
    /// Get health report
    virtual QString getHealthReport() const = 0;
    
    // ── Workflow Execution ──────────────────────────────
    
    /// Define workflow
    virtual void defineWorkflow(const Workflow &workflow,
                               std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Execute workflow
    virtual QString executeWorkflow(const QString &workflowId,
                                   const RequestContext &context,
                                   WorkflowCallback callback = nullptr) = 0;
    
    /// Get workflow execution
    virtual WorkflowExecution getWorkflowExecution(const QString &executionId) const = 0;
    
    /// Cancel workflow execution
    virtual void cancelWorkflowExecution(const QString &executionId,
                                        std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get workflow
    virtual Workflow getWorkflow(const QString &workflowId) const = 0;
    
    /// List workflows
    virtual QVector<Workflow> listWorkflows() const = 0;
    
    /// Delete workflow
    virtual void deleteWorkflow(const QString &workflowId,
                               std::function<void(bool success)> callback = nullptr) = 0;
    
    // ── Message Routing ────────────────────────────────
    
    /// Send message
    virtual QString sendMessage(const SystemMessage &message,
                               MessageCallback callback = nullptr) = 0;
    
    /// Broadcast message
    virtual void broadcastMessage(const SystemMessage &message,
                                 SubsystemType excludeSubsystem = SubsystemType::Custom) = 0;
    
    /// Register message handler
    virtual void registerMessageHandler(const QString &messageType,
                                       MessageCallback handler) = 0;
    
    /// Get message
    virtual SystemMessage getMessage(const QString &messageId) const = 0;
    
    /// Get pending messages
    virtual QVector<SystemMessage> getPendingMessages(SubsystemType subsystem) const = 0;
    
    // ── Circuit Breaker ────────────────────────────────
    
    /// Get circuit breaker for subsystem
    virtual CircuitBreaker getCircuitBreaker(SubsystemType subsystem) const = 0;
    
    /// Open circuit
    virtual void openCircuit(SubsystemType subsystem,
                            std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Close circuit
    virtual void closeCircuit(SubsystemType subsystem,
                             std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get circuit breaker state
    virtual CircuitBreaker::State getCircuitState(SubsystemType subsystem) const = 0;
    
    // ── Dependencies ────────────────────────────────────
    
    /// Register dependency
    virtual void registerDependency(const Dependency &dep,
                                   std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get dependencies
    virtual QVector<Dependency> getDependencies(SubsystemType subsystem) const = 0;
    
    /// Check dependency health
    virtual bool checkDependencyHealth(SubsystemType subsystem) const = 0;
    
    /// Get dependency graph
    virtual QVariantMap getDependencyGraph() const = 0;
    
    // ── Initialization Sequence ────────────────────────
    
    /// Set startup sequence
    virtual void setStartupSequence(const StartupSequence &sequence,
                                   std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get startup sequence
    virtual StartupSequence getStartupSequence() const = 0;
    
    /// Execute startup sequence
    virtual void executeStartupSequence(std::function<void(bool success)> callback = nullptr) = 0;
    
    // ── Shutdown Sequence ───────────────────────────────
    
    /// Set shutdown sequence
    virtual void setShutdownSequence(const ShutdownSequence &sequence,
                                    std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get shutdown sequence
    virtual ShutdownSequence getShutdownSequence() const = 0;
    
    /// Execute shutdown sequence
    virtual void executeShutdownSequence(std::function<void(bool success)> callback = nullptr) = 0;
    
    // ── Resource Management ────────────────────────────
    
    /// Set resource limits
    virtual void setResourceLimits(int maxMemory, float maxCpu,
                                  std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get resource usage
    virtual QVariantMap getResourceUsage() const = 0;
    
    /// Check resource availability
    virtual bool checkResourceAvailability(int requiredMemory, float requiredCpu) const = 0;
    
    /// Optimize resources
    virtual void optimizeResources(std::function<void(bool success)> callback = nullptr) = 0;
    
    // ── Configuration ───────────────────────────────────
    
    /// Set configuration
    virtual void setConfiguration(const IntegrationConfiguration &config,
                                 std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get configuration
    virtual IntegrationConfiguration getConfiguration() const = 0;
    
    /// Update configuration
    virtual void updateConfiguration(const QString &key, const QVariant &value,
                                    std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Validate configuration
    virtual bool validateConfiguration(const IntegrationConfiguration &config) const = 0;
    
    // ── Error Recovery ──────────────────────────────────
    
    /// Enable auto-recovery
    virtual void enableAutoRecovery(bool enable) = 0;
    
    /// Trigger recovery
    virtual void triggerRecovery(SubsystemType subsystem,
                                std::function<void(bool success)> callback = nullptr) = 0;
    
    /// Get last error
    virtual QString getLastError() const = 0;
    
    /// Get error history
    virtual QVector<QString> getErrorHistory(int limit = 100) const = 0;
    
    /// Clear error history
    virtual void clearErrorHistory(std::function<void(bool success)> callback = nullptr) = 0;
    
    // ── Statistics ───────────────────────────────────────
    
    /// Get statistics
    virtual QVariantMap getStatistics() const = 0;
    
    /// Get subsystem statistics
    virtual QVariantMap getSubsystemStatistics(SubsystemType type) const = 0;
    
    /// Get performance report
    virtual QString getPerformanceReport() const = 0;
    
    // ── Testing & Diagnostics ──────────────────────────
    
    /// Run diagnostics
    virtual QString runDiagnostics() = 0;
    
    /// Test subsystem
    virtual bool testSubsystem(SubsystemType type) = 0;
    
    /// Test connectivity
    virtual bool testConnectivity(SubsystemType from, SubsystemType to) = 0;

signals:
    /// System state changed
    void systemStateChanged(SystemState oldState, SystemState newState);
    
    /// Health status changed
    void healthStatusChanged(HealthStatus status);
    
    /// Subsystem health changed
    void subsystemHealthChanged(const SubsystemHealth &health);
    
    /// Workflow started
    void workflowStarted(const QString &executionId);
    
    /// Workflow completed
    void workflowCompleted(const WorkflowExecution &execution);
    
    /// Workflow failed
    void workflowFailed(const QString &executionId, const QString &error);
    
    /// Message received
    void messageReceived(const SystemMessage &message);
    
    /// Error occurred
    void errorOccurred(int errorCode, const QString &message);
    
    /// Circuit opened
    void circuitOpened(SubsystemType subsystem);
    
    /// Circuit closed
    void circuitClosed(SubsystemType subsystem);
};

using IntegrationOrchestratorPtr = std::shared_ptr<IntegrationOrchestrator>;
