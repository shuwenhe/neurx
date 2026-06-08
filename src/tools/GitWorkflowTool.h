#pragma once

#include "agent/AgentToolRegistry.h"
#include <QString>
#include <QStringList>

/**
 * @class GitWorkflowTool
 * @brief Git 工作流自动化工具
 * 
 * 实现 claude-code commit-commands 插件的功能：
 * - AI 生成 commit message（分析 diff）
 * - 一键 commit + push + PR
 * - 敏感文件检测
 * - 提交前安全扫描
 * 
 * 使用示例：
 * {
 *   "tool": "git_workflow",
 *   "action": "generate_commit_message"
 * }
 * 
 * {
 *   "tool": "git_workflow",
 *   "action": "commit_push_pr",
 *   "commit_message": "feat: Add HookManager",
 *   "pr_title": "Feature: Extensible Hook System",
 *   "pr_body": "Implements 9 Hook types..."
 * }
 */
class GitWorkflowTool : public BaseTool {
public:
    explicit GitWorkflowTool(QObject *parent = nullptr);
    ~GitWorkflowTool() override;

    // ── BaseTool 接口实现 ───────────────────────────────────────────────────
    
    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;

private:
    // ── Git 操作 ────────────────────────────────────────────────────────────
    
    /**
     * @brief 获取 git diff（未暂存的更改）
     */
    QString getGitDiff();
    
    /**
     * @brief 获取暂存区的 diff
     */
    QString getStagedDiff();
    
    /**
     * @brief 获取最近的 commit 信息
     */
    QStringList getRecentCommits(int count = 5);
    
    /**
     * @brief 执行 git 命令
     */
    QString runGitCommand(const QStringList& args, bool* success = nullptr);

    // ── AI 功能 ─────────────────────────────────────────────────────────────
    
    /**
     * @brief 生成 commit message（使用 LLM 分析 diff）
     * @return 生成的 commit message
     */
    QString generateCommitMessage();
    
    /**
     * @brief 生成 PR 标题和正文
     */
    struct PRContent {
        QString title;
        QString body;
    };
    PRContent generatePRContent(const QString& commitMessages);

    // ── 安全检查 ────────────────────────────────────────────────────────────
    
    /**
     * @brief 检查是否包含敏感文件
     */
    bool hasSensitiveFiles(const QStringList& files);
    
    /**
     * @brief 获取敏感文件列表
     */
    QStringList findSensitiveFiles(const QStringList& files);
    
    /**
     * @brief 检查是否包含密钥等敏感信息
     */
    bool hasSecrets(const QString& diff);

    // ── 工作流操作 ──────────────────────────────────────────────────────────
    
    /**
     * @brief 自动提交
     */
    ToolResult actionAutoCommit(const QJsonObject& args);
    
    /**
     * @brief 提交 + 推送
     */
    ToolResult actionCommitAndPush(const QJsonObject& args);
    
    /**
     * @brief 提交 + 推送 + 创建 PR
     */
    ToolResult actionCommitPushPR(const QJsonObject& args);
    
    /**
     * @brief 生成 commit message
     */
    ToolResult actionGenerateCommitMessage(const QJsonObject& args);
    
    /**
     * @brief 生成 PR 内容
     */
    ToolResult actionGeneratePRContent(const QJsonObject& args);
    
    /**
     * @brief 检查敏感文件
     */
    ToolResult actionCheckSensitiveFiles(const QJsonObject& args);

    // ── 辅助方法 ────────────────────────────────────────────────────────────
    
    /**
     * @brief 格式化 commit message（遵循 Conventional Commits）
     */
    QString formatCommitMessage(const QString& message);
    
    /**
     * @brief 验证 commit message 格式
     */
    bool isValidCommitMessage(const QString& message);
    
    /**
     * @brief 获取当前分支名
     */
    QString getCurrentBranch();
    
    /**
     * @brief 获取远程仓库 URL
     */
    QString getRemoteUrl();
    
    /**
     * @brief 解析 GitHub 仓库信息
     */
    struct RepoInfo {
        QString owner;
        QString repo;
        bool valid;
    };
    RepoInfo parseGitHubRepo(const QString& url);

    // ── 数据成员 ────────────────────────────────────────────────────────────
    
    QStringList m_sensitivePatterns;  ///< 敏感文件模式
    QStringList m_sensitiveExtensions;///< 敏感文件扩展名
};
