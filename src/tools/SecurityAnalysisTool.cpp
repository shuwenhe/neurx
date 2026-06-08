#include "SecurityAnalysisTool.h"
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QDirIterator>
#include <QRegularExpression>
#include <QJsonArray>
#include <QJsonDocument>
#include <QDebug>

SecurityAnalysisTool::SecurityAnalysisTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent), m_workspaceRoot(workspaceRoot)
{
}

SecurityAnalysisTool::~SecurityAnalysisTool() = default;

QString SecurityAnalysisTool::name() const
{
    return QStringLiteral("security_analysis");
}

QString SecurityAnalysisTool::description() const
{
    return QStringLiteral("Analyze code for security vulnerabilities (SQL injection, XSS, hardcoded secrets, etc.)");
}

QJsonObject SecurityAnalysisTool::parametersSchema() const
{
    QJsonObject schema;
    schema[QStringLiteral("action")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Action: scan_file, scan_directory")}
    };
    
    schema[QStringLiteral("file_path")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Path to file to scan")}
    };
    
    schema[QStringLiteral("directory")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Directory to scan recursively")}
    };
    
    schema[QStringLiteral("language")] = QJsonObject{
        {QStringLiteral("type"), QStringLiteral("string")},
        {QStringLiteral("description"), QStringLiteral("Programming language (python, javascript, java, cpp)")}
    };
    
    return schema;
}

ToolResult SecurityAnalysisTool::execute(const QString &callId, const QJsonObject &args)
{
    ToolResult result;
    result.callId = callId;
    result.name = name();
    
    const QString action = args.value(QStringLiteral("action")).toString();
    const QString language = args.value(QStringLiteral("language")).toString();
    
    if (action == QStringLiteral("scan_file")) {
        const QString filePath = args.value(QStringLiteral("file_path")).toString();
        
        if (filePath.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: file_path is required");
            return result;
        }
        
        const QJsonArray issues = scanFile(filePath, language);
        
        QJsonObject response;
        response[QStringLiteral("file")] = filePath;
        response[QStringLiteral("issues")] = issues;
        response[QStringLiteral("issue_count")] = issues.size();
        
        result.content = QJsonDocument(response).toJson(QJsonDocument::Compact);
        result.isError = issues.size() > 0;
        return result;
        
    } else if (action == QStringLiteral("scan_directory")) {
        const QString directory = args.value(QStringLiteral("directory")).toString();
        
        if (directory.isEmpty()) {
            result.isError = true;
            result.content = QStringLiteral("Error: directory is required");
            return result;
        }
        
        const QJsonObject response = scanDirectory(directory, language);
        result.content = QJsonDocument(response).toJson(QJsonDocument::Compact);
        
        const int issueCount = response.value(QStringLiteral("total_issues")).toInt();
        result.isError = issueCount > 0;
        return result;
    }
    
    result.isError = true;
    result.content = QStringLiteral("Error: Unknown action: %1").arg(action);
    return result;
}

QString SecurityAnalysisTool::summary(const QJsonObject &args) const
{
    const QString action = args.value(QStringLiteral("action")).toString();
    
    if (action == QStringLiteral("scan_file")) {
        return QStringLiteral("Security scan: %1").arg(args.value(QStringLiteral("file_path")).toString());
    } else if (action == QStringLiteral("scan_directory")) {
        return QStringLiteral("Security scan directory: %1").arg(args.value(QStringLiteral("directory")).toString());
    }
    
    return action;
}

QJsonArray SecurityAnalysisTool::scanFile(const QString &filePath, const QString &language)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QJsonArray();
    }
    
    const QString content = QString::fromUtf8(file.readAll());
    file.close();
    
    return scanForPattern(content, language);
}

QJsonObject SecurityAnalysisTool::scanDirectory(const QString &directory, const QString &language)
{
    QJsonObject result;
    QJsonArray allIssues;
    int filesScanned = 0;
    int totalIssues = 0;
    
    QDirIterator it(directory, {QStringLiteral("*.js"), QStringLiteral("*.ts"), QStringLiteral("*.py"), 
                                 QStringLiteral("*.java"), QStringLiteral("*.cpp"), QStringLiteral("*.cs")},
                    QDir::Files, QDirIterator::Subdirectories);
    
    while (it.hasNext()) {
        it.next();
        
        const QJsonArray issues = scanFile(it.filePath(), language);
        if (!issues.isEmpty()) {
            filesScanned++;
            totalIssues += issues.size();
            
            for (const QJsonValue &issue : issues) {
                QJsonObject issueObj = issue.toObject();
                issueObj[QStringLiteral("file")] = it.filePath();
                allIssues.append(issueObj);
            }
        }
    }
    
    result[QStringLiteral("directory")] = directory;
    result[QStringLiteral("files_scanned")] = filesScanned;
    result[QStringLiteral("total_issues")] = totalIssues;
    result[QStringLiteral("issues")] = allIssues;
    
    return result;
}

QJsonArray SecurityAnalysisTool::scanForPattern(const QString &content, const QString &language)
{
    QJsonArray issues;
    int lineNo = 1;
    
    const QStringList lines = content.split('\n');
    
    for (const QString &line : lines) {
        // 检测 SQL 注入
        if (line.contains(QRegularExpression(QStringLiteral("SELECT.*FROM.*WHERE.*\\+|execute\\(|eval\\(")))) {
            QJsonObject issue;
            issue[QStringLiteral("type")] = QStringLiteral("sql_injection");
            issue[QStringLiteral("severity")] = QStringLiteral("high");
            issue[QStringLiteral("line")] = lineNo;
            issue[QStringLiteral("message")] = QStringLiteral("Potential SQL injection risk");
            issues.append(issue);
        }
        
        // 检测 XSS 风险
        if (line.contains(QRegularExpression(QStringLiteral("innerHTML|dangerouslySetInnerHTML|eval\\(")))) {
            QJsonObject issue;
            issue[QStringLiteral("type")] = QStringLiteral("xss");
            issue[QStringLiteral("severity")] = QStringLiteral("high");
            issue[QStringLiteral("line")] = lineNo;
            issue[QStringLiteral("message")] = QStringLiteral("Potential XSS vulnerability");
            issues.append(issue);
        }
        
        // 检测硬编码密钥
        if (line.contains(QRegularExpression(QStringLiteral("(password|secret|api_key|token)\\s*=\\s*['\"]")))) {
            QJsonObject issue;
            issue[QStringLiteral("type")] = QStringLiteral("hardcoded_secret");
            issue[QStringLiteral("severity")] = QStringLiteral("critical");
            issue[QStringLiteral("line")] = lineNo;
            issue[QStringLiteral("message")] = QStringLiteral("Hardcoded secret detected");
            issues.append(issue);
        }
        
        // 检测命令注入
        if (line.contains(QRegularExpression(QStringLiteral("system\\(|exec\\(|os\\.system|subprocess\\.call")))) {
            QJsonObject issue;
            issue[QStringLiteral("type")] = QStringLiteral("command_injection");
            issue[QStringLiteral("severity")] = QStringLiteral("high");
            issue[QStringLiteral("line")] = lineNo;
            issue[QStringLiteral("message")] = QStringLiteral("Potential command injection");
            issues.append(issue);
        }
        
        // 检测不安全的反序列化
        if (line.contains(QRegularExpression(QStringLiteral("pickle\\.load|json\\.loads\\s*\\(\\s*user_input|eval\\s*\\(")))) {
            QJsonObject issue;
            issue[QStringLiteral("type")] = QStringLiteral("unsafe_deserialization");
            issue[QStringLiteral("severity")] = QStringLiteral("high");
            issue[QStringLiteral("line")] = lineNo;
            issue[QStringLiteral("message")] = QStringLiteral("Unsafe deserialization");
            issues.append(issue);
        }
        
        // 检测弱密码算法
        if (line.contains(QRegularExpression(QStringLiteral("md5|sha1|crypt\\(")))) {
            QJsonObject issue;
            issue[QStringLiteral("type")] = QStringLiteral("weak_crypto");
            issue[QStringLiteral("severity")] = QStringLiteral("medium");
            issue[QStringLiteral("line")] = lineNo;
            issue[QStringLiteral("message")] = QStringLiteral("Weak cryptographic algorithm");
            issues.append(issue);
        }
        
        lineNo++;
    }
    
    return issues;
}

bool SecurityAnalysisTool::hasSqlInjectionRisk(const QString &content)
{
    return content.contains(QRegularExpression(QStringLiteral("execute\\(.*\\+.*query|'\\s*\\+\\s*variable")));
}

bool SecurityAnalysisTool::hasXssRisk(const QString &content)
{
    return content.contains(QRegularExpression(QStringLiteral("innerHTML.*=|dangerouslySetInnerHTML")));
}

bool SecurityAnalysisTool::hasHardcodedSecrets(const QString &content)
{
    return content.contains(QRegularExpression(QStringLiteral("password.*=|secret.*=|api_key.*=")));
}

bool SecurityAnalysisTool::hasCommandInjection(const QString &content)
{
    return content.contains(QRegularExpression(QStringLiteral("system\\(|exec\\(|shell.*=.*true")));
}

QString SecurityAnalysisTool::generateSecurityReport(const QJsonArray &issues)
{
    QString report;
    QTextStream stream(&report);
    
    stream << QStringLiteral("Security Analysis Report\n");
    stream << QStringLiteral("========================\n\n");
    
    stream << QStringLiteral("Total Issues: ") << issues.size() << '\n';
    
    int critical = 0, high = 0, medium = 0;
    
    for (const QJsonValue &val : issues) {
        const QJsonObject issue = val.toObject();
        const QString severity = issue.value(QStringLiteral("severity")).toString();
        
        if (severity == QStringLiteral("critical")) critical++;
        else if (severity == QStringLiteral("high")) high++;
        else if (severity == QStringLiteral("medium")) medium++;
    }
    
    stream << QStringLiteral("Critical: ") << critical << '\n';
    stream << QStringLiteral("High: ") << high << '\n';
    stream << QStringLiteral("Medium: ") << medium << '\n';
    
    return report;
}
