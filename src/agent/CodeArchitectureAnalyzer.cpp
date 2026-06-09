#include "CodeArchitectureAnalyzer.h"
#include <QDebug>

CodeArchitectureAnalyzer::CodeArchitectureAnalyzer(QObject* parent)
    : QObject(parent), m_detectedPattern(MVC) {
}

CodeArchitectureAnalyzer::~CodeArchitectureAnalyzer() {
}

void CodeArchitectureAnalyzer::analyzeCodebase(const QStringList& filePaths) {
    for (const auto& filePath : filePaths) {
        qDebug() << "Analyzing:" << filePath;
    }
    emit analysisCompleted();
}

void CodeArchitectureAnalyzer::identifyPattern(const QString& codebase) {
    if (codebase.contains("Model") && codebase.contains("View") && codebase.contains("Controller")) {
        m_detectedPattern = MVC;
    } else if (codebase.contains("Service") && codebase.contains("Repository")) {
        m_detectedPattern = LayeredArchitecture;
    }
    emit patternIdentified(QString::number(static_cast<int>(m_detectedPattern)));
}

QVector<CodeArchitectureAnalyzer::ComponentDependency> CodeArchitectureAnalyzer::extractDependencies(const QString& code) {
    return m_dependencies;
}

QVector<CodeArchitectureAnalyzer::ArchitectureIssue> CodeArchitectureAnalyzer::detectArchitectureIssues() {
    return m_issues;
}

CodeArchitectureAnalyzer::ArchitectureMetrics CodeArchitectureAnalyzer::analyzeArchitectureQuality() {
    ArchitectureMetrics metrics;
    metrics.numberOfComponents = m_dependencies.size();
    metrics.couplingScore = 45.0f;
    metrics.cohesionScore = 75.0f;
    metrics.cyclicDependencies = 0;
    metrics.maintainability = 78.0f;
    return metrics;
}

QString CodeArchitectureAnalyzer::suggestRefactoring() {
    return "Consider extracting common logic into service layer";
}

QString CodeArchitectureAnalyzer::suggestDesignPatterns() {
    return "Apply Dependency Injection for better testability";
}

CodeArchitectureAnalyzer::DependencyGraph CodeArchitectureAnalyzer::generateDependencyGraph() {
    DependencyGraph graph;
    graph.totalComponents = m_dependencies.size();
    return graph;
}
