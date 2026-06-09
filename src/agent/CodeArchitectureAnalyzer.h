#pragma once

#include <QString>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class CodeArchitectureAnalyzer
 * @brief Code architecture analysis and design recommendations
 */

class CodeArchitectureAnalyzer : public QObject {
    Q_OBJECT

public:
    enum ArchitecturePattern {
        MVC,
        MVP,
        MVVM,
        LayeredArchitecture,
        Microservices,
        EventDriven,
        CQRS,
        HexagonalArchitecture
    };

    struct ComponentDependency {
        QString source;
        QString target;
        QString type;  // import, extends, implements, uses
        int weight;
    };

    struct ArchitectureIssue {
        QString component;
        QString issue;
        QString severity;  // critical, high, medium, low
        QString suggestion;
    };

    explicit CodeArchitectureAnalyzer(QObject* parent = nullptr);
    ~CodeArchitectureAnalyzer();

    void analyzeCodebase(const QStringList& filePaths);
    void identifyPattern(const QString& codebase);

    QVector<ComponentDependency> extractDependencies(const QString& code);
    QVector<ArchitectureIssue> detectArchitectureIssues();

    struct ArchitectureMetrics {
        int numberOfComponents;
        float couplingScore;  // 0-100, lower is better
        float cohesionScore;  // 0-100, higher is better
        int cyclicDependencies;
        float maintainability;  // 0-100
    };
    ArchitectureMetrics analyzeArchitectureQuality();

    QString suggestRefactoring();
    QString suggestDesignPatterns();

    struct DependencyGraph {
        QMap<QString, QVector<QString>> adjacencyList;
        int totalComponents;
    };
    DependencyGraph generateDependencyGraph();

signals:
    void analysisCompleted();
    void patternIdentified(const QString& pattern);
    void issueDetected(const ArchitectureIssue& issue);
    void refactoringSuggested();

private:
    QVector<ComponentDependency> m_dependencies;
    QVector<ArchitectureIssue> m_issues;
    ArchitecturePattern m_detectedPattern;
};
