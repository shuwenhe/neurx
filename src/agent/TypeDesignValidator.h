#pragma once

#include <QObject>
#include <QString>
#include <QMap>
#include <QVector>
#include <QJsonObject>

/**
 * @class TypeDesignValidator
 * @brief Analyzes type design patterns and consistency
 * 
 * Based on pr-review-toolkit's type-design-analyzer. Validates type definitions,
 * inheritance hierarchies, and generic type usage.
 */
class TypeDesignValidator : public QObject {
    Q_OBJECT

public:
    explicit TypeDesignValidator(QObject* parent = nullptr);
    ~TypeDesignValidator();

    // Type design issues
    enum TypeIssue {
        MissingTypeAnnotation,  // Function without return type
        AmbiguousGeneric,       // Generic type without constraints
        WeakInheritance,        // Unclear inheritance structure
        TypeInconsistency,      // Inconsistent type usage
        UnsafeTypecast,         // Unsafe type casting
        MissingNullability,     // Missing null checks for optional types
        OvercomplicatedType,    // Type is too complex/nested
        UnusedTypeParameter     // Generic parameter not used
    };

    // Type finding
    struct TypeFinding {
        int lineNumber;
        int endLineNumber;
        QString filePath;
        TypeIssue issueType;
        float severity;         // 0.0-1.0
        QString typeName;
        QString currentType;
        QString suggestedType;
        QString explanation;
        QString reasoning;
    };

    // Analysis result
    struct TypeAnalysis {
        QString filePath;
        int totalTypes = 0;
        int wellAnnotatedTypes = 0;
        int hasInconsistencies = 0;
        QVector<TypeFinding> findings;
        float designScore;      // 0.0-1.0
        QString summary;
    };

    // Config
    struct AnalysisConfig {
        bool checkAnnotations = true;
        bool checkGenerics = true;
        bool checkInheritance = true;
        bool checkConsistency = true;
        bool checkNullability = true;
        float minAcceptableScore = 0.75f;
    };

    // Analysis
    void analyzeTypes(const QString& code, const QString& filePath, const AnalysisConfig& config);
    void analyzeFile(const QString& filePath, const AnalysisConfig& config);
    
    // Detection methods
    QVector<TypeFinding> findMissingAnnotations(const QString& code);
    QVector<TypeFinding> findAmbiguousGenerics(const QString& code);
    QVector<TypeFinding> findWeakInheritance(const QString& code);
    QVector<TypeFinding> findTypeInconsistencies(const QString& code);
    QVector<TypeFinding> findUnsafeCasts(const QString& code);
    QVector<TypeFinding> findOvercomplicatedTypes(const QString& code);
    QVector<TypeFinding> findUnusedTypeParameters(const QString& code);
    
    // Helper methods
    bool hasTypeAnnotation(const QString& functionSignature);
    bool isGenericType(const QString& type);
    bool isWeakInheritance(const QString& classDefinition);
    QString suggestBetterType(const QString& currentType);
    
    // Results
    TypeAnalysis getAnalysisResult(const QString& filePath);
    QJsonObject getStatistics() const;
    
    // Report generation
    QString generateDesignReport(const TypeAnalysis& analysis);
    QString generateRecommendations(const TypeAnalysis& analysis);

signals:
    void analysisStarted(const QString& filePath);
    void analysisCompleted(const QString& filePath);
    void issueFound(const TypeFinding& finding);
    void errorOccurred(const QString& error);

private:
    QMap<QString, TypeAnalysis> m_results;
    int m_totalAnalyzed = 0;
    int m_totalIssuesFound = 0;
};
