#pragma once

#include "agent/AgentToolRegistry.h"
#include <QString>
#include <QStringList>
#include <QJsonObject>

/**
 * @class ConfigGeneratorTool
 * @brief 配置文件生成工具
 * 
 * 功能：
 * - 环境配置生成（.env, .env.local, .env.production）
 * - JSON 配置生成
 * - YAML 配置生成
 * - 多平台配置（macOS plist, Windows registry）
 * - 配置变量替换
 * - 配置验证
 * 
 * 使用示例：
 * {
 *   "tool": "config_generator",
 *   "action": "generate_env",
 *   "environment": "development",
 *   "variables": {
 *     "API_URL": "http://localhost:3000",
 *     "DATABASE_URL": "postgres://...",
 *     "DEBUG": "true"
 *   },
 *   "output_file": "/path/to/.env.development"
 * }
 */
class ConfigGeneratorTool : public BaseTool {
public:
    explicit ConfigGeneratorTool(const QString &workspaceRoot, QObject *parent = nullptr);
    ~ConfigGeneratorTool() override;

    // ── BaseTool 接口实现 ───────────────────────────────────────────────────
    
    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

private:
    QString m_workspaceRoot;
    
    // ── 配置生成 ────────────────────────────────────────────────────────────
    
    /**
     * @brief 生成 .env 文件
     */
    QString generateEnvFile(const QJsonObject &variables, bool addComments = true);
    
    /**
     * @brief 生成 JSON 配置
     */
    QString generateJsonConfig(const QJsonObject &config, bool pretty = true);
    
    /**
     * @brief 生成 YAML 配置
     */
    QString generateYamlConfig(const QJsonObject &config);
    
    /**
     * @brief 生成 macOS plist 配置
     */
    QString generatePlistConfig(const QJsonObject &config);
    
    /**
     * @brief 生成 Windows 注册表脚本
     */
    QString generateWindowsRegistryScript(const QJsonObject &config, const QString &keyPath);
    
    /**
     * @brief 验证配置
     */
    bool validateConfig(const QJsonObject &config, const QStringList &requiredKeys);
    
    /**
     * @brief 获取配置模板
     */
    QJsonObject getConfigTemplate(const QString &type);
    
    /**
     * @brief 转义字符串用于不同格式
     */
    QString escapeForFormat(const QString &value, const QString &format);
};
