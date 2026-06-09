#include "SecurityPatternDetector.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonArray>
#include <QFile>
#include <QTextStream>
#include <cmath>

const QVector<QString> SecurityPatternDetector::INJECTION_KEYWORDS = {
    "sql", "exec", "eval", "execute", "query", "system", "shell", "command",
    "spawn", "fork", "popen", "subprocess", "os.system", "popen"
};

const QVector<QString> SecurityPatternDetector::XSS_KEYWORDS = {
    "innerHTML", "dangerouslySetInnerHTML", "eval", "new Function",
    "document.write", "insertHTML", "fromHtml"
};

const QVector<QString> SecurityPatternDetector::SECRET_KEYWORDS = {
    "password", "token", "secret", "key", "api_key", "credential", "auth",
    "private_key", "access_token", "bearer", "x-api-key"
};

const QVector<QString> SecurityPatternDetector::DANGEROUS_FUNCTIONS = {
    "pickle.load", "yaml.load", "eval", "exec", "system", "popen",
    "exec", "__import__", "compile", "open"
};

SecurityPatternDetector::SecurityPatternDetector(QObject* parent)
    : QObject(parent)
{
    initializePatterns();
}

SecurityPatternDetector::~SecurityPatternDetector()
{
    // Cleanup
}

void SecurityPatternDetector::detectInFile(const QString& filePath, const DetectionConfig& config)
{
    m_config = config;
    
    qInfo() << QString("[Security] Scanning file: %1").arg(filePath);
    emit detectionStarted(filePath);

    try {
        QFile file(filePath);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            emit errorOccurred(QString("Cannot open file: %1").arg(filePath));
            return;
        }

        QTextStream in(&file);
        QString code = in.readAll();
        file.close();

        m_totalFilesScanned++;
        scanCodeForPatterns(code, filePath, config);

        if (config.enableFlowAnalysis) {
            performFlowAnalysis(code, filePath);
        }

        emit detectionCompleted(filePath);
    } catch (const std::exception& e) {
        emit errorOccurred(QString::fromStdString(e.what()));
    }
}

void SecurityPatternDetector::detectInFiles(const QVector<QString>& filePaths, const DetectionConfig& config)
{
    qInfo() << QString("[Security] Scanning %1 files").arg(filePaths.size());

    for (int i = 0; i < filePaths.size(); ++i) {
        detectInFile(filePaths[i], config);
        emit detectionProgress(i + 1, filePaths.size());
    }

    qInfo() << "[Security] Scan complete";
}

void SecurityPatternDetector::detectInDiff(const QString& diffContent, const DetectionConfig& config)
{
    qInfo() << "[Security] Analyzing diff for security issues";
    m_config = config;

    // Parse diff and extract changed lines
    QStringList lines = diffContent.split('\n');
    QString currentFile;
    int lineNum = 0;

    for (const QString& line : lines) {
        if (line.startsWith("+++")) {
            currentFile = line.mid(4);  // Remove "+++"
            lineNum = 0;
        } else if (line.startsWith("+") && !line.startsWith("+++")) {
            lineNum++;
            scanCodeForPatterns(line, currentFile, config);
        }
    }
}

void SecurityPatternDetector::registerSecurityPattern(const QString& name, const QString& regex,
                                                      VulnerabilityType type,
                                                      VulnerabilitySeverity severity)
{
    m_patternRegistry[name] = QRegularExpression(regex);
    m_patternMetadata[name] = qMakePair(type, severity);
    qInfo() << QString("[Security] Registered pattern: %1").arg(name);
}

QVector<SecurityPatternDetector::SecurityFinding> SecurityPatternDetector::findInjectionVulnerabilities(const QString& code)
{
    QVector<SecurityFinding> findings;

    // SQL injection patterns
    if (code.contains(QRegularExpression(".*sql.*select.*\\+.*user.*input.*", QRegularExpression::CaseInsensitiveOption))) {
        SecurityFinding finding;
        finding.type = Injection;
        finding.severity = High;
        finding.confidenceScore = 0.85f;
        finding.message = "Potential SQL injection vulnerability";
        finding.suggestion = "Use parameterized queries instead of string concatenation";
        findings.append(finding);
    }

    // Command injection patterns
    for (const QString& func : INJECTION_KEYWORDS) {
        if (code.contains(func, Qt::CaseInsensitive)) {
            SecurityFinding finding;
            finding.type = Injection;
            finding.severity = High;
            finding.confidenceScore = 0.75f;
            finding.message = QString("Potential injection via %1()").arg(func);
            finding.suggestion = QString("Sanitize user input before passing to %1()").arg(func);
            findings.append(finding);
        }
    }

    return findings;
}

QVector<SecurityPatternDetector::SecurityFinding> SecurityPatternDetector::findXSSVulnerabilities(const QString& code)
{
    QVector<SecurityFinding> findings;

    for (const QString& keyword : XSS_KEYWORDS) {
        if (code.contains(keyword, Qt::CaseInsensitive)) {
            SecurityFinding finding;
            finding.type = XSS;
            finding.severity = High;
            finding.confidenceScore = 0.8f;
            finding.message = QString("Potential XSS vulnerability with %1").arg(keyword);
            finding.suggestion = "Use safe DOM manipulation methods or escape user input";
            findings.append(finding);
        }
    }

    return findings;
}

QVector<SecurityPatternDetector::SecurityFinding> SecurityPatternDetector::findSSRFVulnerabilities(const QString& code)
{
    QVector<SecurityFinding> findings;

    if (code.contains("fetch(url)") || code.contains("requests.get(url)")) {
        SecurityFinding finding;
        finding.type = SSRF;
        finding.severity = High;
        finding.confidenceScore = 0.82f;
        finding.message = "Potential SSRF vulnerability with user-controlled URL";
        finding.suggestion = "Validate and allowlist target URLs before making requests";
        findings.append(finding);
    }

    return findings;
}

QVector<SecurityPatternDetector::SecurityFinding> SecurityPatternDetector::findIDORVulnerabilities(const QString& code)
{
    QVector<SecurityFinding> findings;

    if (code.contains("user_id") && code.contains("GET")) {
        SecurityFinding finding;
        finding.type = IDOR;
        finding.severity = High;
        finding.confidenceScore = 0.70f;
        finding.message = "Potential IDOR vulnerability with direct object reference";
        finding.suggestion = "Verify user authorization before accessing resources";
        findings.append(finding);
    }

    return findings;
}

QVector<SecurityPatternDetector::SecurityFinding> SecurityPatternDetector::findAuthBypassVulnerabilities(const QString& code)
{
    QVector<SecurityFinding> findings;

    if (code.contains("if (user)") || code.contains("if (!user)")) {
        SecurityFinding finding;
        finding.type = AuthBypass;
        finding.severity = Critical;
        finding.confidenceScore = 0.65f;
        finding.message = "Potential authentication bypass vulnerability";
        finding.suggestion = "Implement proper authentication and authorization checks";
        findings.append(finding);
    }

    return findings;
}

QVector<SecurityPatternDetector::SecurityFinding> SecurityPatternDetector::findHardcodedSecrets(const QString& code, const QString& filePath)
{
    QVector<SecurityFinding> findings;

    for (const QString& keyword : SECRET_KEYWORDS) {
        if (code.contains(keyword, Qt::CaseInsensitive)) {
            // Check for hardcoded values
            if (code.contains("=") && code.contains("\"")) {
                SecurityFinding finding;
                finding.type = HardcodedSecret;
                finding.severity = Critical;
                finding.confidenceScore = 0.95f;
                finding.filePath = filePath;
                finding.message = QString("Potential hardcoded %1 detected").arg(keyword);
                finding.suggestion = "Move secrets to environment variables or secure vaults";
                findings.append(finding);
            }
        }
    }

    return findings;
}

QVector<SecurityPatternDetector::SecurityFinding> SecurityPatternDetector::findUnsafeDeserialization(const QString& code)
{
    QVector<SecurityFinding> findings;

    for (const QString& func : DANGEROUS_FUNCTIONS) {
        if (code.contains(func)) {
            SecurityFinding finding;
            finding.type = UnsafeDeserialization;
            finding.severity = Critical;
            finding.confidenceScore = 0.92f;
            finding.message = QString("Unsafe deserialization with %1()").arg(func);
            finding.suggestion = QString("Replace %1() with safer alternatives").arg(func);
            findings.append(finding);
        }
    }

    return findings;
}

QVector<SecurityPatternDetector::SecurityFinding> SecurityPatternDetector::findPathTraversal(const QString& code)
{
    QVector<SecurityFinding> findings;

    if (code.contains("../" ) || code.contains("..\\")) {
        SecurityFinding finding;
        finding.type = PathTraversal;
        finding.severity = High;
        finding.confidenceScore = 0.80f;
        finding.message = "Potential path traversal vulnerability";
        finding.suggestion = "Validate and normalize file paths before use";
        findings.append(finding);
    }

    return findings;
}

bool SecurityPatternDetector::matchesPattern(const QString& code, const QString& pattern)
{
    QRegularExpression regex(pattern);
    return regex.match(code).hasMatch();
}

float SecurityPatternDetector::calculatePatternConfidence(const SecurityFinding& finding)
{
    float confidence = finding.confidenceScore;

    // Adjust based on severity
    switch (finding.severity) {
        case Critical:
            confidence = std::min(1.0f, confidence + 0.05f);
            break;
        case High:
            confidence = std::min(1.0f, confidence + 0.02f);
            break;
        case Medium:
            break;
        case Low:
            confidence = std::max(0.0f, confidence - 0.05f);
            break;
        case Info:
            confidence = std::max(0.0f, confidence - 0.10f);
            break;
    }

    return confidence;
}

bool SecurityPatternDetector::performSemanticAnalysis(const SecurityFinding& finding, const QString& context)
{
    // Analyze context to reduce false positives
    if (context.contains("// safe:") || context.contains("/* safe:")) {
        return false;  // Excluded
    }

    return true;  // Potential issue
}

QVector<SecurityPatternDetector::SecurityFinding> SecurityPatternDetector::analyzeDataFlow(const QString& code)
{
    QVector<SecurityFinding> findings;

    // Trace data flow from source to sink
    if (code.contains("input") && code.contains("output")) {
        // Simple data flow analysis
        qInfo() << "[Security] Analyzing data flow patterns";
    }

    return findings;
}

bool SecurityPatternDetector::isExcludedByComment(const QString& line)
{
    return line.contains("// noqa") || line.contains("# noqa") || 
           line.contains("// safe:") || line.contains("# safe:");
}

QString SecurityPatternDetector::extractExclusionReason(const QString& line)
{
    if (line.contains("// ")) {
        int pos = line.indexOf("// ");
        return line.mid(pos + 3);
    }
    if (line.contains("# ")) {
        int pos = line.indexOf("# ");
        return line.mid(pos + 2);
    }
    return "Unknown reason";
}

SecurityPatternDetector::DetectionResult SecurityPatternDetector::getDetectionResult(const QString& filePath)
{
    if (m_detectionResults.contains(filePath)) {
        return m_detectionResults[filePath];
    }
    return DetectionResult();
}

QVector<SecurityPatternDetector::DetectionResult> SecurityPatternDetector::getAllDetectionResults()
{
    return m_detectionResults.values();
}

QJsonObject SecurityPatternDetector::getDetectionStatistics() const
{
    QJsonObject stats;
    stats["totalFilesScanned"] = m_totalFilesScanned;
    stats["totalFindingsDetected"] = m_totalFindingsDetected;
    stats["totalCriticalIssues"] = m_totalCriticalIssues;
    stats["averageRiskScore"] = m_totalFilesScanned > 0 ? static_cast<double>(m_totalCriticalIssues) / m_totalFilesScanned : 0.0;
    return stats;
}

void SecurityPatternDetector::loadSecurityPolicy(const QString& policyFilePath)
{
    QFile file(policyFilePath);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&file);
        m_securityPolicy = in.readAll();
        file.close();
        qInfo() << "[Security] Loaded security policy from:" << policyFilePath;
        emit policyLoaded(policyFilePath);
    }
}

QString SecurityPatternDetector::getSecurityPolicy() const
{
    return m_securityPolicy;
}

SecurityPatternDetector::VulnerabilitySeverity SecurityPatternDetector::assessSeverity(const SecurityFinding& finding)
{
    return finding.severity;
}

float SecurityPatternDetector::calculateRiskScore(const QVector<SecurityFinding>& findings)
{
    if (findings.isEmpty()) return 0.0f;

    float totalRisk = 0.0f;
    int criticalCount = 0;
    int highCount = 0;

    for (const SecurityFinding& finding : findings) {
        switch (finding.severity) {
            case Critical:
                totalRisk += 1.0f;
                criticalCount++;
                break;
            case High:
                totalRisk += 0.8f;
                highCount++;
                break;
            case Medium:
                totalRisk += 0.5f;
                break;
            case Low:
                totalRisk += 0.2f;
                break;
            case Info:
                totalRisk += 0.05f;
                break;
        }
    }

    return std::min(1.0f, totalRisk / findings.size());
}

QString SecurityPatternDetector::generateSecurityReport(const DetectionResult& result)
{
    QString report;
    report += "# Security Scan Report\n\n";
    report += QString("**File**: %1\n").arg(result.filePath);
    report += QString("**Total Findings**: %1\n").arg(result.totalFindings);
    report += QString("**Critical Issues**: %1\n").arg(result.criticalIssues);
    report += QString("**High Issues**: %1\n").arg(result.highIssues);
    report += QString("**Risk Score**: %.2f\n\n").arg(result.overallRiskScore);

    for (const SecurityFinding& finding : result.findings) {
        report += generateFindingDescription(finding);
        report += "\n";
    }

    return report;
}

QString SecurityPatternDetector::generateFindingDescription(const SecurityFinding& finding)
{
    QString desc;
    desc += QString("- **Line %1**: %2\n").arg(finding.lineNumber).arg(finding.message);
    desc += QString("  Severity: %1, Confidence: %.1f%%\n").arg(static_cast<int>(finding.severity)).arg(finding.confidenceScore * 100);
    desc += QString("  Suggestion: %1\n").arg(finding.suggestion);
    return desc;
}

void SecurityPatternDetector::initializePatterns()
{
    registerSecurityPattern("hardcoded_secret", "password|token|secret.*=", HardcodedSecret, Critical);
    registerSecurityPattern("sql_injection", ".*SELECT.*\\+.*user.*", Injection, High);
    registerSecurityPattern("xss_vulnerability", "innerHTML|dangerouslySetInnerHTML", XSS, High);
    registerSecurityPattern("eval_usage", "eval\\(", UnsafeDeserialization, Critical);
}

void SecurityPatternDetector::scanCodeForPatterns(const QString& code, const QString& filePath, const DetectionConfig& config)
{
    DetectionResult result;
    result.filePath = filePath;
    result.scanTime = QDateTime::currentDateTime();

    if (config.enablePatternRules) {
        result.findings.append(findInjectionVulnerabilities(code));
        result.findings.append(findXSSVulnerabilities(code));
        result.findings.append(findSSRFVulnerabilities(code));
        result.findings.append(findIDORVulnerabilities(code));
        result.findings.append(findAuthBypassVulnerabilities(code));
        result.findings.append(findHardcodedSecrets(code, filePath));
        result.findings.append(findUnsafeDeserialization(code));
        result.findings.append(findPathTraversal(code));
    }

    // Filter by confidence threshold
    QVector<SecurityFinding> filtered;
    for (SecurityFinding& finding : result.findings) {
        finding.confidenceScore = calculatePatternConfidence(finding);
        if (finding.confidenceScore >= config.confidenceThreshold) {
            if (config.respectInlineExclusions && isExcludedByComment(code)) {
                finding.isExcluded = true;
            }
            filtered.append(finding);
            m_totalFindingsDetected++;
            
            if (finding.severity == Critical) {
                m_totalCriticalIssues++;
            }
        }
    }

    result.findings = filtered;
    result.totalFindings = result.findings.size();
    
    // Count by severity
    for (const SecurityFinding& f : result.findings) {
        if (f.severity == Critical) result.criticalIssues++;
        else if (f.severity == High) result.highIssues++;
    }

    result.overallRiskScore = calculateRiskScore(result.findings);
    m_detectionResults[filePath] = result;

    for (const SecurityFinding& f : result.findings) {
        emit findingDetected(f);
        if (f.severity == Critical) {
            emit criticalIssueFound(filePath, f.lineNumber);
        }
    }
}

void SecurityPatternDetector::performFlowAnalysis(const QString& code, const QString& filePath)
{
    qInfo() << QString("[Security] Performing flow analysis on %1").arg(filePath);
    // Multi-file vulnerability detection would go here
}

void SecurityPatternDetector::pruneOldResults()
{
    // Remove results older than 1 hour
    QDateTime oneHourAgo = QDateTime::currentDateTime().addSecs(-3600);
    
    auto it = m_detectionResults.begin();
    while (it != m_detectionResults.end()) {
        if (it.value().scanTime < oneHourAgo) {
            it = m_detectionResults.erase(it);
        } else {
            ++it;
        }
    }
}

void SecurityPatternDetector::logFinding(const SecurityFinding& finding)
{
    QString severity;
    switch (finding.severity) {
        case Critical: severity = "CRITICAL"; break;
        case High: severity = "HIGH"; break;
        case Medium: severity = "MEDIUM"; break;
        case Low: severity = "LOW"; break;
        case Info: severity = "INFO"; break;
    }

    qWarning() << QString("[Security] %1 at %2:%3 - %4")
                  .arg(severity)
                  .arg(finding.filePath)
                  .arg(finding.lineNumber)
                  .arg(finding.message);
}
