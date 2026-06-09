#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <memory>
#include <vector>

/**
 * @class SecurityAnalyzer
 * @brief Comprehensive code security analysis
 * 
 * Features:
 * - Pattern-based vulnerability detection
 * - OWASP compliance checking
 * - Dependency vulnerability scanning
 * - Credential and secret detection
 * - CWE mapping and reporting
 * - Security best practices enforcement
 * - Risk scoring and prioritization
 */

class SecurityAnalyzer : public QObject {
    Q_OBJECT

public:
    enum VulnerabilityType {
        SQLInjection,
        XSS,
        CommandInjection,
        PathTraversal,
        CryptographicWeakness,
        HardcodedCredentials,
        UnsafeDeserialization,
        XMLExternalEntity,
        BrokenAuthentication,
        BrokenAuthorization,
        InsecureDirectObjectRef,
        SecurityMisconfiguration,
        DependencyVulnerabilityFinding,
        Other
    };

    enum Severity {
        Info,
        Low,
        Medium,
        High,
        Critical
    };

    struct SecurityFinding {
        QString id;
        QString file;
        int lineNumber;
        int columnNumber;
        VulnerabilityType type;
        Severity severity;
        QString cweId;  // CWE-xxx
        QString description;
        QString recommendation;
        QString codeSnippet;
        float riskScore;  // 0-100
        QStringList relatedCWEs;
        bool confirmed;
    };

    struct SecurityScanResult {
        QString scanId;
        qint64 timestamp;
        QVector<SecurityFinding> findings;
        int totalFindings;
        int criticalCount;
        int highCount;
        int mediumCount;
        float overallRiskScore;
        QString summary;
        QJsonObject metadata;
        qint64 scanDurationMs;
    };

    struct DependencyVulnerability {
        QString packageName;
        QString packageVersion;
        QString vulnerableVersionRange;
        QString fixedVersion;
        QString cveId;
        Severity severity;
        QString description;
        QString url;
    };

    explicit SecurityAnalyzer(QObject* parent = nullptr);
    ~SecurityAnalyzer();

    // Main scanning operations
    SecurityScanResult scanFiles(const QStringList& files, bool recursive = false);
    SecurityScanResult scanDirectory(const QString& dirPath);
    SecurityScanResult scanCode(const QString& code, const QString& language);

    // Vulnerability detection
    QVector<SecurityFinding> detectSQLInjection(const QStringList& files);
    QVector<SecurityFinding> detectXSS(const QStringList& files);
    QVector<SecurityFinding> detectCommandInjection(const QStringList& files);
    QVector<SecurityFinding> detectPathTraversal(const QStringList& files);
    QVector<SecurityFinding> detectHardcodedCredentials(const QStringList& files);
    QVector<SecurityFinding> detectCryptographicWeakness(const QStringList& files);
    QVector<SecurityFinding> detectUnsafeDeserialization(const QStringList& files);
    QVector<SecurityFinding> detectXXE(const QStringList& files);

    // Dependency analysis
    QVector<DependencyVulnerability> scanDependencies(const QString& packageFilePath);
    QVector<DependencyVulnerability> checkPackageVulnerabilities(const QString& packageName, 
                                                               const QString& version);
    bool updateVulnerabilityDatabase();
    QString getLatestSecureVersion(const QString& packageName);

    // Credential detection
    QVector<SecurityFinding> detectCredentials(const QStringList& files);
    QVector<SecurityFinding> detectAPIKeys(const QStringList& files);
    QVector<SecurityFinding> detectPrivateKeys(const QStringList& files);
    QVector<SecurityFinding> detectDatabaseCredentials(const QStringList& files);
    QVector<SecurityFinding> detectAuthTokens(const QStringList& files);

    // OWASP Top 10 checking
    QVector<SecurityFinding> checkOWASPCompliance(const QStringList& files);
    QVector<SecurityFinding> checkOWASPInjection(const QStringList& files);
    QVector<SecurityFinding> checkBrokenAuthentication(const QStringList& files);
    QVector<SecurityFinding> checkSensitiveDataExposure(const QStringList& files);
    QVector<SecurityFinding> checkXML(const QStringList& files);
    QVector<SecurityFinding> checkAccessControl(const QStringList& files);

    // CWE mapping
    QString getCWEDescription(const QString& cweId);
    QVector<SecurityFinding> findingsByCWE(const QString& cweId);
    QJsonObject getCWEMetadata(const QString& cweId);

    // Pattern-based detection
    void registerCustomSecurityPattern(const QString& patternId, const QString& regex,
                                      VulnerabilityType type, Severity severity,
                                      const QString& description);
    void removeCustomPattern(const QString& patternId);
    QVector<SecurityFinding> scanWithPattern(const QStringList& files, 
                                            const QString& patternId);

    // Filtering and analysis
    QVector<SecurityFinding> filterBySeverity(const QVector<SecurityFinding>& findings,
                                             Severity minLevel);
    QVector<SecurityFinding> filterByType(const QVector<SecurityFinding>& findings,
                                         VulnerabilityType type);
    QVector<SecurityFinding> deduplicateFindings(const QVector<SecurityFinding>& findings);

    // Remediation suggestions
    QString getRemediationCode(const SecurityFinding& finding);
    QString generateRemediationReport(const SecurityScanResult& result);
    QJsonArray generateRemediationPlan(const SecurityScanResult& result);

    // Configuration
    void setSeverityThreshold(Severity threshold);
    void enablePattern(const QString& patternId);
    void disablePattern(const QString& patternId);
    void setCustomRuleFile(const QString& filePath);
    void loadRulesFromFile(const QString& filePath);
    void setExcludePatterns(const QStringList& patterns);

    // Reporting
    QString generateHTMLReport(const SecurityScanResult& result);
    QString generateMarkdownReport(const SecurityScanResult& result);
    QJsonObject exportScanJSON(const SecurityScanResult& result);
    void sendToSIEM(const SecurityScanResult& result, const QString& endpoint);

    // History and tracking
    SecurityScanResult getScanHistory(const QString& scanId);
    QVector<SecurityScanResult> listScans(int limit = 100);
    QVector<SecurityFinding> getRecentFindings(int days = 7);

    // Statistics
    struct SecurityStats {
        int totalScansRun;
        int totalFindingsDiscovered;
        QMap<VulnerabilityType, int> findingsByType;
        QMap<Severity, int> findingsBySeverity;
        float averageRiskScore;
        int dependenciesScanned;
        int vulnerableDependencies;
    };
    SecurityStats getStatistics() const;

    // Remediation tracking
    bool markFindingAsResolved(const QString& findingId);
    bool markFindingAsFalsePositive(const QString& findingId);
    int getResolvedFindingsCount();
    int getFalsePositiveCount();

signals:
    void scanStarted(const QString& scanId);
    void scanProgress(int processed, int total);
    void findingDiscovered(const SecurityFinding& finding);
    void scanCompleted(const SecurityScanResult& result);
    void scanFailed(const QString& error);
    void vulnerabilityDetected(const DependencyVulnerability& vuln);

private:
    struct SecurityPattern {
        QString id;
        QString regex;
        VulnerabilityType type;
        Severity severity;
        QString description;
        bool enabled;
    };

    std::vector<SecurityPattern> m_customPatterns;
    QMap<QString, SecurityScanResult> m_scanHistory;
    Severity m_severityThreshold;
    SecurityStats m_statistics;
    QStringList m_excludePatterns;

    QString m_currentScanId;
    int m_scanProgress;

    QString generateUniqueScanId();
    bool matchesExcludePattern(const QString& filePath);
};
