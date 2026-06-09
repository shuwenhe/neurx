#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <memory>

/**
 * @class FeatureDevelopmentWorkflow
 * @brief Structured 7-phase feature development workflow
 * 
 * Features:
 * - Phase-based workflow (discovery, design, implementation, etc.)
 * - Checkpoint tracking
 * - Continuous architectural validation
 * - Integration readiness checks
 * - Deployment planning
 * - Rollback planning
 * - Quality gates at each phase
 */

class FeatureDevelopmentWorkflow : public QObject {
    Q_OBJECT

public:
    enum Phase {
        Discovery,      // Phase 1: Requirements gathering
        Design,         // Phase 2: Architecture and design
        Implementation, // Phase 3: Code implementation
        Testing,        // Phase 4: Unit and integration tests
        Integration,    // Phase 5: System integration
        Review,         // Phase 6: Code review and compliance
        Deployment      // Phase 7: Release and deployment
    };

    enum QualityGateStatus {
        NotStarted,
        InProgress,
        Passed,
        WarningsPassed,
        WarningsFailed,
        Failed,
        Blocked
    };

    struct PhaseCheckpoint {
        Phase phase;
        QString id;
        qint64 startTime;
        qint64 endTime;
        QualityGateStatus gateStatus;
        QString description;
        QStringList deliverables;
        QJsonObject metadata;
        bool blocked;
        QStringList blockingIssues;
    };

    struct FeatureSpec {
        QString featureId;
        QString name;
        QString description;
        QString owner;
        QString targetBranch;
        QStringList acceptanceCriteria;
        QStringList dependsOn;  // Other feature IDs
        int estimatedStoryPoints;
        QString priority;  // "critical", "high", "medium", "low"
        qint64 deadline;
        QJsonObject specifications;
    };

    struct WorkflowState {
        QString featureId;
        Phase currentPhase;
        QVector<PhaseCheckpoint> completedPhases;
        QVector<PhaseCheckpoint> currentCheckpoint;
        float progressPercentage;
        QStringList blockers;
        QJsonObject phaseData;
    };

    struct DeploymentPlan {
        QString featureId;
        QString releaseVersion;
        QStringList affectedServices;
        QString rollbackProcedure;
        QString monitoringPlan;
        QString communicationPlan;
        bool requiresDataMigration;
        QString dataMigrationScript;
        QStringList postDeploymentTests;
        bool requiresFeatureFlag;
        QString featureFlagKey;
    };

    explicit FeatureDevelopmentWorkflow(QObject* parent = nullptr);
    ~FeatureDevelopmentWorkflow();

    // Workflow management
    WorkflowState startFeatureDevelopment(const FeatureSpec& spec);
    WorkflowState getWorkflowState(const QString& featureId);
    bool advancePhase(const QString& featureId);
    bool regressPhase(const QString& featureId);
    void pauseWorkflow(const QString& featureId);
    void resumeWorkflow(const QString& featureId);

    // Phase-specific operations
    // Phase 1: Discovery
    QStringList conductDiscovery(const FeatureSpec& spec);
    QString generateRequirementsDocument(const FeatureSpec& spec);
    QJsonArray identifyStakeholders(const QString& featureId);
    QStringList defineAcceptanceCriteria(const QString& featureId);

    // Phase 2: Design
    QString generateArchitectureDesign(const FeatureSpec& spec);
    QJsonObject designDatabase(const QString& featureId);
    QStringList identifyIntegrationPoints(const QString& featureId);
    QString generateAPISpecification(const QString& featureId);
    bool validateArchitecturalDecisions(const QString& featureId);

    // Phase 3: Implementation
    QStringList generateProjectStructure(const FeatureSpec& spec);
    QString generateImplementationChecklist(const QString& featureId);
    bool validateImplementationProgress(const QString& featureId);
    QStringList identifyMissingImplementations(const QString& featureId);

    // Phase 4: Testing
    QString generateTestPlan(const QString& featureId);
    QStringList generateTestCases(const QString& featureId);
    bool validateTestCoverage(const QString& featureId, float minimumCoverage = 80.0);
    QJsonObject runQualityChecks(const QString& featureId);
    bool validatePerformance(const QString& featureId);

    // Phase 5: Integration
    bool validateIntegrationReadiness(const QString& featureId);
    QString generateIntegrationReport(const QString& featureId);
    QStringList checkDependencies(const QString& featureId);
    bool resolveConflicts(const QString& featureId);

    // Phase 6: Review
    QJsonObject conductCodeReview(const QString& featureId);
    bool validateCompliance(const QString& featureId);
    QStringList getReviewFeedback(const QString& featureId);
    bool addressReviewComments(const QString& featureId);

    // Phase 7: Deployment
    DeploymentPlan createDeploymentPlan(const QString& featureId);
    bool validateDeploymentReadiness(const QString& featureId);
    QString generateRollbackPlan(const QString& featureId);
    bool validateMonitoring(const QString& featureId);
    QString generateCommunicationPlan(const QString& featureId);

    // Quality gates
    QualityGateStatus checkPhaseQualityGate(const QString& featureId);
    QJsonObject getQualityGateMetrics(const QString& featureId);
    bool canAdvancePhase(const QString& featureId);
    QString getQualityGateBlockReason(const QString& featureId);

    // Checkpoint management
    PhaseCheckpoint createPhaseCheckpoint(const QString& featureId, Phase phase);
    PhaseCheckpoint getPhaseCheckpoint(const QString& featureId, Phase phase);
    bool approvePhaseCheckpoint(const QString& featureId, Phase phase);
    bool requestPhaseCheckpointChanges(const QString& featureId, Phase phase,
                                       const QString& reason);

    // Blocker management
    bool addBlocker(const QString& featureId, const QString& issue);
    bool resolveBlocker(const QString& featureId, const QString& issue);
    QStringList getBlockers(const QString& featureId);
    bool isBlockedOnFeature(const QString& featureId);

    // Dependency management
    QStringList resolveDependencies(const QString& featureId);
    bool checkAllDependenciesComplete(const QString& featureId);
    QString getDependencyStatus(const QString& featureId);

    // Reporting
    QString generatePhaseReport(const QString& featureId);
    QString generateProgressReport(const QString& featureId);
    QString generateComplianceReport(const QString& featureId);
    QString generateHealthDashboard();

    // Metrics and tracking
    struct WorkflowMetrics {
        int totalFeaturesInProgress;
        int completedFeatures;
        QMap<Phase, int> featuresByPhase;
        float averageTimePerPhase;
        float overallProgressPercentage;
        int blockedFeatures;
        QMap<QString, int> blockersCount;
    };
    WorkflowMetrics getMetrics() const;

    // History
    QVector<WorkflowState> getFeatureHistory(const QString& featureId);
    QVector<WorkflowState> getActiveFeatures();
    QVector<WorkflowState> getCompletedFeatures();

    // Configuration
    void setPhaseTimeout(Phase phase, int timeoutMinutes);
    void setQualityGateThresholds(Phase phase, const QJsonObject& thresholds);
    void enablePhaseAutoAdvance(bool enabled);
    void setApprovalRequired(Phase phase, bool required);

signals:
    void phaseStarted(const QString& featureId, Phase phase);
    void phaseCompleted(const QString& featureId, Phase phase);
    void qualityGateFailure(const QString& featureId, Phase phase);
    void blockerAdded(const QString& featureId, const QString& issue);
    void blockerResolved(const QString& featureId, const QString& issue);
    void workflowCompleted(const QString& featureId);

private:
    struct FeatureWorkflow {
        WorkflowState state;
        QVector<PhaseCheckpoint> checkpoints;
        QStringList blockers;
        DeploymentPlan deploymentPlan;
    };

    QMap<QString, FeatureWorkflow> m_workflows;
    QMap<Phase, int> m_phaseTimeouts;
    QMap<Phase, QJsonObject> m_qualityThresholds;
    bool m_autoAdvance;
    QMap<Phase, bool> m_approvalRequired;
    WorkflowMetrics m_metrics;

    bool validatePhaseReadiness(const QString& featureId, Phase phase);
    QString generateUniqueCheckpointId();
};
