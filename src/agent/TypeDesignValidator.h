#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <map>

/**
 * @class TypeDesignValidator
 * @brief Validates and analyzes type design and interfaces
 * 
 * Features:
 * - Type compatibility checking
 * - Interface design validation
 * - Generic type analysis
 * - Type safety verification
 * - Inheritance hierarchy analysis
 * - Template correctness checking
 */

class TypeDesignValidator : public QObject {
    Q_OBJECT

public:
    enum TypeCategory {
        Primitive,
        Class,
        Struct,
        Interface,
        Template,
        Generic,
        Enum,
        Union
    };

    enum ValidationSeverity {
        Info,
        Warning,
        Error
    };

    struct TypeInfo {
        QString name;
        TypeCategory category;
        QStringList baseClasses;
        QStringList members;
        QStringList methods;
        bool isAbstract;
        bool isTemplate;
        int memberCount;
        int methodCount;
    };

    struct ValidationResult {
        bool isValid;
        QStringList issues;
        QStringList warnings;
        QStringList suggestions;
        float conformanceScore;
        QMap<ValidationSeverity, int> issueCounts;
    };

    explicit TypeDesignValidator(QObject* parent = nullptr);
    ~TypeDesignValidator();

    // Type analysis
    TypeInfo analyzeType(const QString& typeName, const QString& filepath);
    ValidationResult validateType(const QString& typeName);
    ValidationResult validateInterface(const QString& interfaceName);

    // Compatibility checking
    bool areTypesCompatible(const QString& type1, const QString& type2);
    bool isAssignableTo(const QString& sourceType, const QString& targetType);
    bool checkTypeConversion(const QString& fromType, const QString& toType);
    QStringList getCompatibleTypes(const QString& type);

    // Inheritance analysis
    QStringList getInheritanceChain(const QString& className);
    int getInheritanceDepth(const QString& className);
    bool checkCircularInheritance(const QString& className);
    QString suggestInheritanceImprovement(const QString& className);

    // Interface design validation
    struct InterfaceIssue {
        QString issue;
        QString location;
        ValidationSeverity severity;
        QString suggestion;
    };
    QVector<InterfaceIssue> validateInterfaceDesign(const QString& interfaceName);
    bool isInterfaceWellDesigned(const QString& interfaceName);

    // Generic/Template analysis
    ValidationResult validateTemplate(const QString& templateName);
    QStringList getTemplateParameters(const QString& templateName);
    bool areTemplateArgumentsValid(const QString& templateName, const QStringList& arguments);
    QString suggestTemplateSpecialization(const QString& templateName);

    // Method signature validation
    struct MethodSignature {
        QString name;
        QString returnType;
        QStringList parameterTypes;
        bool isConst;
        bool isVirtual;
        bool isPure;
    };
    ValidationResult validateMethodSignature(const MethodSignature& signature);
    bool checkMethodOverride(const MethodSignature& original, const MethodSignature& override);

    // Type safety
    ValidationResult checkTypeSafety(const QString& filepath);
    QStringList detectUnsafeCasts(const QString& filepath);
    QStringList detectUnsafePointerUsage(const QString& filepath);
    bool hasNullSafetyIssues(const QString& filepath);

    // Design patterns
    QStringList detectPatterns(const QString& typeName);
    QString suggestPatternApplication(const QString& typeName);
    ValidationResult validatePatternUsage(const QString& patternName);

    // Refactoring suggestions
    struct RefactoringSuggestion {
        QString issue;
        QString suggestion;
        QString reason;
        float confidence;
    };
    QVector<RefactoringSuggestion> suggestRefactorings(const QString& typeName);

    // Statistics
    struct TypeStats {
        int totalTypes;
        int validTypes;
        int typesWithIssues;
        float averageConformance;
        QMap<ValidationSeverity, int> severityDistribution;
    };
    TypeStats getStatistics() const;

    // Batch validation
    QMap<QString, ValidationResult> validateTypes(const QStringList& typeNames);

    // Configuration
    void setValidationLevel(int level);  // 0-10, higher = stricter
    void enableStrictMode(bool enabled);
    void enableWarnings(bool enabled);

    // Export/Import
    QJsonObject exportValidationResults();
    QString generateValidationReport();

signals:
    void typeValidated(const QString& typeName, bool valid);
    void issueFound(const QString& typeName, const QString& issue);

private:
    QMap<QString, TypeInfo> m_typeCache;
    int m_validationLevel;
    bool m_strictMode;
    bool m_warningsEnabled;
    TypeStats m_statistics;

    ValidationResult performValidation(const TypeInfo& type);
    float calculateConformanceScore(const TypeInfo& type);
};
