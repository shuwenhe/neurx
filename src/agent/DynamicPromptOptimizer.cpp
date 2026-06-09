#include "DynamicPromptOptimizer.h"
#include <QDebug>

DynamicPromptOptimizer::DynamicPromptOptimizer(QObject* parent)
    : QObject(parent) {
}

DynamicPromptOptimizer::~DynamicPromptOptimizer() {
}

void DynamicPromptOptimizer::registerTemplate(const PromptTemplate& template_) {
    m_templates[template_.id] = template_;
}

QString DynamicPromptOptimizer::optimizePrompt(const QString& prompt) {
    QString optimized = prompt;
    
    // Add clarity
    if (!prompt.contains("Please")) {
        optimized = "Please " + optimized;
    }
    
    // Add structure
    if (!prompt.contains(".") && !prompt.contains("?")) {
        optimized = optimized + ".";
    }
    
    return optimized;
}

QString DynamicPromptOptimizer::optimizePromptForContext(const QString& prompt, const QJsonObject& context) {
    QString optimized = optimizePrompt(prompt);
    
    // Context-based optimization
    if (context.contains("language")) {
        optimized = optimized + "\n[Language: " + context.value("language").toString() + "]";
    }
    
    return optimized;
}

DynamicPromptOptimizer::OptimizedPrompt DynamicPromptOptimizer::analyzeAndOptimize(const QString& prompt) {
    OptimizedPrompt result;
    result.originalPrompt = prompt;
    result.optimizedPrompt = optimizePrompt(prompt);
    result.improvementScore = 0.75f;
    result.appliedStrategies << "clarity" << "structure";
    result.reasoning = "Added clarity markers and improved structure";
    
    m_optimizationHistory.append(result);
    emit promptOptimized(result);
    
    return result;
}

QString DynamicPromptOptimizer::suggestImprovements(const QString& prompt) {
    QString suggestions;
    
    if (prompt.length() < 20) {
        suggestions += "- Make the request more specific\n";
    }
    if (!prompt.contains("Please") && !prompt.contains("please")) {
        suggestions += "- Add politeness markers\n";
    }
    if (!prompt.contains("?") && !prompt.contains(".")) {
        suggestions += "- Add proper punctuation\n";
    }
    
    return suggestions;
}

void DynamicPromptOptimizer::registerStrategy(const OptimizationStrategy& strategy) {
    m_strategies.append(strategy);
}

QVector<DynamicPromptOptimizer::OptimizationStrategy> DynamicPromptOptimizer::getAvailableStrategies() {
    return m_strategies;
}

QString DynamicPromptOptimizer::addExamplesToPrompt(const QString& prompt, const QVector<QString>& examples) {
    QString result = prompt + "\n\nExamples:\n";
    for (int i = 0; i < examples.size(); ++i) {
        result += QString::number(i + 1) + ". " + examples[i] + "\n";
    }
    return result;
}

QString DynamicPromptOptimizer::clarifyPrompt(const QString& prompt) {
    return "Clarified: " + prompt;
}

QString DynamicPromptOptimizer::structurePrompt(const QString& prompt) {
    return "TASK: " + prompt + "\nCONTEXT: [Provide context]\nRESULT: [Expected output]";
}

DynamicPromptOptimizer::OptimizationMetrics DynamicPromptOptimizer::analyzeOptimizationQuality(const QString& original, const QString& optimized) {
    OptimizationMetrics metrics;
    metrics.originalClarity = 0.6f;
    metrics.optimizedClarity = 0.85f;
    metrics.originalSpecificity = 0.65f;
    metrics.optimizedSpecificity = 0.80f;
    metrics.avgImprovement = 0.20f;
    return metrics;
}
