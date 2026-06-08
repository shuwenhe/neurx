#include "SecurityScanner.h"
#include <QFile>
#include <QTextStream>
#include <QFileInfo>
#include <QDebug>

// ── 构造和析构 ──────────────────────────────────────────────────────────────

SecurityScanner::SecurityScanner(QObject *parent)
    : QObject(parent)
    , m_severityThreshold(Severity::Info)
    , m_layer1Enabled(true)
{
    initDangerousPatterns();
    qInfo() << "[SecurityScanner] Initialized with" << m_patterns.size() << "patterns";
}

SecurityScanner::~SecurityScanner()
{
    qInfo() << "[SecurityScanner] Destroyed";
}

// ── Layer 1: 模式扫描 ───────────────────────────────────────────────────────

QList<SecurityScanner::SecurityIssue> SecurityScanner::scanFile(const QString& filePath)
{
    QList<SecurityIssue> issues;

    if (!m_layer1Enabled) {
        return issues;
    }

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "[SecurityScanner] Failed to open file:" << filePath;
        return issues;
    }

    QTextStream in(&file);
    QString content = in.readAll();
    file.close();

    return scanContent(content, filePath);
}

QList<SecurityScanner::SecurityIssue> SecurityScanner::scanContent(const QString& content, const QString& filePath)
{
    if (!m_layer1Enabled) {
        return {};
    }

    QStringList lines = content.split('\n');
    return scanLines(lines, filePath);
}

QList<SecurityScanner::SecurityIssue> SecurityScanner::scanDiff(const QString& diff)
{
    QList<SecurityIssue> issues;

    if (!m_layer1Enabled) {
        return issues;
    }

    // 解析 diff，只扫描新增的行（以 + 开头）
    QStringList lines = diff.split('\n');
    QString currentFile;
    int lineNumber = 0;

    for (const QString& line : lines) {
        // 解析文件名
        if (line.startsWith("+++")) {
            currentFile = line.mid(4).trimmed();
            if (currentFile.startsWith("b/")) {
                currentFile = currentFile.mid(2);
            }
            continue;
        }

        // 解析行号
        if (line.startsWith("@@")) {
            // 提取新文件的起始行号
            QRegularExpression lineNumRe("\\+([0-9]+)");
            QRegularExpressionMatch match = lineNumRe.match(line);
            if (match.hasMatch()) {
                lineNumber = match.captured(1).toInt();
            }
            continue;
        }

        // 只扫描新增的行
        if (line.startsWith("+") && !line.startsWith("+++")) {
            QString content = line.mid(1);  // 去掉 + 前缀
            
            QList<SecurityIssue> lineIssues = scanLines({content}, currentFile);
            for (SecurityIssue& issue : lineIssues) {
                issue.lineNumber = lineNumber;
                issues.append(issue);
            }
        }

        // 更新行号
        if (!line.startsWith("-")) {
            lineNumber++;
        }
    }

    qInfo() << "[SecurityScanner] Scanned diff, found" << issues.size() << "issues";
    
    return issues;
}

// ── 模式管理 ────────────────────────────────────────────────────────────────

void SecurityScanner::setPatternEnabled(const QString& patternName, bool enabled)
{
    if (m_metadata.contains(patternName)) {
        m_metadata[patternName].enabled = enabled;
        qInfo() << "[SecurityScanner] Pattern" << patternName << (enabled ? "enabled" : "disabled");
    } else {
        qWarning() << "[SecurityScanner] Pattern not found:" << patternName;
    }
}

QJsonObject SecurityScanner::getPatternMetadata(const QString& patternName) const
{
    QJsonObject obj;
    
    if (m_metadata.contains(patternName)) {
        const PatternMetadata& meta = m_metadata[patternName];
        obj["name"] = meta.name;
        obj["description"] = meta.description;
        obj["severity"] = severityToString(meta.severity);
        obj["cweId"] = meta.cweId;
        obj["recommendation"] = meta.recommendation;
        obj["enabled"] = meta.enabled;
    }
    
    return obj;
}

void SecurityScanner::setSeverityThreshold(Severity threshold)
{
    m_severityThreshold = threshold;
    qInfo() << "[SecurityScanner] Severity threshold set to" << severityToString(threshold);
}

// ── 初始化危险模式 ──────────────────────────────────────────────────────────

void SecurityScanner::initDangerousPatterns()
{
    initPythonPatterns();
    initJavaScriptPatterns();
    initShellPatterns();
    initSecretPatterns();
    initSQLPatterns();
    initXSSPatterns();
}

void SecurityScanner::initPythonPatterns()
{
    PatternMetadata meta;
    
    // 1. 不安全的 YAML 反序列化
    m_patterns["unsafe_yaml"] = QRegularExpression("yaml\\.load\\s*\\([^)]*(?!.*Loader=)");
    meta = PatternMetadata();
    meta.name = "unsafe_yaml";
    meta.description = "Unsafe YAML deserialization - use yaml.safe_load() or specify Loader";
    meta.severity = Severity::Critical;
    meta.cweId = "CWE-502";
    meta.recommendation = "Use yaml.safe_load() instead of yaml.load(), or specify Loader=yaml.SafeLoader";
    meta.tags = QStringList{"python", "deserialization"};
    meta.enabled = true;
    m_metadata["unsafe_yaml"] = meta;

    // 2. 不安全的 Pickle 反序列化
    m_patterns["unsafe_pickle"] = QRegularExpression("pickle\\.load\\s*\\(");
    meta = PatternMetadata();
    meta.name = "unsafe_pickle";
    meta.description = "Unsafe pickle deserialization from untrusted source";
    meta.severity = Severity::Critical;
    meta.cweId = "CWE-502";
    meta.recommendation = "Avoid using pickle with untrusted data. Consider JSON or other safe formats";
    meta.tags = QStringList{"python", "deserialization"};
    meta.enabled = true;
    m_metadata["unsafe_pickle"] = meta;

    // 3. PyTorch 不安全加载
    m_patterns["torch_unsafe"] = QRegularExpression("torch\\.load\\s*\\([^)]*weights_only\\s*=\\s*False");
    meta = PatternMetadata();
    meta.name = "torch_unsafe";
    meta.description = "Unsafe torch.load() with weights_only=False";
    meta.severity = Severity::Critical;
    meta.cweId = "CWE-502";
    meta.recommendation = "Use torch.load(..., weights_only=True) for untrusted models";
    meta.tags = QStringList{"python", "ml"};
    meta.enabled = true;
    m_metadata["torch_unsafe"] = meta;

    // 4. eval() 使用
    m_patterns["python_eval"] = QRegularExpression("\\beval\\s*\\(");
    meta = PatternMetadata();
    meta.name = "python_eval";
    meta.description = "Use of eval() can lead to code injection";
    meta.severity = Severity::Critical;
    meta.cweId = "CWE-95";
    meta.recommendation = "Avoid eval(). Use ast.literal_eval() for safe evaluation or parse manually";
    meta.tags = QStringList{"python", "injection"};
    meta.enabled = true;
    m_metadata["python_eval"] = meta;

    // 5. exec() 使用
    m_patterns["python_exec"] = QRegularExpression("\\bexec\\s*\\(");
    meta = PatternMetadata();
    meta.name = "python_exec";
    meta.description = "Use of exec() can lead to code injection";
    meta.severity = Severity::Critical;
    meta.cweId = "CWE-95";
    meta.recommendation = "Avoid exec(). Consider alternative approaches like importing modules";
    meta.tags = QStringList{"python", "injection"};
    meta.enabled = true;
    m_metadata["python_exec"] = meta;

    // 6. os.system() 使用
    m_patterns["os_system"] = QRegularExpression("os\\.system\\s*\\(");
    meta = PatternMetadata();
    meta.name = "os_system";
    meta.description = "os.system() vulnerable to command injection";
    meta.severity = Severity::Critical;
    meta.cweId = "CWE-78";
    meta.recommendation = "Use subprocess module with list arguments instead of os.system()";
    meta.tags = QStringList{"python", "command_injection"};
    meta.enabled = true;
    m_metadata["os_system"] = meta;

    // 7. subprocess shell=True
    m_patterns["subprocess_shell"] = QRegularExpression("subprocess\\.[^\\(]*\\([^)]*shell\\s*=\\s*True");
    meta = PatternMetadata();
    meta.name = "subprocess_shell";
    meta.description = "subprocess with shell=True vulnerable to command injection";
    meta.severity = Severity::Warning;
    meta.cweId = "CWE-78";
    meta.recommendation = "Use shell=False and pass command as list, or validate input carefully";
    meta.tags = QStringList{"python", "command_injection"};
    meta.enabled = true;
    m_metadata["subprocess_shell"] = meta;
}

void SecurityScanner::initJavaScriptPatterns()
{
    PatternMetadata meta;
    
    // 8. eval() 使用
    m_patterns["js_eval"] = QRegularExpression("\\beval\\s*\\(");
    meta = PatternMetadata();
    meta.name = "js_eval";
    meta.description = "Use of eval() can lead to code injection";
    meta.severity = Severity::Critical;
    meta.cweId = "CWE-95";
    meta.recommendation = "Avoid eval(). Use JSON.parse() for data or safer alternatives";
    meta.tags = QStringList{"javascript", "injection"};
    meta.enabled = true;
    m_metadata["js_eval"] = meta;

    // 9. innerHTML 赋值
    m_patterns["innerHTML"] = QRegularExpression("innerHTML\\s*=");
    meta = PatternMetadata();
    meta.name = "innerHTML";
    meta.description = "Direct innerHTML assignment can lead to XSS";
    meta.severity = Severity::Warning;
    meta.cweId = "CWE-79";
    meta.recommendation = "Use textContent for text, or sanitize HTML before assignment";
    meta.tags = QStringList{"javascript", "xss"};
    meta.enabled = true;
    m_metadata["innerHTML"] = meta;

    // 10. dangerouslySetInnerHTML (React)
    m_patterns["dangerouslySetInnerHTML"] = QRegularExpression("dangerouslySetInnerHTML");
    meta = PatternMetadata();
    meta.name = "dangerouslySetInnerHTML";
    meta.description = "dangerouslySetInnerHTML can lead to XSS if not sanitized";
    meta.severity = Severity::Warning;
    meta.cweId = "CWE-79";
    meta.recommendation = "Sanitize HTML content with DOMPurify before using dangerouslySetInnerHTML";
    meta.tags = QStringList{"react", "xss"};
    meta.enabled = true;
    m_metadata["dangerouslySetInnerHTML"] = meta;

    // 11. document.write
    m_patterns["document_write"] = QRegularExpression("document\\.write\\s*\\(");
    meta = PatternMetadata();
    meta.name = "document_write";
    meta.description = "document.write() is dangerous and deprecated";
    meta.severity = Severity::Warning;
    meta.cweId = "CWE-79";
    meta.recommendation = "Use DOM manipulation methods like appendChild() instead";
    meta.tags = QStringList{"javascript", "xss"};
    meta.enabled = true;
    m_metadata["document_write"] = meta;
}

void SecurityScanner::initShellPatterns()
{
    PatternMetadata meta;
    
    // 12. rm -rf 危险命令
    m_patterns["rm_rf"] = QRegularExpression("rm\\s+(-[a-z]*r[a-z]*f|--recursive\\s+--force)");
    meta = PatternMetadata();
    meta.name = "rm_rf";
    meta.description = "Potentially dangerous rm -rf command";
    meta.severity = Severity::Warning;
    meta.cweId = "CWE-78";
    meta.recommendation = "Double-check the target path before using rm -rf";
    meta.tags = QStringList{"shell", "dangerous_command"};
    meta.enabled = true;
    m_metadata["rm_rf"] = meta;

    // 13. curl | sh 危险管道
    m_patterns["curl_pipe_sh"] = QRegularExpression("(curl|wget)[^|]*\\|\\s*(sh|bash)");
    meta = PatternMetadata();
    meta.name = "curl_pipe_sh";
    meta.description = "Piping curl/wget to shell is dangerous";
    meta.severity = Severity::Warning;
    meta.cweId = "CWE-494";
    meta.recommendation = "Download script first, review it, then execute separately";
    meta.tags = QStringList{"shell", "dangerous_command"};
    meta.enabled = true;
    m_metadata["curl_pipe_sh"] = meta;
}

void SecurityScanner::initSecretPatterns()
{
    PatternMetadata meta;
    
    // 14. 硬编码 API 密钥
    m_patterns["hardcoded_api_key"] = QRegularExpression(
        "(api[_-]?key|api[_-]?secret|access[_-]?key)\\s*=\\s*['\\\"](?!\\$\\{)[a-zA-Z0-9_-]{20,}['\\\"]",
        QRegularExpression::CaseInsensitiveOption
    );
    meta = PatternMetadata();
    meta.name = "hardcoded_api_key";
    meta.description = "Potential hardcoded API key detected";
    meta.severity = Severity::Critical;
    meta.cweId = "CWE-798";
    meta.recommendation = "Use environment variables or secure secret management instead";
    meta.tags = QStringList{"secrets"};
    meta.enabled = true;
    m_metadata["hardcoded_api_key"] = meta;

    // 15. 硬编码密码
    m_patterns["hardcoded_password"] = QRegularExpression(
        "password\\s*=\\s*['\\\"](?!\\$\\{)[^'\\\"]{6,}['\\\"]",
        QRegularExpression::CaseInsensitiveOption
    );
    meta = PatternMetadata();
    meta.name = "hardcoded_password";
    meta.description = "Potential hardcoded password detected";
    meta.severity = Severity::Critical;
    meta.cweId = "CWE-798";
    meta.recommendation = "Use environment variables or secure credential storage";
    meta.tags = QStringList{"secrets"};
    meta.enabled = true;
    m_metadata["hardcoded_password"] = meta;

    // 16. AWS Access Key
    m_patterns["aws_access_key"] = QRegularExpression("AKIA[0-9A-Z]{16}");
    meta = PatternMetadata();
    meta.name = "aws_access_key";
    meta.description = "AWS Access Key detected";
    meta.severity = Severity::Critical;
    meta.cweId = "CWE-798";
    meta.recommendation = "Remove the key immediately and rotate credentials";
    meta.tags = QStringList{"secrets", "aws"};
    meta.enabled = true;
    m_metadata["aws_access_key"] = meta;
}

void SecurityScanner::initSQLPatterns()
{
    PatternMetadata meta;
    
    // 17. SQL 字符串拼接
    m_patterns["sql_concat"] = QRegularExpression(
        "(SELECT|INSERT|UPDATE|DELETE).*\\+.*['\\\"]",
        QRegularExpression::CaseInsensitiveOption
    );
    meta = PatternMetadata();
    meta.name = "sql_concat";
    meta.description = "Potential SQL injection via string concatenation";
    meta.severity = Severity::Critical;
    meta.cweId = "CWE-89";
    meta.recommendation = "Use parameterized queries or prepared statements";
    meta.tags = QStringList{"sql", "injection"};
    meta.enabled = true;
    m_metadata["sql_concat"] = meta;

    // 18. Python f-string 在 SQL
    m_patterns["sql_fstring"] = QRegularExpression(
        "f['\\\"]\\s*(SELECT|INSERT|UPDATE|DELETE)",
        QRegularExpression::CaseInsensitiveOption
    );
    meta = PatternMetadata();
    meta.name = "sql_fstring";
    meta.description = "Using f-string for SQL query can lead to SQL injection";
    meta.severity = Severity::Critical;
    meta.cweId = "CWE-89";
    meta.recommendation = "Use parameterized queries with placeholders";
    meta.tags = QStringList{"python", "sql", "injection"};
    meta.enabled = true;
    m_metadata["sql_fstring"] = meta;
}

void SecurityScanner::initXSSPatterns()
{
    PatternMetadata meta;
    
    // 19. v-html (Vue.js)
    m_patterns["vue_v_html"] = QRegularExpression("v-html\\s*=");
    meta = PatternMetadata();
    meta.name = "vue_v_html";
    meta.description = "v-html directive can lead to XSS if not sanitized";
    meta.severity = Severity::Warning;
    meta.cweId = "CWE-79";
    meta.recommendation = "Sanitize content before using v-html";
    meta.tags = QStringList{"vue", "xss"};
    meta.enabled = true;
    m_metadata["vue_v_html"] = meta;

    // 20. Angular bypassSecurityTrust
    m_patterns["angular_bypass"] = QRegularExpression("bypassSecurityTrust");
    meta = PatternMetadata();
    meta.name = "angular_bypass";
    meta.description = "Bypassing Angular security can lead to XSS";
    meta.severity = Severity::Warning;
    meta.cweId = "CWE-79";
    meta.recommendation = "Only bypass security for trusted content, sanitize user input";
    meta.tags = QStringList{"angular", "xss"};
    meta.enabled = true;
    m_metadata["angular_bypass"] = meta;
}

// ── 扫描辅助 ────────────────────────────────────────────────────────────────

QList<SecurityScanner::SecurityIssue> SecurityScanner::scanLines(const QStringList& lines, const QString& filePath)
{
    QList<SecurityIssue> issues;

    for (int lineNum = 0; lineNum < lines.size(); ++lineNum) {
        const QString& line = lines[lineNum];

        // 遍历所有模式
        for (auto it = m_patterns.begin(); it != m_patterns.end(); ++it) {
            const QString& patternName = it.key();
            const QRegularExpression& regex = it.value();

            // 检查模式是否启用
            if (m_metadata.contains(patternName) && !m_metadata[patternName].enabled) {
                continue;
            }

            // 匹配模式
            QRegularExpressionMatch match = regex.match(line);
            if (match.hasMatch()) {
                SecurityIssue issue;
                issue.filePath = filePath;
                issue.lineNumber = lineNum + 1;
                issue.pattern = patternName;
                issue.severity = getPatternSeverity(patternName);
                issue.message = getPatternMessage(patternName);
                issue.cweId = getPatternCWE(patternName);
                issue.recommendation = getPatternRecommendation(patternName);
                issue.matchedText = match.captured(0);

                // 检查严重程度阈值
                if (issue.severity >= m_severityThreshold) {
                    issues.append(issue);
                    emit issueFound(issue);
                }
            }
        }
    }

    return issues;
}

SecurityScanner::Severity SecurityScanner::getPatternSeverity(const QString& patternName) const
{
    if (m_metadata.contains(patternName)) {
        return m_metadata[patternName].severity;
    }
    return Severity::Warning;
}

QString SecurityScanner::getPatternMessage(const QString& patternName) const
{
    if (m_metadata.contains(patternName)) {
        return m_metadata[patternName].description;
    }
    return QString("Security issue detected: %1").arg(patternName);
}

QString SecurityScanner::getPatternCWE(const QString& patternName) const
{
    if (m_metadata.contains(patternName)) {
        return m_metadata[patternName].cweId;
    }
    return QString();
}

QString SecurityScanner::getPatternRecommendation(const QString& patternName) const
{
    if (m_metadata.contains(patternName)) {
        return m_metadata[patternName].recommendation;
    }
    return QString();
}

// ── 辅助函数实现 ────────────────────────────────────────────────────────────

QString severityToString(SecurityScanner::Severity severity)
{
    switch (severity) {
        case SecurityScanner::Severity::Info: return "Info";
        case SecurityScanner::Severity::Warning: return "Warning";
        case SecurityScanner::Severity::Critical: return "Critical";
        default: return "Unknown";
    }
}

QString severityToColor(SecurityScanner::Severity severity)
{
    switch (severity) {
        case SecurityScanner::Severity::Info: return "#0066CC";
        case SecurityScanner::Severity::Warning: return "#FFA500";
        case SecurityScanner::Severity::Critical: return "#CC0000";
        default: return "#808080";
    }
}
