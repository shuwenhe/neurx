#include "SecurityGuidelineEnforcer.h"
#include <QDebug>

SecurityGuidelineEnforcer::SecurityGuidelineEnforcer(QObject* parent)
    : QObject(parent) {
}

SecurityGuidelineEnforcer::~SecurityGuidelineEnforcer() {
}

void SecurityGuidelineEnforcer::registerSecurityPatterns(const QVector<SecurityPattern>& patterns) {
    m_patterns = patterns;
}

void SecurityGuidelineEnforcer::analyzeCode(const QString& filePath, const QString& code) {
    auto violations = detectViolations(code, filePath);
    emit codeAnalyzed(filePath, violations.size());
}

QVector<SecurityGuidelineEnforcer::SecurityViolation> SecurityGuidelineEnforcer::detectViolations(const QString& code, const QString& filePath) {
    QVector<SecurityViolation> violations;
    
    QStringList lines = code.split("\n");
    for (int i = 0; i < lines.size(); ++i) {
        const auto& line = lines[i];
        
        for (const auto& pattern : m_patterns) {
            if (!m_enabledPatterns.value(pattern.type, true)) continue;
            
            if (pattern.isRegex) {
                QRegularExpression regex(pattern.pattern);
                if (regex.match(line).hasMatch()) {
                    SecurityViolation violation;
                    violation.filePath = filePath;
                    violation.lineNumber = i + 1;
                    violation.type = pattern.type;
                    violation.matchedCode = line.trimmed();
                    violation.severity = "high";
                    violation.suggestion = pattern.remediation;
                    violations.append(violation);
                    emit violationDetected(violation);
                }
            } else {
                if (line.contains(pattern.pattern)) {
                    SecurityViolation violation;
                    violation.filePath = filePath;
                    violation.lineNumber = i + 1;
                    violation.type = pattern.type;
                    violation.matchedCode = line.trimmed();
                    violation.severity = "high";
                    violation.suggestion = pattern.remediation;
                    violations.append(violation);
                    emit violationDetected(violation);
                }
            }
        }
    }
    
    m_violations.append(violations);
    return violations;
}

void SecurityGuidelineEnforcer::setSecurityLevel(const QString& level) {
    qDebug() << "Set security level to:" << level;
}

void SecurityGuidelineEnforcer::enablePattern(SecurityIssueType type) {
    m_enabledPatterns[type] = true;
}

void SecurityGuidelineEnforcer::disablePattern(SecurityIssueType type) {
    m_enabledPatterns[type] = false;
}

SecurityGuidelineEnforcer::ComplianceScore SecurityGuidelineEnforcer::assessCodeSecurity(const QString& code) {
    ComplianceScore score;
    auto violations = detectViolations(code, "");
    
    score.issueCount = violations.size();
    score.criticalCount = 0;
    for (const auto& v : violations) {
        if (v.severity == "critical") score.criticalCount++;
    }
    
    score.score = 100.0f - (violations.size() * 5.0f);
    if (score.score < 0) score.score = 0;
    
    if (score.score >= 90) score.assessment = "Excellent";
    else if (score.score >= 70) score.assessment = "Good";
    else if (score.score >= 50) score.assessment = "Fair";
    else score.assessment = "Poor";
    
    return score;
}
