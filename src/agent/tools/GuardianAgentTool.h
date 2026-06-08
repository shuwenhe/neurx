#ifndef GUARDIANAGENTTOOL_H
#define GUARDIANAGENTTOOL_H

#include "agent/AgentToolRegistry.h"
#include "agent/runtime/RiskAssessor.h"
#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QMap>
#include <QList>

/**
 * @class GuardianAgentTool
 * @brief 自动审批决策Agent - 用于自动化风险评估和审批决策
 * 
 * Guardian Agent是一个专门的子Agent，用于：
 * 1. 接收工具操作请求
 * 2. 调用RiskAssessor进行风险评估
 * 3. 基于审批策略做出自动决策
 * 4. 返回审批结果（批准/拒绝/需要人工审核）
 * 
 * 审批决策逻辑：
 * - CRITICAL风险：自动拒绝，需要人工决策
 * - HIGH风险：根据审批策略判断
 * - MEDIUM风险：按策略判断
 * - LOW/MINIMAL风险：自动批准（除非策略要求）
 */

class GuardianAgentTool : public BaseTool
{
    Q_OBJECT

public:
    enum ApprovalDecision {
        APPROVED,          // 自动批准
        REJECTED,          // 自动拒绝
        REQUIRES_REVIEW    // 需要人工审核
    };

    explicit GuardianAgentTool(QObject *parent = nullptr);
    ~GuardianAgentTool() override;

    // BaseTool接口实现
    QString name() const override { return "GuardianAgent"; }
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

    // 审批相关方法
    ApprovalDecision assessOperation(
        const QString &toolName,
        const QString &action,
        const QJsonObject &params,
        const QString &approvalPolicy,
        QJsonObject &decisionDetails);

    // 设置审批策略
    void setApprovalPolicy(const QString &toolName, const QString &policy);
    QString getApprovalPolicy(const QString &toolName);

    // 获取信任的工具列表
    QStringList getTrustedTools() const;
    void addTrustedTool(const QString &toolName);
    void removeTrustedTool(const QString &toolName);

    // 获取黑名单工具
    QStringList getBlacklistedTools() const;
    void addBlacklistedTool(const QString &toolName);
    void removeBlacklistedTool(const QString &toolName);

    // 生成审批报告
    QJsonObject generateApprovalReport(
        const QString &toolName,
        const QString &action,
        const QJsonObject &params,
        ApprovalDecision decision);

signals:
    void approvalRequired(const QJsonObject &request);  // 需要人工审核
    void operationApproved(const QString &toolName);    // 操作被批准
    void operationRejected(const QString &toolName);    // 操作被拒绝

private:
    // 私有审批逻辑
    ApprovalDecision evaluateRiskDecision(
        RiskAssessor::RiskLevel maxRisk,
        const QString &approvalPolicy);

    ApprovalDecision evaluateTrustDecision(
        const QString &toolName,
        RiskAssessor::RiskLevel maxRisk);

    // 工具操作的审批历史
    struct ApprovalRecord {
        QString toolName;
        QString action;
        ApprovalDecision decision;
        QString timestamp;
        QString reason;
        QJsonObject riskReport;
    };

    // 维护审批记录用于学习
    QList<ApprovalRecord> m_approvalHistory;

    // 持久化设置
    QMap<QString, QString> m_approvalPolicies;
    QStringList m_trustedTools;
    QStringList m_blacklistedTools;

    // 风险评估器实例
    RiskAssessor m_riskAssessor;

    // 配置常量
    static constexpr const char *DEFAULT_POLICY = "Granular";
    static constexpr int MAX_HISTORY_RECORDS = 1000;

    // 私有方法
    QString getCurrentTimestamp() const;
    void recordApprovalDecision(const ApprovalRecord &record);
    void trimApprovalHistory();
};

#endif // GUARDIANAGENTTOOL_H
