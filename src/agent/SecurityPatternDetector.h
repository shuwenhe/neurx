#pragma once

#include <QObject>
#include <QString>
#include <QMap>
#include <QVector>
#include <QJsonObject>
#include <QRegularExpression>
#include <QDateTime>

/**
 * @class SecurityPatternDetector
 * @brief Detects security vulnerabilities through pattern matching
 * 
 * Based on security-guidance plugin. Implements 3-layer security review:
 * 1. Pattern warnings (regex-based instant checks)
 * 2. Semantic analysis (context-aware detection)
 * 3. Flow analysis (multi-file vulnerabilities)
 */
class SecurityPatternDetector : public QObject {
    Q_OBJECT

public:
    explicit SecurityPatternDetector(QObject* parent = nullptr);
    ~SecurityPatternDetector();

    // Vulnerability severity
    enum VulnerabilitySeverity {
        Info,
        Low,
        Medium,
        High,
        Critical
    };

    // Vulnerability type
    enum VulnerabilityType {
        Injection,              // SQL, command, code injection
        XSS,                    // Cross-site scripting
        SSRF,                   // Server-side request forgery
        IDOR,                   // Insecure direct object reference
        AuthBypass,             // Authentication bypass
        HardcodedSecret,        // Hardcoded credentials/tokens
        UnsafeDeserialization,  // pickle.load, yaml.load, etc.
        PathTraversal,          // Directory traversal
        CSRF,                   // Cross-site request forgery
        WeakCrypto,             // Weak cryptographic practices
        MemoryUnsafe,           // Memory safety issues
        RaceCondition           // Race conditions
    };

    // Security finding
    struct SecurityFinding {
        int id;
        QString filePath;
        int lineNumber;
        int columnNumber;
        VulnerabilityType type;
        VulnerabilitySeverity severity;
        float confidenceScore;  // 0.0-1.0
        QString pattern;
        QString message;
        QString suggestion;
        bool isExcluded;        // Excluded by inline comment
        QDateTime detectedAt;
    };

    // Detection configuration
    struct DetectionConfig {
        bool enablePatternRules = true;
        bool enableSemanticAnalysis = true;
        bool enableFlowAnalysis = true;
        float confidenceThreshold = 0.7f;
        bool includeInfoLevel = false;
        int maxFindingsPerFile = 50;
        bool respectInlineExclusions = true;
        QString organizationSecurityPolicy;  // Path to security-guidance.md
    };

    // Detection result
    struct DetectionResult {
        QString filePath;
        int totalFindings = 0;
        int criticalIssues = 0;
        int highIssues = 0;
        int mediumIssues = 0;
        QVector<SecurityFinding> findings;
        float overallRiskScore;  // 0.0-1.0
        QDateTime scanTime;
    };

    // Start detection
    void detectInFile(const QString& filePath, const DetectionConfig& config);
    void detectInFiles(const QVector<QString>& filePaths, const DetectionConfig& config);
    void detectInDiff(const QString& diffContent, const DetectionConfig& config);
    
    // Pattern management
    void registerSecurityPattern(const QString& name, const QString& regex, 
                                 VulnerabilityType type, VulnerabilitySeverity severity);
    
    // Vulnerability detection
    QVector<SecurityFinding> findInjectionVulnerabilities(const QString& code);
    QVector<SecurityFinding> findXSSVulnerabilities(const QString& code);
    QVector<SecurityFinding> findSSRFVulnerabilities(const QString& code);
    QVector<SecurityFinding> findIDORVulnerabilities(const QString& code);
    QVector<SecurityFinding> findAuthBypassVulnerabilities(const QString& code);
    QVector<SecurityFinding> findHardcodedSecrets(const QString& code, const QString& filePath);
    QVector<SecurityFinding> findUnsafeDeserialization(const QString& code);
    QVector<SecurityFinding> findPathTraversal(const QString& code);
    
    // Pattern matching
    bool matchesPattern(const QString& code, const QString& pattern);
    float calculatePatternConfidence(const SecurityFinding& finding);
    
    // Semantic analysis
    bool performSemanticAnalysis(const SecurityFinding& finding, const QString& context);
    QVector<SecurityFinding> analyzeDataFlow(const QString& code);
    
    // Inline exclusion support
    bool isExcludedByComment(const QString& line);
    QString extractExclusionReason(const QString& line);
    
    // Results management
    DetectionResult getDetectionResult(const QString& filePath);
    QVector<DetectionResult> getAllDetectionResults();
    QJsonObject getDetectionStatistics() const;
    
    // Policy management
    void loadSecurityPolicy(const QString& policyFilePath);
    QString getSecurityPolicy() const;
    
    // Severity assessment
    VulnerabilitySeverity assessSeverity(const SecurityFinding& finding);
    float calculateRiskScore(const QVector<SecurityFinding>& findings);
    
    // Report generation
    QString generateSecurityReport(const DetectionResult& result);
    QString generateFindingDescription(const SecurityFinding& finding);

signals:
    void detectionStarted(const QString& filePath);
    void detectionCompleted(const QString& filePath);
    void findingDetected(const SecurityFinding& finding);
    void criticalIssueFound(const QString& filePath, int lineNumber);
    void detectionProgress(int processed, int total);
    void policyLoaded(const QString& policyName);
    void errorOccurred(const QString& error);

private:
    // Configuration
    DetectionConfig m_config;
    
    // Pattern registry
    QMap<QString, QRegularExpression> m_patternRegistry;
    QMap<QString, QPair<VulnerabilityType, VulnerabilitySeverity>> m_patternMetadata;
    
    // Results cache
    QMap<QString, DetectionResult> m_detectionResults;
    
    // Statistics
    int m_totalFilesScanned = 0;
    int m_totalFindingsDetected = 0;
    int m_totalCriticalIssues = 0;
    
    // Security policy
    QString m_securityPolicy;
    
    // Predefined pattern keywords
    static const QVector<QString> INJECTION_KEYWORDS;
    static const QVector<QString> XSS_KEYWORDS;
    static const QVector<QString> SECRET_KEYWORDS;
    static const QVector<QString> DANGEROUS_FUNCTIONS;

    // Helper methods
    void initializePatterns();
    void scanCodeForPatterns(const QString& code, const QString& filePath, const DetectionConfig& config);
    void performFlowAnalysis(const QString& code, const QString& filePath);
    void pruneOldResults();
    void logFinding(const SecurityFinding& finding);
};
