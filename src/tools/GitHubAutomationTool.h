#pragma once

#include "agent/AgentToolRegistry.h"
#include <QString>
#include <QStringList>
#include <QJsonObject>

/**
 * @class GitHubAutomationTool
 * @brief GitHub 自动化工具
 * 
 * 功能：
 * - 自动检测和关闭过期 issue
 * - 检测重复 issue 并关闭
 * - 自动标签管理
 * - PR 自动合并条件检查
 * - 分支清理
 * - Issue 模板应用
 * 
 * 使用示例：
 * {
 *   "tool": "github_automation",
 *   "action": "detect_stale_issues",
 *   "repository": "owner/repo",
 *   "stale_days": 30
 * }
 */
class GitHubAutomationTool : public BaseTool {
public:
    explicit GitHubAutomationTool(QObject *parent = nullptr);
    ~GitHubAutomationTool() override;

    // ── BaseTool 接口实现 ───────────────────────────────────────────────────
    
    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

private:
    // ── GitHub 自动化操作 ────────────────────────────────────────────────────
    
    /**
     * @brief 检测过期的 issue（无活动超过 N 天）
     */
    QJsonArray detectStaleIssues(const QString &repository, int staleDays = 30);
    
    /**
     * @brief 检测重复的 issue
     */
    QJsonArray detectDuplicateIssues(const QString &repository);
    
    /**
     * @brief 自动应用标签
     */
    QJsonObject applyLabels(const QString &repository, const QJsonObject &labelRules);
    
    /**
     * @brief 检查 PR 合并条件
     */
    QJsonObject checkMergeConditions(const QString &repository, const QString &prNumber);
    
    /**
     * @brief 清理过期分支
     */
    QJsonArray cleanupBranches(const QString &repository, int daysOld = 7);
    
    /**
     * @brief 生成 GitHub 报告
     */
    QString generateGitHubReport(const QJsonArray &items);
};
