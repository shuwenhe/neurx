#include "RiskAssessor.h"
#include <QRegularExpression>
#include <QJsonDocument>
#include <QJsonArray>
#include <QFileInfo>
#include <QDir>

RiskAssessor::RiskAssessor(QObject *parent)
    : QObject(parent)
{
    initializePatterns();
}

RiskAssessor::~RiskAssessor()
{
}

void RiskAssessor::initializePatterns()
{
    // 危险的文件模式 - 系统关键文件
    m_dangerousFilePatterns = {
        // 系统配置
        {"/etc/.*", CRITICAL},
        {"/System/.*", CRITICAL},
        {"/Library/.*", HIGH},
        {"/usr/local/bin/.*", HIGH},
        {"/etc/passwd", CRITICAL},
        {"/etc/shadow", CRITICAL},
        {"/etc/sudoers", CRITICAL},
        // 隐藏配置
        {".*/.ssh/.*", HIGH},
        {".*/.aws/.*", HIGH},
        {".*/.env.*", HIGH},
        {".*/.git/config", MEDIUM},
        // 系统目录
        {"/boot/.*", CRITICAL},
        {"/bin/.*", HIGH},
        {"/sbin/.*", HIGH},
        {"/sys/.*", HIGH},
        {"/proc/.*", HIGH},
    };

    // 危险的网络模式
    m_dangerousNetworkPatterns = {
        {"internal-.*", HIGH},
        {"localhost:.*", MEDIUM},
        {"127.0.0.1:.*", MEDIUM},
        {"*.internal", HIGH},
        {"169.254.*", HIGH},  // Link-local
    };

    // 危险的系统命令
    m_dangerousCommandPatterns = {
        {"sudo.*", CRITICAL},
        {"chmod.*777.*", CRITICAL},
        {"rm -rf /.*", CRITICAL},
        {"dd if=/dev/zero.*", CRITICAL},
        {"mkfs.*", CRITICAL},
        {"kill -9.*", HIGH},
        {":(){ :|:& };:", CRITICAL},  // 叉炸弹
    };

    // 秘密信息模式
    m_secretPatterns = {
        {"password", HIGH},
        {"secret", HIGH},
        {"token", HIGH},
        {"api[_-]?key", CRITICAL},
        {"aws[_-]?key", CRITICAL},
        {"private[_-]?key", CRITICAL},
        {"credential", MEDIUM},
        {"bearer.*", HIGH},
    };
}

QList<RiskAssessor::RiskFinding> RiskAssessor::assessToolOperation(
    const QString &toolName,
    const QString &action,
    const QJsonObject &parameters)
{
    QList<RiskFinding> findings;

    // 根据工具类型进行风险评估
    if (toolName.contains("File", Qt::CaseInsensitive) ||
        toolName.contains("System", Qt::CaseInsensitive)) {
        findings.append(assessFileSystemRisk(action, parameters));
    }

    if (toolName.contains("Shell", Qt::CaseInsensitive) ||
        toolName.contains("Command", Qt::CaseInsensitive) ||
        toolName.contains("Process", Qt::CaseInsensitive)) {
        findings.append(assessSystemCommandRisk(action, parameters));
    }

    if (toolName.contains("Network", Qt::CaseInsensitive) ||
        toolName.contains("Http", Qt::CaseInsensitive) ||
        toolName.contains("Curl", Qt::CaseInsensitive)) {
        findings.append(assessNetworkRisk(action, parameters));
    }

    if (toolName.contains("Database", Qt::CaseInsensitive) ||
        toolName.contains("SQL", Qt::CaseInsensitive)) {
        findings.append(assessDatabaseRisk(action, parameters));
    }

    if (toolName.contains("Secrets", Qt::CaseInsensitive) ||
        toolName.contains("Credential", Qt::CaseInsensitive)) {
        findings.append(assessSecretsRisk(action, parameters));
    }

    if (toolName.contains("Batch", Qt::CaseInsensitive) ||
        toolName.contains("Loop", Qt::CaseInsensitive)) {
        findings.append(assessResourcesRisk(action, parameters));
    }

    return findings;
}

RiskAssessor::RiskLevel RiskAssessor::getMaxRiskLevel(
    const QList<RiskFinding> &findings)
{
    RiskLevel maxLevel = MINIMAL;
    for (const auto &finding : findings) {
        if (finding.level > maxLevel) {
            maxLevel = finding.level;
        }
    }
    return maxLevel;
}

QJsonObject RiskAssessor::generateRiskReport(
    const QList<RiskFinding> &findings)
{
    QJsonObject report;
    report["totalFindings"] = static_cast<int>(findings.size());
    report["maxRiskLevel"] = riskLevelName(getMaxRiskLevel(findings));

    // 按风险等级分类
    QMap<QString, int> levelCounts;
    QJsonArray findingsArray;

    for (const auto &finding : findings) {
        QString levelName = riskLevelName(finding.level);
        levelCounts[levelName]++;

        QJsonObject findingObj;
        findingObj["category"] = riskCategoryName(finding.category);
        findingObj["level"] = levelName;
        findingObj["type"] = finding.riskType;
        findingObj["description"] = finding.description;
        findingObj["affectedResource"] = finding.affectedResource;

        QJsonArray recommendations;
        for (const auto &rec : finding.recommendations) {
            recommendations.append(rec);
        }
        findingObj["recommendations"] = recommendations;

        findingsArray.append(findingObj);
    }

    // 添加统计
    QJsonObject statistics;
    for (const auto &level : levelCounts.keys()) {
        statistics[level] = levelCounts[level];
    }
    report["statistics"] = statistics;
    report["findings"] = findingsArray;

    return report;
}

bool RiskAssessor::requiresApproval(RiskLevel level,
                                     const QString &approvalPolicy)
{
    if (approvalPolicy == "Never") {
        return false;
    } else if (approvalPolicy == "OnFailure") {
        return level >= HIGH;
    } else if (approvalPolicy == "OnRequest") {
        return true;
    } else if (approvalPolicy == "Granular") {
        return level >= MEDIUM;
    } else if (approvalPolicy == "UnlessTrusted") {
        return level >= HIGH;
    }
    return level >= CRITICAL;
}

QString RiskAssessor::riskLevelName(RiskLevel level)
{
    switch (level) {
    case MINIMAL:
        return "MINIMAL";
    case LOW:
        return "LOW";
    case MEDIUM:
        return "MEDIUM";
    case HIGH:
        return "HIGH";
    case CRITICAL:
        return "CRITICAL";
    default:
        return "UNKNOWN";
    }
}

QString RiskAssessor::riskCategoryName(RiskCategory category)
{
    switch (category) {
    case FileSystem:
        return "FileSystem";
    case Network:
        return "Network";
    case SystemCommand:
        return "SystemCommand";
    case Database:
        return "Database";
    case Secrets:
        return "Secrets";
    case Resources:
        return "Resources";
    default:
        return "Unknown";
    }
}

QList<RiskAssessor::RiskFinding> RiskAssessor::assessFileSystemRisk(
    const QString &action,
    const QJsonObject &params)
{
    QList<RiskFinding> findings;

    QString path = params.value("path").toString();
    if (path.isEmpty()) {
        path = params.value("filePath").toString();
    }

    // 检查路径遍历攻击
    if (isPathTraversalAttempt(path)) {
        RiskFinding finding;
        finding.category = FileSystem;
        finding.level = CRITICAL;
        finding.riskType = "PathTraversal";
        finding.description = "Detected path traversal attempt using ../ sequences";
        finding.affectedResource = path;
        finding.recommendations = {"Use safePath() validation", "Restrict to workspace directory"};
        findings.append(finding);
    }

    // 检查是否操作系统关键文件
    for (const auto &pattern : m_dangerousFilePatterns.keys()) {
        QRegularExpression regex(pattern);
        if (regex.match(path).hasMatch()) {
            RiskFinding finding;
            finding.category = FileSystem;
            finding.level = m_dangerousFilePatterns[pattern];
            finding.riskType = "DangerousPath";
            finding.description = QString("Operation on system-critical path: %1").arg(path);
            finding.affectedResource = path;
            finding.recommendations = {"Verify this is necessary", "Use read-only mode if possible"};
            findings.append(finding);
            break;
        }
    }

    // 检查删除操作
    if (action.toLower() == "delete" || action.toLower() == "remove") {
        RiskFinding finding;
        finding.category = FileSystem;
        finding.level = HIGH;
        finding.riskType = "DestructiveOperation";
        finding.description = "Destructive file operation detected";
        finding.affectedResource = path;
        finding.recommendations = {"Require explicit user confirmation", "Create backup before deletion"};
        findings.append(finding);
    }

    // 检查内容中的敏感信息
    if (params.contains("content")) {
        QString content = params.value("content").toString();
        if (containsSensitivePatterns(content)) {
            RiskFinding finding;
            finding.category = Secrets;
            finding.level = HIGH;
            finding.riskType = "SensitiveContent";
            finding.description = "Detected sensitive information patterns in file content";
            finding.affectedResource = path;
            finding.recommendations = {"Verify no credentials are exposed", "Use environment variables instead"};
            findings.append(finding);
        }
    }

    return findings;
}

QList<RiskAssessor::RiskFinding> RiskAssessor::assessNetworkRisk(
    const QString &action,
    const QJsonObject &params)
{
    QList<RiskFinding> findings;

    QString url = params.value("url").toString();
    QString host = params.value("host").toString();

    if (url.isEmpty() && host.isEmpty()) {
        return findings;
    }

    // 检查内部网络
    for (const auto &pattern : m_dangerousNetworkPatterns.keys()) {
        QRegularExpression regex(pattern);
        if (regex.match(url + host).hasMatch()) {
            RiskFinding finding;
            finding.category = Network;
            finding.level = m_dangerousNetworkPatterns[pattern];
            finding.riskType = "InternalNetworkAccess";
            finding.description = "Attempting to access internal network resources";
            finding.affectedResource = url.isEmpty() ? host : url;
            finding.recommendations = {"Verify this is an internal service", "Check network isolation"};
            findings.append(finding);
        }
    }

    // 检查无HTTPS连接
    if (!url.isEmpty() && url.startsWith("http://")) {
        RiskFinding finding;
        finding.category = Network;
        finding.level = MEDIUM;
        finding.riskType = "InsecureConnection";
        finding.description = "HTTP connection without encryption";
        finding.affectedResource = url;
        finding.recommendations = {"Use HTTPS instead", "Enable TLS certificate verification"};
        findings.append(finding);
    }

    return findings;
}

QList<RiskAssessor::RiskFinding> RiskAssessor::assessSystemCommandRisk(
    const QString &action,
    const QJsonObject &params)
{
    QList<RiskFinding> findings;

    QString command = params.value("command").toString();
    if (command.isEmpty()) {
        return findings;
    }

    // 检查危险命令
    for (const auto &pattern : m_dangerousCommandPatterns.keys()) {
        QRegularExpression regex(pattern);
        if (regex.match(command).hasMatch()) {
            RiskFinding finding;
            finding.category = SystemCommand;
            finding.level = m_dangerousCommandPatterns[pattern];
            finding.riskType = "DangerousCommand";
            finding.description = QString("Detected dangerous system command: %1").arg(pattern);
            finding.affectedResource = command;
            finding.recommendations = {"Restrict permissions", "Use sandboxed execution"};
            findings.append(finding);
        }
    }

    // 检查命令注入
    if (command.contains(";") || command.contains("|") || command.contains("&&") ||
        command.contains("||") || command.contains("`")) {
        RiskFinding finding;
        finding.category = SystemCommand;
        finding.level = HIGH;
        finding.riskType = "CommandInjection";
        finding.description = "Command may contain injection vectors";
        finding.affectedResource = command;
        finding.recommendations = {"Use array-based command execution", "Properly escape arguments"};
        findings.append(finding);
    }

    return findings;
}

QList<RiskAssessor::RiskFinding> RiskAssessor::assessDatabaseRisk(
    const QString &action,
    const QJsonObject &params)
{
    QList<RiskFinding> findings;

    // 检查SQL注入
    QString query = params.value("query").toString();
    if (query.contains("'") || query.contains("\"")) {
        RiskFinding finding;
        finding.category = Database;
        finding.level = CRITICAL;
        finding.riskType = "SQLInjection";
        finding.description = "Potential SQL injection vulnerability detected";
        finding.affectedResource = query;
        finding.recommendations = {"Use prepared statements", "Validate all inputs", "Use ORM frameworks"};
        findings.append(finding);
    }

    // 检查删除/修改操作
    if (action.toLower() == "delete" || action.toLower() == "update" ||
        action.toLower() == "drop") {
        RiskFinding finding;
        finding.category = Database;
        finding.level = HIGH;
        finding.riskType = "DataModification";
        finding.description = "Database modification operation detected";
        finding.affectedResource = params.value("table").toString();
        finding.recommendations = {"Require explicit confirmation", "Use transactions", "Create backups"};
        findings.append(finding);
    }

    return findings;
}

QList<RiskAssessor::RiskFinding> RiskAssessor::assessSecretsRisk(
    const QString &action,
    const QJsonObject &params)
{
    QList<RiskFinding> findings;

    // 检查所有参数中的秘密信息
    for (auto it = params.begin(); it != params.end(); ++it) {
        QString key = it.key();
        QString value = it.value().toString();

        // 检查key名称
        for (const auto &pattern : m_secretPatterns.keys()) {
            QRegularExpression regex(pattern, QRegularExpression::CaseInsensitiveOption);
            if (regex.match(key).hasMatch() || regex.match(value).hasMatch()) {
                RiskFinding finding;
                finding.category = Secrets;
                finding.level = m_secretPatterns[pattern];
                finding.riskType = "SecretsExposure";
                finding.description = QString("Detected potential secrets in parameter: %1").arg(key);
                finding.affectedResource = key;
                finding.recommendations = {
                    "Use secure credential storage (e.g., .env files)",
                    "Never log or display secrets",
                    "Rotate secrets regularly"
                };
                findings.append(finding);
                break;
            }
        }
    }

    return findings;
}

QList<RiskAssessor::RiskFinding> RiskAssessor::assessResourcesRisk(
    const QString &action,
    const QJsonObject &params)
{
    QList<RiskFinding> findings;

    int estimatedUsage = estimateResourceUsage(params);
    if (estimatedUsage > 80) {
        RiskFinding finding;
        finding.category = Resources;
        finding.level = HIGH;
        finding.riskType = "ResourceExhaustion";
        finding.description = QString("Operation may exhaust resources (estimated: %1%)").arg(estimatedUsage);
        finding.affectedResource = "System Resources";
        finding.recommendations = {
            "Add iteration limits",
            "Implement timeout mechanisms",
            "Monitor resource usage"
        };
        findings.append(finding);
    }

    return findings;
}

bool RiskAssessor::isPathTraversalAttempt(const QString &path)
{
    return path.contains("..") || path.contains("./") ||
           path.contains("\\..") || path.contains("\\.\\");
}

bool RiskAssessor::containsSensitivePatterns(const QString &content)
{
    for (const auto &pattern : m_secretPatterns.keys()) {
        QRegularExpression regex(pattern, QRegularExpression::CaseInsensitiveOption);
        if (regex.match(content).hasMatch()) {
            return true;
        }
    }
    return false;
}

int RiskAssessor::estimateResourceUsage(const QJsonObject &params)
{
    int usage = 0;

    // 检查迭代次数
    if (params.contains("count")) {
        int count = params.value("count").toInt(0);
        if (count > 1000) usage += 40;
        else if (count > 100) usage += 20;
    }

    // 检查文件大小
    if (params.contains("fileSize")) {
        qint64 size = static_cast<qint64>(params.value("fileSize").toDouble(0));
        if (size > 1000000000) usage += 40;  // > 1GB
        else if (size > 100000000) usage += 20;  // > 100MB
    }

    // 检查递归深度
    if (params.contains("depth")) {
        int depth = params.value("depth").toInt(0);
        if (depth > 10) usage += 30;
        else if (depth > 5) usage += 15;
    }

    return qMin(usage, 100);
}
