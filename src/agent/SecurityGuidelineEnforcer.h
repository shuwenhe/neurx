#pragma once

#include <QString>
#include <QObject>
#include <QRegularExpression>
#include <memory>
#include <vector>

/**
 * @class SecurityGuidelineEnforcer
 * @brief Security pattern detection and enforcement
 */

class SecurityGuidelineEnforcer : public QObject {
    Q_OBJECT

public:
    enum SecurityIssueType {
        CommandInjection,
        CrossSiteScripting,
        EvalUsage,
        DangerousHTML,
        PickleDeserialization,
        SystemCall,
        SQLInjection,
        PathTraversal,
        UnsafeDeserialization,
        InsecureCrypto
    };

    struct SecurityPattern {
        SecurityIssueType type;
        QString pattern;
        QString description;
        QString remediation;
        bool isRegex;
    };

    struct SecurityViolation {
        QString filePath;
        int lineNumber;
        SecurityIssueType type;
        QString matchedCode;
        QString severity;  // critical, high, medium, low
        QString suggestion;
    };

    explicit SecurityGuidelineEnforcer(QObject* parent = nullptr);
    ~SecurityGuidelineEnforcer();

    void registerSecurityPatterns(const QVector<SecurityPattern>& patterns);
    void analyzeCode(const QString& filePath, const QString& code);
    QVector<SecurityViolation> detectViolations(const QString& code, const QString& filePath);

    void setSecurityLevel(const QString& level);  // strict, standard, relaxed
    void enablePattern(SecurityIssueType type);
    void disablePattern(SecurityIssueType type);

    struct ComplianceScore {
        float score;  // 0-100
        int issueCount;
        int criticalCount;
        QString assessment;
    };
    ComplianceScore assessCodeSecurity(const QString& code);

signals:
    void violationDetected(const SecurityViolation& violation);
    void codeAnalyzed(const QString& filePath, int violationCount);
    void securityAlertTriggered(const QString& severity);

private:
    QVector<SecurityPattern> m_patterns;
    QVector<SecurityViolation> m_violations;
    QMap<SecurityIssueType, bool> m_enabledPatterns;
};
