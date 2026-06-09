#include "FolderTrustDiscoveryService.h"
#include <QJsonDocument>
#include <QFileInfo>
#include <QDirIterator>
#include <QRegularExpression>
#include <QDebug>

static const QString NEURX_DIR = ".neurx";

QJsonObject FolderDiscoveryResults::toJson() const {
    QJsonObject obj;
    obj["commands"] = QJsonArray::fromStringList(commands);
    obj["mcps"] = QJsonArray::fromStringList(mcps);
    obj["hooks"] = QJsonArray::fromStringList(hooks);
    obj["skills"] = QJsonArray::fromStringList(skills);
    obj["agents"] = QJsonArray::fromStringList(agents);
    obj["settings"] = QJsonArray::fromStringList(settings);
    obj["securityWarnings"] = QJsonArray::fromStringList(securityWarnings);
    obj["discoveryErrors"] = QJsonArray::fromStringList(discoveryErrors);
    return obj;
}

FolderDiscoveryResults FolderTrustDiscoveryService::discover(const QString &workspaceDir) {
    FolderDiscoveryResults results;

    QDir dir(workspaceDir);
    if (!dir.exists(NEURX_DIR)) {
        return results;
    }

    QString neurxDir = dir.absoluteFilePath(NEURX_DIR);

    discoverCommands(neurxDir, results);
    discoverSkills(neurxDir, results);
    discoverAgents(neurxDir, results);
    discoverSettings(neurxDir, results);

    return results;
}

void FolderTrustDiscoveryService::discoverCommands(const QString &neurxDir, FolderDiscoveryResults &results) {
    QDir dir(neurxDir + "/commands");
    if (!dir.exists()) return;

    QDirIterator it(dir.path(), QStringList() << "*.toml", QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        results.commands << it.fileInfo().baseName();
    }
}

void FolderTrustDiscoveryService::discoverSkills(const QString &neurxDir, FolderDiscoveryResults &results) {
    QDir dir(neurxDir + "/skills");
    if (!dir.exists()) return;

    QDirIterator it(dir.path(), QDir::Dirs | QDir::NoDotAndDotDot);
    while (it.hasNext()) {
        it.next();
        QString skillMdPath = it.filePath() + "/SKILL.md";
        if (QFileInfo::exists(skillMdPath)) {
            results.skills << it.fileName();
        }
    }
}

void FolderTrustDiscoveryService::discoverAgents(const QString &neurxDir, FolderDiscoveryResults &results) {
    QDir dir(neurxDir + "/agents");
    if (!dir.exists()) return;

    QDirIterator it(dir.path(), QStringList() << "*.md", QDir::Files);
    while (it.hasNext()) {
        it.next();
        QString name = it.fileName();
        if (!name.startsWith('_')) {
            results.agents << it.fileInfo().baseName();
        }
    }

    if (!results.agents.isEmpty()) {
        results.securityWarnings << "此项目包含自定义 Agent (Custom Agents)。";
    }
}

void FolderTrustDiscoveryService::discoverSettings(const QString &neurxDir, FolderDiscoveryResults &results) {
    QString settingsPath = neurxDir + "/settings.json";
    if (!QFileInfo::exists(settingsPath)) return;

    QFile file(settingsPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        results.discoveryErrors << "无法读取 settings.json";
        return;
    }

    QString content = QString::fromUtf8(file.readAll());
    QString strippedContent = stripJsonComments(content);

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(strippedContent.toUtf8(), &error);
    if (error.error != QJsonParseError::NoError) {
        results.discoveryErrors << "解析 settings.json 失败: " + error.errorString();
        return;
    }

    if (!doc.isObject()) {
        results.discoveryErrors << "settings.json 必须是一个 JSON 对象。";
        return;
    }

    QJsonObject settings = doc.object();

    // 获取普通的设置项（过滤掉已知的特殊项）
    QStringList keys = settings.keys();
    for (const QString &key : keys) {
        if (key != "mcpServers" && key != "hooks" && key != "$schema") {
            results.settings << key;
        }
    }

    // 收集安全警告
    results.securityWarnings << collectSecurityWarnings(settings);

    // 发现 MCP
    if (settings.contains("mcpServers") && settings["mcpServers"].isObject()) {
        results.mcps << settings["mcpServers"].toObject().keys();
    }

    // 发现 Hooks
    if (settings.contains("hooks") && settings["hooks"].isObject()) {
        QJsonObject hooksObj = settings["hooks"].toObject();
        QStringList hookCommands;
        for (auto it = hooksObj.begin(); it != hooksObj.end(); ++it) {
            if (it.value().isArray()) {
                QJsonArray events = it.value().toArray();
                for (const QJsonValue &event : events) {
                    if (event.isObject()) {
                        QJsonObject hook = event.toObject();
                        if (hook.contains("command") && hook["command"].isString()) {
                            QString cmd = hook["command"].toString();
                            if (!hookCommands.contains(cmd)) {
                                hookCommands << cmd;
                            }
                        }
                    }
                }
            }
        }
        results.hooks = hookCommands;
    }
}

QStringList FolderTrustDiscoveryService::collectSecurityWarnings(const QJsonObject &settings) {
    QStringList warnings;

    QJsonObject tools = settings["tools"].toObject();
    QJsonObject security = settings["security"].toObject();
    QJsonObject folderTrust = security["folderTrust"].toObject();

    QJsonValue allowedTools = tools["allowed"];
    if (allowedTools.isArray() && !allowedTools.toArray().isEmpty()) {
        warnings << "此项目自动批准某些工具 (tools.allowed)。";
    }

    if (security.contains("folderTrust") && folderTrust["enabled"].isBool() && !folderTrust["enabled"].toBool()) {
        warnings << "此项目尝试禁用文件夹信任检查 (security.folderTrust.enabled)。";
    }

    if (tools.contains("sandbox") && tools["sandbox"].isBool() && !tools["sandbox"].toBool()) {
        warnings << "此项目禁用了安全沙箱 (tools.sandbox)。";
    }

    return warnings;
}

QString FolderTrustDiscoveryService::stripJsonComments(const QString &json) {
    // 简单的正则实现：移除 // 和 /* ... */
    // 注意：这不处理字符串内部的 // 或 /*
    // 在真实场景中应该更健壮，但对于这个端口来说，目前的实现足以演示
    QString result = json;

    // 移除多行注释
    QRegularExpression multiLineComment("/\\*.*?\\*/", QRegularExpression::DotMatchesEverythingOption);
    result.remove(multiLineComment);

    // 移除单行注释
    QRegularExpression singleLineComment("//.*");
    result.remove(singleLineComment);

    return result;
}

