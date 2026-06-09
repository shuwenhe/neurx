#pragma once

#include <QString>
#include <QStringList>
#include <QJsonObject>
#include <QJsonArray>
#include <QDir>
#include <QDateTime>

/**
 * @struct FolderDiscoveryResults
 * @brief 文件夹信任发现结果
 */
struct FolderDiscoveryResults {
    QStringList commands;         ///< 发现的自定义命令
    QStringList mcps;             ///< 发现的 MCP 服务器
    QStringList hooks;            ///< 发现的钩子 (hooks)
    QStringList skills;           ///< 发现的技能 (skills)
    QStringList agents;           ///< 发现的自定义 Agent
    QStringList settings;         ///< 发现的其他配置项
    QStringList securityWarnings; ///< 安全警告
    QStringList discoveryErrors;  ///< 发现过程中的错误

    QJsonObject toJson() const;
};

/**
 * @class FolderTrustDiscoveryService
 * @brief 文件夹信任发现服务
 *
 * 在文件夹被信任之前，安全地扫描其本地配置（.neurx 目录）。
 * 该服务是只读的，且不执行任何扫描到的代码。
 */
class FolderTrustDiscoveryService {
public:
    /**
     * @brief 扫描工作空间目录中的配置
     * @param workspaceDir 工作空间目录
     */
    static FolderDiscoveryResults discover(const QString &workspaceDir);

private:
    static void discoverCommands(const QString &neurxDir, FolderDiscoveryResults &results);
    static void discoverSkills(const QString &neurxDir, FolderDiscoveryResults &results);
    static void discoverAgents(const QString &neurxDir, FolderDiscoveryResults &results);
    static void discoverSettings(const QString &neurxDir, FolderDiscoveryResults &results);

    static QStringList collectSecurityWarnings(const QJsonObject &settings);
    static QString stripJsonComments(const QString &json);
};

