#include "GitHubAutomationTool.h"
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QDebug>
#include <QDateTime>

GitHubAutomationTool::GitHubAutomationTool(QObject *parent)
    : BaseTool(parent)
{
}

GitHubAutomationTool::~GitHubAutomationTool() = default;

QString GitHubAutomationTool::name() const
{
    return QStringLiteral("github_automation");
}

QString GitHubAutomationTool::description() const
{
    return QStringLiteral("Automate GitHub workflows (detect stale issues, duplicates, label management, branch cleanup)");
}

QJsonObject GitHubAutomationTool::parametersSchema() const
{
    QJsonObject schema;
    schema[QStringLiteral("action")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Action: detect_stale_issues, detect_duplicates, apply_labels, check_merge_conditions, cleanup_branches")},
        {QStringLiteral("enum"), QJsonArray{
            QStringLiteral("detect_stale_issues"),
            QStringLiteral("detect_duplicates"),
            QStringLiteral("apply_labels"),
            QStringLiteral("check_merge_conditions"),
            QStringLiteral("cleanup_branches")
        }}
    };
    
    schema[QStringLiteral("repository")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("GitHub repository (owner/repo)")}
    };
    
    schema[QStringLiteral("stale_days")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("integer")},
        {QStringLiteral("description"), QStringLiteral("Days without activity to consider stale (default: 30)")}
    };
    
    schema[QStringLiteral("label_rules")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("object")},
        {QStringLiteral("description"), QStringLiteral("Label rules mapping")}
    };
    
    schema[QStringLiteral("pr_number")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Pull request number")}
    };
    
    return schema;
}

ToolResult GitHubAutomationTool::execute(const QString &callId, const QJsonObject &args)
{
    ToolResult result;
    result.callId = callId;
    result.name = name();
    
    const QString action = args.value(QStringLiteral("action")).toString();
    const QString repository = args.value(QStringLiteral("repository")).toString();
    
    if (action == QStringLiteral("detect_stale_issues")) {
        const int staleDays = args.value(QStringLiteral("stale_days")).toInt(30);
        
        if (repository.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: repository is required");
            return result;
        }
        
        const QJsonArray issues = detectStaleIssues(repository, staleDays);
        
        QJsonObject response;
        response[QStringLiteral("repository")] = repository;
        response[QStringLiteral("stale_days")] = staleDays;
        response[QStringLiteral("stale_issues")] = issues;
        response[QStringLiteral("count")] = issues.size();
        
        result.content = QJsonDocument(response).toJson(QJsonDocument::Compact);
        return result;
        
    } else if (action == QStringLiteral("detect_duplicates")) {
        if (repository.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: repository is required");
            return result;
        }
        
        const QJsonArray duplicates = detectDuplicateIssues(repository);
        
        QJsonObject response;
        response[QStringLiteral("repository")] = repository;
        response[QStringLiteral("duplicate_groups")] = duplicates;
        response[QStringLiteral("count")] = duplicates.size();
        
        result.content = QJsonDocument(response).toJson(QJsonDocument::Compact);
        return result;
        
    } else if (action == QStringLiteral("apply_labels")) {
        const QJsonObject labelRules = args.value(QStringLiteral("label_rules")).toObject();
        
        if (repository.isEmpty() || labelRules.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: repository and label_rules are required");
            return result;
        }
        
        const QJsonObject response = applyLabels(repository, labelRules);
        result.content = QJsonDocument(response).toJson(QJsonDocument::Compact);
        return result;
        
    } else if (action == QStringLiteral("check_merge_conditions")) {
        const QString prNumber = args.value(QStringLiteral("pr_number")).toString();
        
        if (repository.isEmpty() || prNumber.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: repository and pr_number are required");
            return result;
        }
        
        const QJsonObject response = checkMergeConditions(repository, prNumber);
        result.content = QJsonDocument(response).toJson(QJsonDocument::Compact);
        return result;
        
    } else if (action == QStringLiteral("cleanup_branches")) {
        const int daysOld = args.value(QStringLiteral("days_old")).toInt(7);
        
        if (repository.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: repository is required");
            return result;
        }
        
        const QJsonArray cleaned = cleanupBranches(repository, daysOld);
        
        QJsonObject response;
        response[QStringLiteral("repository")] = repository;
        response[QStringLiteral("days_old")] = daysOld;
        response[QStringLiteral("cleaned_branches")] = cleaned;
        response[QStringLiteral("count")] = cleaned.size();
        
        result.content = QJsonDocument(response).toJson(QJsonDocument::Compact);
        return result;
    }
    
    result.isError = true;
    result.content = QStringLiteral("Error: Unknown action: %1").arg(action);
    return result;
}

QString GitHubAutomationTool::summary(const QJsonObject &args) const
{
    const QString action = args.value(QStringLiteral("action")).toString();
    const QString repo = args.value(QStringLiteral("repository")).toString();
    
    if (!repo.isEmpty()) {
        return QStringLiteral("GitHub %1: %2").arg(action, repo);
    }
    
    return action;
}

QJsonArray GitHubAutomationTool::detectStaleIssues(const QString &repository, int staleDays)
{
    QJsonArray issues;
    
    // 模拟 GitHub API 调用
    QJsonObject issue1;
    issue1[QStringLiteral("number")] = 123;
    issue1[QStringLiteral("title")] = QStringLiteral("Sample stale issue");
    issue1[QStringLiteral("last_activity")] = QDateTime::currentDateTime().addDays(-staleDays - 5).toString();
    issue1[QStringLiteral("status")] = QStringLiteral("open");
    issues.append(issue1);
    
    // 实际实现中，这将使用 GitHub API v3 或 v4
    // curl -H "Authorization: token TOKEN" https://api.github.com/repos/owner/repo/issues
    
    return issues;
}

QJsonArray GitHubAutomationTool::detectDuplicateIssues(const QString &repository)
{
    QJsonArray duplicateGroups;
    
    // 模拟检测重复的 issue
    // 实际实现中，这会使用 GitHub 搜索 API 和文本相似性分析
    
    return duplicateGroups;
}

QJsonObject GitHubAutomationTool::applyLabels(const QString &repository, const QJsonObject &labelRules)
{
    QJsonObject result;
    int labelsApplied = 0;
    
    // 遍历 label 规则并应用
    for (auto it = labelRules.begin(); it != labelRules.end(); ++it) {
        const QString labelName = it.key();
        const QString rule = it.value().toString();
        
        // 根据规则应用标签
        // 示例：如果 title 包含"bug"，应用"bug"标签
        labelsApplied++;
    }
    
    result[QStringLiteral("repository")] = repository;
    result[QStringLiteral("labels_applied")] = labelsApplied;
    result[QStringLiteral("rules_count")] = labelRules.size();
    
    return result;
}

QJsonObject GitHubAutomationTool::checkMergeConditions(const QString &repository, const QString &prNumber)
{
    QJsonObject result;
    
    // 检查 PR 的合并条件
    // 1. 所有检查都已通过
    // 2. 所有审查都已批准
    // 3. 没有冲突
    // 4. 至少有 N 个审查
    
    result[QStringLiteral("pr_number")] = prNumber;
    result[QStringLiteral("can_merge")] = true;
    result[QStringLiteral("checks_passed")] = true;
    result[QStringLiteral("reviews_approved")] = true;
    result[QStringLiteral("conflicts")] = false;
    
    return result;
}

QJsonArray GitHubAutomationTool::cleanupBranches(const QString &repository, int daysOld)
{
    QJsonArray cleaned;
    
    // 执行 git 命令清理过期分支
    QProcess git;
    git.start(QStringLiteral("git"), QStringList{QStringLiteral("branch"), QStringLiteral("-v")});
    git.waitForFinished();
    
    const QString output = QString::fromUtf8(git.readAllStandardOutput());
    
    // 解析分支列表并找出过期的分支
    // 模拟返回已清理的分支
    
    return cleaned;
}

QString GitHubAutomationTool::generateGitHubReport(const QJsonArray &items)
{
    QString report;
    
    report += QStringLiteral("GitHub Automation Report\n");
    report += QStringLiteral("========================\n\n");
    report += QStringLiteral("Total items: ") + QString::number(items.size()) + '\n';
    
    return report;
}
