#include "TypeDesignValidator.h"
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>

TypeDesignValidator::TypeDesignValidator(QObject* parent)
    : QObject(parent)
{
}

TypeDesignValidator::~TypeDesignValidator()
{
}

void TypeDesignValidator::analyzeTypes(const QString& code, const QString& filePath, const AnalysisConfig& config)
{
    qInfo() << QString("[Types] Analyzing: %1").arg(filePath);
    emit analysisStarted(filePath);

    TypeAnalysis analysis;
    analysis.filePath = filePath;
    
    if (config.checkAnnotations) {
        analysis.findings.append(findMissingAnnotations(code));
    }
    if (config.checkGenerics) {
        analysis.findings.append(findAmbiguousGenerics(code));
    }
    if (config.checkInheritance) {
        analysis.findings.append(findWeakInheritance(code));
    }
    if (config.checkConsistency) {
        analysis.findings.append(findTypeInconsistencies(code));
    }
    if (config.checkNullability) {
        analysis.findings.append(findUnsafeCasts(code));
    }

    analysis.totalTypes = code.count("class") + code.count("struct") + code.count("interface");
    analysis.wellAnnotatedTypes = std::max(0, analysis.totalTypes - static_cast<int>(analysis.findings.size()));
    analysis.designScore = analysis.totalTypes > 0 ? 
        static_cast<float>(analysis.wellAnnotatedTypes) / analysis.totalTypes : 1.0f;
    
    analysis.summary = generateDesignReport(analysis);
    m_results[filePath] = analysis;
    m_totalAnalyzed++;
    m_totalIssuesFound += analysis.findings.size();

    for (const TypeFinding& f : analysis.findings) {
        emit issueFound(f);
    }

    emit analysisCompleted(filePath);
}

void TypeDesignValidator::analyzeFile(const QString& filePath, const AnalysisConfig& config)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit errorOccurred(QString("Cannot open file: %1").arg(filePath));
        return;
    }

    QTextStream in(&file);
    QString code = in.readAll();
    file.close();

    analyzeTypes(code, filePath, config);
}

QVector<TypeDesignValidator::TypeFinding> TypeDesignValidator::findMissingAnnotations(const QString& code)
{
    QVector<TypeFinding> findings;

    if (code.contains("function") && !code.contains(":")) {
        TypeFinding finding;
        finding.issueType = MissingTypeAnnotation;
        finding.severity = 0.75f;
        finding.explanation = "Function without type annotations";
        finding.reasoning = "Add return type and parameter type annotations for better type safety";
        findings.append(finding);
    }

    return findings;
}

QVector<TypeDesignValidator::TypeFinding> TypeDesignValidator::findAmbiguousGenerics(const QString& code)
{
    QVector<TypeFinding> findings;

    if (code.contains("<") && code.contains(">") && !code.contains("extends") && !code.contains("super")) {
        TypeFinding finding;
        finding.issueType = AmbiguousGeneric;
        finding.severity = 0.65f;
        finding.explanation = "Generic type without constraints";
        finding.reasoning = "Consider adding type constraints (extends/super) for clarity";
        findings.append(finding);
    }

    return findings;
}

QVector<TypeDesignValidator::TypeFinding> TypeDesignValidator::findWeakInheritance(const QString& code)
{
    QVector<TypeFinding> findings;

    if (code.contains("extends") && code.count("abstract") == 0) {
        TypeFinding finding;
        finding.issueType = WeakInheritance;
        finding.severity = 0.6f;
        finding.explanation = "Inheritance without abstract base";
        finding.reasoning = "Consider using abstract classes or interfaces for better design";
        findings.append(finding);
    }

    return findings;
}

QVector<TypeDesignValidator::TypeFinding> TypeDesignValidator::findTypeInconsistencies(const QString& code)
{
    QVector<TypeFinding> findings;

    if (code.contains("var") && code.contains("const") && code.contains("let")) {
        TypeFinding finding;
        finding.issueType = TypeInconsistency;
        finding.severity = 0.55f;
        finding.explanation = "Inconsistent variable declaration keywords";
        finding.reasoning = "Use consistent declaration patterns throughout the codebase";
        findings.append(finding);
    }

    return findings;
}

QVector<TypeDesignValidator::TypeFinding> TypeDesignValidator::findUnsafeCasts(const QString& code)
{
    QVector<TypeFinding> findings;

    if (code.contains("as ") || code.contains("as!") || code.contains("(type)")) {
        TypeFinding finding;
        finding.issueType = UnsafeTypecast;
        finding.severity = 0.7f;
        finding.explanation = "Unsafe type casting detected";
        finding.reasoning = "Prefer type-safe alternatives or add proper type checking before casting";
        findings.append(finding);
    }

    return findings;
}

QVector<TypeDesignValidator::TypeFinding> TypeDesignValidator::findOvercomplicatedTypes(const QString& code)
{
    QVector<TypeFinding> findings;

    // Detect deeply nested generic types
    if (code.count('<') > 3 || code.count('>') > 3) {
        TypeFinding finding;
        finding.issueType = OvercomplicatedType;
        finding.severity = 0.6f;
        finding.explanation = "Overly complicated generic type nesting";
        finding.reasoning = "Consider simplifying type definitions using type aliases";
        findings.append(finding);
    }

    return findings;
}

QVector<TypeDesignValidator::TypeFinding> TypeDesignValidator::findUnusedTypeParameters(const QString& code)
{
    QVector<TypeFinding> findings;
    return findings;
}

bool TypeDesignValidator::hasTypeAnnotation(const QString& functionSignature)
{
    return functionSignature.contains(":") || functionSignature.contains("->") || 
           functionSignature.contains("void") || functionSignature.contains("int") || 
           functionSignature.contains("string");
}

bool TypeDesignValidator::isGenericType(const QString& type)
{
    return type.contains("<") && type.contains(">");
}

bool TypeDesignValidator::isWeakInheritance(const QString& classDefinition)
{
    return classDefinition.contains("extends") && !classDefinition.contains("abstract");
}

QString TypeDesignValidator::suggestBetterType(const QString& currentType)
{
    if (currentType == "any") return "unknown";
    if (currentType == "Object") return "Record<string, unknown>";
    return currentType;
}

TypeDesignValidator::TypeAnalysis TypeDesignValidator::getAnalysisResult(const QString& filePath)
{
    if (m_results.contains(filePath)) {
        return m_results[filePath];
    }
    return TypeAnalysis();
}

QJsonObject TypeDesignValidator::getStatistics() const
{
    QJsonObject stats;
    stats["totalAnalyzed"] = m_totalAnalyzed;
    stats["totalIssuesFound"] = m_totalIssuesFound;
    return stats;
}

QString TypeDesignValidator::generateDesignReport(const TypeAnalysis& analysis)
{
    QString report;
    report += "# Type Design Report\n\n";
    report += QString("**File**: %1\n").arg(analysis.filePath);
    report += QString("**Design Score**: %.1f%%\n").arg(analysis.designScore * 100);
    report += QString("**Total Types**: %1\n").arg(analysis.totalTypes);
    report += QString("**Well-Annotated Types**: %1\n").arg(analysis.wellAnnotatedTypes);
    report += QString("**Issues Found**: %1\n\n").arg(analysis.findings.size());
    
    if (analysis.designScore < 0.75f) {
        report += "⚠️ **Action needed**: Type design score below acceptable threshold\n";
    }

    return report;
}

QString TypeDesignValidator::generateRecommendations(const TypeAnalysis& analysis)
{
    QString recommendations;
    recommendations += "# Type Design Recommendations\n\n";
    
    for (const TypeFinding& f : analysis.findings) {
        recommendations += QString("- %1: %2\n").arg(f.explanation).arg(f.reasoning);
    }

    return recommendations;
}
