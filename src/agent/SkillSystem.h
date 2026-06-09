#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <memory>
#include <map>

/**
 * @class SkillSystem
 * @brief Manages and executes skills with context-aware selection
 * 
 * Features:
 * - Skill registration and lifecycle
 * - Context-aware skill selection
 * - Skill dependency resolution
 * - Performance tracking
 * - Skill marketplace integration
 * - Tagging and categorization
 * - Auto-invocation based on task type
 */

class SkillSystem : public QObject {
    Q_OBJECT

public:
    enum SkillType {
        UtilitySkill,
        DomainSkill,
        DesignSkill,
        OptimizationSkill,
        ValidationSkill,
        DocumentationSkill
    };

    struct SkillDefinition {
        QString id;
        QString name;
        QString description;
        SkillType type;
        QStringList applicableTasks;
        QStringList requiredLanguages;
        QStringList tags;
        int priority;
        bool autoInvoke;
        float successRate;
        QStringList dependencies;
        QJsonObject metadata;
        bool enabled;
    };

    struct SkillExecutionContext {
        QString currentFile;
        QString currentLanguage;
        QString taskType;
        QStringList selectedCode;
        QJsonObject userContext;
        QStringList recentCommands;
    };

    struct SkillResult {
        QString skillId;
        bool success;
        QString output;
        QStringList suggestions;
        float relevanceScore;
        int executionTimeMs;
        QJsonObject metadata;
    };

    explicit SkillSystem(QObject* parent = nullptr);
    ~SkillSystem();

    // Skill management
    void registerSkill(const SkillDefinition& skill);
    void unregisterSkill(const QString& skillId);
    void updateSkill(const QString& skillId, const SkillDefinition& newDef);
    SkillDefinition getSkill(const QString& skillId);
    QVector<SkillDefinition> getAllSkills();
    QVector<SkillDefinition> getSkillsByType(SkillType type);

    // Skill execution
    SkillResult executeSkill(const QString& skillId, const SkillExecutionContext& context);
    QVector<SkillResult> executeApplicableSkills(const SkillExecutionContext& context);
    QVector<SkillResult> executeSkillsOfType(SkillType type, const SkillExecutionContext& context);

    // Context-aware selection
    QVector<SkillDefinition> selectSkillsForTask(const QString& taskType);
    QVector<SkillDefinition> selectSkillsForLanguage(const QString& language);
    QVector<SkillDefinition> selectSkillsByTag(const QString& tag);
    QVector<SkillDefinition> suggestSkillsForCode(const QString& code);

    // Auto-invocation
    void enableAutoInvocation(bool enabled);
    void setAutoInvokeThreshold(float threshold);
    QVector<SkillDefinition> getAutoInvokeSkills();

    // Skill configuration
    void enableSkill(const QString& skillId, bool enabled);
    void setSkillPriority(const QString& skillId, int priority);
    void configureSkillForTask(const QString& skillId, const QString& taskType);
    void setSkillDependencies(const QString& skillId, const QStringList& dependencies);

    // Dependency resolution
    QStringList resolveDependencies(const QString& skillId);
    bool checkDependencies(const QString& skillId);
    QStringList getMissingDependencies(const QString& skillId);

    // Performance tracking
    struct SkillPerformance {
        float successRate;
        float averageExecutionTimeMs;
        int timesExecuted;
        int successfulExecutions;
        float averageRelevanceScore;
    };
    SkillPerformance getSkillPerformance(const QString& skillId);
    QJsonObject getPerformanceReport();

    // Skill marketplace
    void publishSkillToMarketplace(const SkillDefinition& skill);
    void importSkillFromMarketplace(const QString& skillId);
    QVector<SkillDefinition> searchMarketplace(const QString& query);
    QJsonArray getMarketplaceSkills();

    // Batch operations
    QVector<SkillResult> executeBatchSkills(const QStringList& skillIds, const SkillExecutionContext& context);
    void parallelExecuteSkills(const QStringList& skillIds, const SkillExecutionContext& context);

    // Result aggregation
    struct AggregatedResults {
        int totalSkillsExecuted;
        int successfulSkills;
        float overallSuccessRate;
        QVector<SkillResult> results;
        QStringList combinedSuggestions;
    };
    AggregatedResults aggregateResults(const QVector<SkillResult>& results);

    // Skill chaining
    void chainSkills(const QStringList& skillIds);
    QVector<SkillResult> executeSkillChain(const SkillExecutionContext& context);

    // Tagging and categorization
    void addTagToSkill(const QString& skillId, const QString& tag);
    void removeTagFromSkill(const QString& skillId, const QString& tag);
    QStringList getSkillTags(const QString& skillId);
    QVector<SkillDefinition> getSkillsByTag(const QString& tag);

    // Statistics
    struct SkillStats {
        int totalSkills;
        int enabledSkills;
        int disabledSkills;
        QMap<SkillType, int> skillsByType;
        float averageSuccessRate;
        int totalExecutions;
    };
    SkillStats getStatistics() const;

    // Export/Import
    QJsonObject exportSkill(const QString& skillId);
    bool importSkillFromJson(const QJsonObject& skillJson);
    void exportAllSkills(const QString& filepath);
    void importSkillsFromFile(const QString& filepath);

signals:
    void skillRegistered(const QString& skillId);
    void skillUnregistered(const QString& skillId);
    void skillExecuted(const QString& skillId, bool success);
    void skillResultReceived(const SkillResult& result);

private:
    QMap<QString, SkillDefinition> m_skills;
    QMap<QString, SkillPerformance> m_performance;
    QStringList m_skillChain;
    bool m_autoInvokeEnabled;
    float m_autoInvokeThreshold;
    SkillStats m_statistics;

    float calculateRelevanceScore(const SkillDefinition& skill, const SkillExecutionContext& context);
};
