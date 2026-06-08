#ifndef APPROVALSTRATEGYMANAGER_H
#define APPROVALSTRATEGYMANAGER_H

#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QMap>
#include <QList>
#include <QObject>

/**
 * @class ApprovalStrategyManager
 * @brief 审批策略管理器 - 管理和编排灵活的审批策略
 * 
 * 功能：
 * - 定义多个审批策略 (Never, OnFailure, OnRequest, Granular, UnlessTrusted)
 * - 按工具/操作/风险等级配置不同的策略
 * - 支持基于条件的动态策略选择
 * - 提供策略冲突解决机制
 * - 记录和审计策略变更
 */

class ApprovalStrategyManager : public QObject
{
    Q_OBJECT

public:
    enum StrategyType {
        Never,         // 不询问，自动允许
        OnFailure,     // 失败时询问
        OnRequest,     // 每次询问
        Granular,      // 细粒度资源级控制
        UnlessTrusted  // 除非工具被信任
    };

    enum ConditionType {
        RiskLevel,     // 基于风险等级
        ToolName,      // 基于工具名称
        ActionType,    // 基于动作类型
        TimeRange,     // 基于时间范围
        UserRole       // 基于用户角色
    };

    struct ApprovalStrategy {
        QString name;
        StrategyType type;
        QString description;
        QJsonObject config;
        bool isActive;
        QString createdAt;
        QString updatedAt;
    };

    struct StrategyRule {
        ConditionType condition;
        QString value;
        StrategyType recommendedStrategy;
        int priority;  // 数值越大优先级越高
    };

    explicit ApprovalStrategyManager(QObject *parent = nullptr);
    ~ApprovalStrategyManager();

    // 策略管理
    void createStrategy(const QString &name, StrategyType type,
                       const QString &description, const QJsonObject &config);
    void updateStrategy(const QString &name, const QJsonObject &config);
    void deleteStrategy(const QString &name);
    ApprovalStrategy getStrategy(const QString &name);
    QList<ApprovalStrategy> listStrategies();

    // 策略规则管理
    void addRule(const StrategyRule &rule);
    void removeRule(const QString &ruleId);
    QList<StrategyRule> getRulesForTool(const QString &toolName);
    QList<StrategyRule> getRulesForAction(const QString &actionType);

    // 动态策略选择
    StrategyType selectStrategy(
        const QString &toolName,
        const QString &actionType,
        int riskLevel,
        const QString &userRole = "user");

    // 策略冲突解决
    StrategyType resolveConflict(
        const QList<StrategyType> &conflictingStrategies);

    // 策略评估
    bool evaluateStrategy(
        StrategyType strategy,
        int riskLevel,
        const QString &approvalHistory);

    // 性能监控
    QJsonObject getStrategyStats(const QString &strategyName);
    QJsonArray getApprovalMetrics();

    // 导入/导出
    QJsonObject exportPolicies();
    void importPolicies(const QJsonObject &policies);

    // 重置为默认策略
    void resetToDefaults();

signals:
    void strategyCreated(const QString &name);
    void strategyUpdated(const QString &name);
    void strategyDeleted(const QString &name);
    void ruleAdded();
    void ruleRemoved();

private:
    QMap<QString, ApprovalStrategy> m_strategies;
    QList<StrategyRule> m_rules;

    // 性能统计
    struct StrategyStats {
        QString strategyName;
        int totalApprovals;
        int totalRejections;
        int totalReviews;
        double averageApprovalTime;
        double successRate;
    };

    QMap<QString, StrategyStats> m_stats;

    void initializeDefaultStrategies();
    int calculatePriority(const StrategyRule &rule, int ruleCount);
};

#endif // APPROVALSTRATEGYMANAGER_H
