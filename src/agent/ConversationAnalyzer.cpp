#include "ConversationAnalyzer.h"
#include <QDebug>

ConversationAnalyzer::ConversationAnalyzer(QObject* parent)
    : QObject(parent) {
}

ConversationAnalyzer::~ConversationAnalyzer() {
}

void ConversationAnalyzer::analyzeConversation(const QVector<ConversationTurn>& turns) {
    m_turns = turns;
    emit conversationAnalyzed();
}

void ConversationAnalyzer::registerPattern(const ConversationPattern& pattern) {
    m_registeredPatterns.append(pattern);
}

QVector<ConversationAnalyzer::PatternDetection> ConversationAnalyzer::detectPatterns() {
    return m_detectedPatterns;
}

QVector<QString> ConversationAnalyzer::extractThemes() {
    QVector<QString> themes;
    for (const auto& turn : m_turns) {
        // Simple theme extraction
        if (turn.content.contains("error", Qt::CaseInsensitive)) {
            themes.append("error_handling");
        }
        if (turn.content.contains("design", Qt::CaseInsensitive)) {
            themes.append("design");
        }
    }
    return themes;
}

float ConversationAnalyzer::assessConversationQuality() {
    float quality = 75.0f;
    if (m_turns.size() < 3) quality -= 20.0f;
    if (m_detectedPatterns.size() > 2) quality -= 10.0f;
    return quality;
}

ConversationAnalyzer::ConversationMetrics ConversationAnalyzer::analyzeConversationMetrics() {
    ConversationMetrics metrics;
    metrics.totalTurns = m_turns.size();
    metrics.userTurns = 0;
    metrics.assistantTurns = 0;
    metrics.totalTokens = 0;
    metrics.avgTurnLength = 0;

    for (const auto& turn : m_turns) {
        if (turn.role == "user") {
            metrics.userTurns++;
        } else {
            metrics.assistantTurns++;
        }
        metrics.totalTokens += turn.tokenCount;
    }

    if (metrics.totalTurns > 0) {
        metrics.avgTurnLength = static_cast<float>(metrics.totalTokens) / metrics.totalTurns;
    }

    metrics.detectedPatterns = m_detectedPatterns;
    return metrics;
}

QString ConversationAnalyzer::suggestImprovements() {
    return "Consider being more specific with initial requests";
}

QString ConversationAnalyzer::generateSummary() {
    return QString("Conversation Summary: %1 turns, %2 themes detected").arg(m_turns.size()).arg(extractThemes().size());
}
