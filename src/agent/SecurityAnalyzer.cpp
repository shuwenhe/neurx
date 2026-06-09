#include "SecurityAnalyzer.h"
#include <QDebug>
#include <QFile>
#include <QDir>
#include <QRegularExpression>
#include <QJsonDocument>
#include <QJsonArray>
#include <QUuid>
#include <algorithm>

SecurityAnalyzer::SecurityAnalyzer(QObject* parent)
    : QObject(parent),
      m_severityThreshold(Info),
      m_currentScanId(""),
      m_scanProgress(0)
{
    m_statistics.totalScansRun = 0;
    m_statistics.totalFindingsDiscovered = 0;
    m_statistics.averageRiskScore = 0.0f;
    m_statistics.dependenciesScanned = 0;
    m_statistics.vulnerableDependencies = 0;
}

SecurityAnalyzer::~SecurityAnalyzer() = default;

SecurityAnalyzer::SecurityScanResult SecurityAnalyzer::scanFiles(const QStringList& files, bool recursive)
{
    m_currentScanId = generateUniqueScanId();
    m_scanProgress = 0;

    emit scanStarted(m_currentScanId);

    QVector<SecurityFinding> findings;
    int processed = 0;

    for (const auto& file : files) {
        if (matchesExcludePattern(file)) {
            processed++;
            continue;
        }

        // Scan for SQL injection
        auto sqlIssues = detectSQLInjection({file});
        findings.append(sqlIssues);

        // Scan for XSS
        auto xssIssues = detectXSS({file});
        findings.append(xssIssues);

        // Scan for command injection
        auto cmdIssues = detectCommandInjection({file});
        findings.append(cmdIssues);

        // Scan for credentials
        auto credIssues = detectCredentials({file});
        findings.append(credIssues);

        processed++;
        m_scanProgress = (processed * 100) / files.length();
        emit scanProgress(processed, files.length());
    }

    // Compile results
    SecurityScanResult result;
    result.scanId = m_currentScanId;
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    result.findings = findings;
    result.totalFindings = findings.length();

    result.criticalCount = 0;
    result.highCount = 0;
    result.mediumCount = 0;

    for (const auto& finding : findings) {
        if (finding.severity == Critical) result.criticalCount++;
        else if (finding.severity == High) result.highCount++;
        else if (finding.severity == Medium) result.mediumCount++;

        m_statistics.findingsBySeverity[finding.severity]++;
        m_statistics.findingsByType[finding.type]++;
    }

    result.overallRiskScore = result.criticalCount * 25 + result.highCount * 10 + result.mediumCount * 5;
    result.summary = QString("Scan found %1 findings").arg(result.totalFindings);
    result.scanDurationMs = 0;

    m_statistics.totalScansRun++;
    m_statistics.totalFindingsDiscovered += findings.length();
    m_scanHistory[m_currentScanId] = result;

    emit scanCompleted(result);

    return result;
}

SecurityAnalyzer::SecurityScanResult SecurityAnalyzer::scanDirectory(const QString& dirPath)
{
    QStringList files;
    QDir dir(dirPath);
    QStringList filters;
    filters << "*.cpp" << "*.h" << "*.js" << "*.ts" << "*.py" << "*.java";
    
    dir.setNameFilters(filters);
    QFileInfoList fileList = dir.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);

    for (const auto& fileInfo : fileList) {
        if (fileInfo.isDir()) {
            auto result = scanDirectory(fileInfo.filePath());
            files.append(result.metadata["scannedFiles"].toVariant().toString());
        } else {
            files.append(fileInfo.filePath());
        }
    }

    return scanFiles(files);
}

SecurityAnalyzer::SecurityScanResult SecurityAnalyzer::scanCode(const QString& code, const QString& language)
{
    QStringList codeLines = code.split('\n');
    QVector<SecurityFinding> findings;

    // Pattern-based analysis
    for (const auto& pattern : m_customPatterns) {
        if (!pattern.enabled) continue;

        QRegularExpression regex(pattern.regex);
        for (int i = 0; i < codeLines.length(); i++) {
            if (regex.match(codeLines[i]).hasMatch()) {
                SecurityFinding finding;
                finding.id = QUuid::createUuid().toString();
                finding.file = "inline";
                finding.lineNumber = i + 1;
                finding.type = pattern.type;
                finding.severity = pattern.severity;
                finding.description = pattern.description;
                finding.riskScore = static_cast<float>(pattern.severity) * 20;
                findings.append(finding);
            }
        }
    }

    SecurityScanResult result;
    result.scanId = generateUniqueScanId();
    result.timestamp = QDateTime::currentMSecsSinceEpoch();
    result.findings = findings;
    result.totalFindings = findings.length();

    return result;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::detectSQLInjection(const QStringList& files)
{
    QVector<SecurityFinding> findings;

    QRegularExpression sqlPattern(
        "query\\s*\\(\\s*['\"].*\\$|concat\\s*\\(|format\\s*\\(.*query",
        QRegularExpression::CaseInsensitiveOption
    );

    for (const auto& file : files) {
        QFile qfile(file);
        if (!qfile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }

        int lineNum = 0;
        while (!qfile.atEnd()) {
            QString line = qfile.readLine();
            lineNum++;

            if (sqlPattern.match(line).hasMatch()) {
                SecurityFinding finding;
                finding.id = QUuid::createUuid().toString();
                finding.file = file;
                finding.lineNumber = lineNum;
                finding.type = SQLInjection;
                finding.severity = Critical;
                finding.cweId = "CWE-89";
                finding.description = "Potential SQL injection vulnerability";
                finding.riskScore = 95.0f;
                findings.append(finding);
            }
        }

        qfile.close();
    }

    return findings;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::detectXSS(const QStringList& files)
{
    QVector<SecurityFinding> findings;

    QRegularExpression xssPattern(
        "innerHTML|dangerouslySetInnerHTML|eval\\s*\\(|Function\\s*\\(",
        QRegularExpression::CaseInsensitiveOption
    );

    for (const auto& file : files) {
        QFile qfile(file);
        if (!qfile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }

        int lineNum = 0;
        while (!qfile.atEnd()) {
            QString line = qfile.readLine();
            lineNum++;

            if (xssPattern.match(line).hasMatch()) {
                SecurityFinding finding;
                finding.id = QUuid::createUuid().toString();
                finding.file = file;
                finding.lineNumber = lineNum;
                finding.type = XSS;
                finding.severity = High;
                finding.cweId = "CWE-79";
                finding.description = "Potential XSS vulnerability";
                finding.riskScore = 85.0f;
                findings.append(finding);
            }
        }

        qfile.close();
    }

    return findings;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::detectCommandInjection(const QStringList& files)
{
    QVector<SecurityFinding> findings;

    QRegularExpression cmdPattern(
        "exec\\s*\\(|system\\s*\\(|popen\\s*\\(|shell=True|bash|sh -c",
        QRegularExpression::CaseInsensitiveOption
    );

    for (const auto& file : files) {
        QFile qfile(file);
        if (!qfile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }

        int lineNum = 0;
        while (!qfile.atEnd()) {
            QString line = qfile.readLine();
            lineNum++;

            if (cmdPattern.match(line).hasMatch()) {
                SecurityFinding finding;
                finding.id = QUuid::createUuid().toString();
                finding.file = file;
                finding.lineNumber = lineNum;
                finding.type = CommandInjection;
                finding.severity = Critical;
                finding.cweId = "CWE-78";
                finding.description = "Potential command injection vulnerability";
                finding.riskScore = 90.0f;
                findings.append(finding);
            }
        }

        qfile.close();
    }

    return findings;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::detectPathTraversal(const QStringList& files)
{
    QVector<SecurityFinding> findings;
    return findings;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::detectHardcodedCredentials(const QStringList& files)
{
    QVector<SecurityFinding> findings;

    QRegularExpression credPattern(
        "password\\s*=|api[_-]?key|secret|token|aws[_-]?key|private[_-]?key",
        QRegularExpression::CaseInsensitiveOption
    );

    for (const auto& file : files) {
        QFile qfile(file);
        if (!qfile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }

        int lineNum = 0;
        while (!qfile.atEnd()) {
            QString line = qfile.readLine();
            lineNum++;

            if (credPattern.match(line).hasMatch()) {
                SecurityFinding finding;
                finding.id = QUuid::createUuid().toString();
                finding.file = file;
                finding.lineNumber = lineNum;
                finding.type = HardcodedCredentials;
                finding.severity = Critical;
                finding.cweId = "CWE-798";
                finding.description = "Hardcoded credentials detected";
                finding.riskScore = 100.0f;
                findings.append(finding);
            }
        }

        qfile.close();
    }

    return findings;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::detectCryptographicWeakness(const QStringList& files)
{
    QVector<SecurityFinding> findings;
    return findings;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::detectUnsafeDeserialization(const QStringList& files)
{
    QVector<SecurityFinding> findings;

    QRegularExpression dePattern("pickle|deserialize|Deserialize", QRegularExpression::CaseInsensitiveOption);

    for (const auto& file : files) {
        QFile qfile(file);
        if (!qfile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }

        int lineNum = 0;
        while (!qfile.atEnd()) {
            QString line = qfile.readLine();
            lineNum++;

            if (dePattern.match(line).hasMatch()) {
                SecurityFinding finding;
                finding.id = QUuid::createUuid().toString();
                finding.file = file;
                finding.lineNumber = lineNum;
                finding.type = UnsafeDeserialization;
                finding.severity = High;
                finding.cweId = "CWE-502";
                finding.description = "Unsafe deserialization detected";
                finding.riskScore = 80.0f;
                findings.append(finding);
            }
        }

        qfile.close();
    }

    return findings;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::detectXXE(const QStringList& files)
{
    QVector<SecurityFinding> findings;
    return findings;
}

QVector<SecurityAnalyzer::DependencyVulnerability> SecurityAnalyzer::scanDependencies(const QString& packageFilePath)
{
    QVector<DependencyVulnerability> vulnerabilities;
    m_statistics.dependenciesScanned++;
    return vulnerabilities;
}

QVector<SecurityAnalyzer::DependencyVulnerability> SecurityAnalyzer::checkPackageVulnerabilities(
    const QString& packageName, const QString& version)
{
    QVector<DependencyVulnerability> vulnerabilities;
    return vulnerabilities;
}

bool SecurityAnalyzer::updateVulnerabilityDatabase()
{
    return true;
}

QString SecurityAnalyzer::getLatestSecureVersion(const QString& packageName)
{
    return "1.0.0";
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::detectCredentials(const QStringList& files)
{
    return detectHardcodedCredentials(files);
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::detectAPIKeys(const QStringList& files)
{
    QVector<SecurityFinding> findings;
    return findings;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::detectPrivateKeys(const QStringList& files)
{
    QVector<SecurityFinding> findings;
    return findings;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::detectDatabaseCredentials(const QStringList& files)
{
    QVector<SecurityFinding> findings;
    return findings;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::detectAuthTokens(const QStringList& files)
{
    QVector<SecurityFinding> findings;
    return findings;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::checkOWASPCompliance(const QStringList& files)
{
    QVector<SecurityFinding> findings;
    findings.append(detectSQLInjection(files));
    findings.append(detectXSS(files));
    findings.append(detectCommandInjection(files));
    return findings;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::checkOWASPInjection(const QStringList& files)
{
    QVector<SecurityFinding> findings;
    return findings;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::checkBrokenAuthentication(const QStringList& files)
{
    QVector<SecurityFinding> findings;
    return findings;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::checkSensitiveDataExposure(const QStringList& files)
{
    QVector<SecurityFinding> findings;
    return findings;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::checkXML(const QStringList& files)
{
    QVector<SecurityFinding> findings;
    return findings;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::checkAccessControl(const QStringList& files)
{
    QVector<SecurityFinding> findings;
    return findings;
}

QString SecurityAnalyzer::getCWEDescription(const QString& cweId)
{
    return "CWE Description";
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::findingsByCWE(const QString& cweId)
{
    QVector<SecurityFinding> findings;
    return findings;
}

QJsonObject SecurityAnalyzer::getCWEMetadata(const QString& cweId)
{
    QJsonObject metadata;
    return metadata;
}

void SecurityAnalyzer::registerCustomSecurityPattern(const QString& patternId, const QString& regex,
                                                    VulnerabilityType type, Severity severity,
                                                    const QString& description)
{
    SecurityPattern pattern;
    pattern.id = patternId;
    pattern.regex = regex;
    pattern.type = type;
    pattern.severity = severity;
    pattern.description = description;
    pattern.enabled = true;

    m_customPatterns.push_back(pattern);
}

void SecurityAnalyzer::removeCustomPattern(const QString& patternId)
{
    auto it = std::find_if(m_customPatterns.begin(), m_customPatterns.end(),
                          [&](const SecurityPattern& p) { return p.id == patternId; });
    if (it != m_customPatterns.end()) {
        m_customPatterns.erase(it);
    }
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::scanWithPattern(const QStringList& files,
                                                                           const QString& patternId)
{
    QVector<SecurityFinding> findings;
    return findings;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::filterBySeverity(
    const QVector<SecurityFinding>& findings, Severity minLevel)
{
    QVector<SecurityFinding> filtered;
    for (const auto& finding : findings) {
        if (finding.severity >= minLevel) {
            filtered.append(finding);
        }
    }
    return filtered;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::filterByType(
    const QVector<SecurityFinding>& findings, VulnerabilityType type)
{
    QVector<SecurityFinding> filtered;
    for (const auto& finding : findings) {
        if (finding.type == type) {
            filtered.append(finding);
        }
    }
    return filtered;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::deduplicateFindings(
    const QVector<SecurityFinding>& findings)
{
    QMap<QString, SecurityFinding> deduped;
    for (const auto& finding : findings) {
        QString key = finding.file + ":" + QString::number(finding.lineNumber);
        if (!deduped.contains(key)) {
            deduped[key] = finding;
        }
    }
    return deduped.values().toVector();
}

QString SecurityAnalyzer::getRemediationCode(const SecurityFinding& finding)
{
    return "// Remediation code here";
}

QString SecurityAnalyzer::generateRemediationReport(const SecurityScanResult& result)
{
    return "Remediation Report";
}

QJsonArray SecurityAnalyzer::generateRemediationPlan(const SecurityScanResult& result)
{
    QJsonArray plan;
    return plan;
}

void SecurityAnalyzer::setSeverityThreshold(Severity threshold)
{
    m_severityThreshold = threshold;
}

void SecurityAnalyzer::enablePattern(const QString& patternId)
{
    for (auto& pattern : m_customPatterns) {
        if (pattern.id == patternId) {
            pattern.enabled = true;
            break;
        }
    }
}

void SecurityAnalyzer::disablePattern(const QString& patternId)
{
    for (auto& pattern : m_customPatterns) {
        if (pattern.id == patternId) {
            pattern.enabled = false;
            break;
        }
    }
}

void SecurityAnalyzer::setCustomRuleFile(const QString& filePath)
{
    loadRulesFromFile(filePath);
}

void SecurityAnalyzer::loadRulesFromFile(const QString& filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    if (doc.isArray()) {
        QJsonArray rules = doc.array();
        for (const auto& rule : rules) {
            if (rule.isObject()) {
                QJsonObject ruleObj = rule.toObject();
                registerCustomSecurityPattern(
                    ruleObj["id"].toString(),
                    ruleObj["regex"].toString(),
                    static_cast<VulnerabilityType>(ruleObj["type"].toInt()),
                    static_cast<Severity>(ruleObj["severity"].toInt()),
                    ruleObj["description"].toString()
                );
            }
        }
    }

    file.close();
}

void SecurityAnalyzer::setExcludePatterns(const QStringList& patterns)
{
    m_excludePatterns = patterns;
}

QString SecurityAnalyzer::generateHTMLReport(const SecurityScanResult& result)
{
    QString html = "<html><body>";
    html += "<h1>Security Scan Report</h1>";
    html += "<p>Risk Score: " + QString::number(result.overallRiskScore) + "</p>";
    html += "</body></html>";
    return html;
}

QString SecurityAnalyzer::generateMarkdownReport(const SecurityScanResult& result)
{
    QString md = "# Security Scan Report\n\n";
    md += "**Risk Score:** " + QString::number(result.overallRiskScore) + "\n";
    md += "**Total Findings:** " + QString::number(result.totalFindings) + "\n";
    return md;
}

QJsonObject SecurityAnalyzer::exportScanJSON(const SecurityScanResult& result)
{
    QJsonObject obj;
    obj["scanId"] = result.scanId;
    obj["totalFindings"] = result.totalFindings;
    obj["overallRiskScore"] = result.overallRiskScore;
    return obj;
}

void SecurityAnalyzer::sendToSIEM(const SecurityScanResult& result, const QString& endpoint)
{
    // SIEM integration
}

SecurityAnalyzer::SecurityScanResult SecurityAnalyzer::getScanHistory(const QString& scanId)
{
    return m_scanHistory.value(scanId, SecurityScanResult());
}

QVector<SecurityAnalyzer::SecurityScanResult> SecurityAnalyzer::listScans(int limit)
{
    QVector<SecurityScanResult> scans;
    int count = 0;
    for (const auto& scan : m_scanHistory) {
        if (count >= limit) break;
        scans.append(scan);
        count++;
    }
    return scans;
}

QVector<SecurityAnalyzer::SecurityFinding> SecurityAnalyzer::getRecentFindings(int days)
{
    QVector<SecurityFinding> findings;
    return findings;
}

SecurityAnalyzer::SecurityStats SecurityAnalyzer::getStatistics() const
{
    return m_statistics;
}

bool SecurityAnalyzer::markFindingAsResolved(const QString& findingId)
{
    return true;
}

bool SecurityAnalyzer::markFindingAsFalsePositive(const QString& findingId)
{
    return true;
}

int SecurityAnalyzer::getResolvedFindingsCount()
{
    return 0;
}

int SecurityAnalyzer::getFalsePositiveCount()
{
    return 0;
}

QString SecurityAnalyzer::generateUniqueScanId()
{
    return QUuid::createUuid().toString();
}

bool SecurityAnalyzer::matchesExcludePattern(const QString& filePath)
{
    for (const auto& pattern : m_excludePatterns) {
        QRegularExpression regex(pattern);
        if (regex.match(filePath).hasMatch()) {
            return true;
        }
    }
    return false;
}
