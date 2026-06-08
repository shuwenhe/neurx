#pragma once

#include "agent/AgentToolRegistry.h"
#include <QString>
#include <QStringList>
#include <QJsonObject>

/**
 * @class CodeMigrationTool
 * @brief 代码迁移和大规模代码转换工具
 * 
 * 功能：
 * - 大规模文本搜索和替换
 * - 模式匹配转换
 * - API 版本迁移
 * - 框架升级辅助
 * - 变量重命名
 * - 导入路径更新
 * 
 * 使用示例：
 * {
 *   "tool": "code_migration",
 *   "action": "find_and_replace",
 *   "directory": "/path/to/project",
 *   "pattern": "oldAPI\\.method",
 *   "replacement": "newAPI.method",
 *   "file_pattern": "*.js",
 *   "dry_run": true
 * }
 */
class CodeMigrationTool : public BaseTool {
public:
    explicit CodeMigrationTool(const QString &workspaceRoot, QObject *parent = nullptr);
    ~CodeMigrationTool() override;

    // ── BaseTool 接口实现 ───────────────────────────────────────────────────
    
    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

private:
    QString m_workspaceRoot;
    
    // ── 迁移操作 ────────────────────────────────────────────────────────────
    
    /**
     * @brief 大规模查找和替换
     */
    QJsonObject findAndReplace(const QString &directory, const QString &pattern, 
                               const QString &replacement, const QString &filePattern,
                               bool dryRun = true, bool useRegex = false);
    
    /**
     * @brief 重命名导入路径
     */
    QJsonObject migrateImports(const QString &directory, const QString &oldPath,
                               const QString &newPath, const QString &filePattern);
    
    /**
     * @brief 迁移 API 调用
     */
    QJsonObject migrateApiCalls(const QString &directory, const QJsonObject &mappings,
                                const QString &filePattern);
    
    /**
     * @brief 生成迁移报告
     */
    QString generateMigrationReport(const QJsonArray &changes);
    
    /**
     * @brief 应用变更
     */
    bool applyChanges(const QJsonArray &changes);
};
