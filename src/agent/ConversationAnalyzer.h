#pragma once

#include <QString>
#include <QObject>
#include <memory>
#include <vector>

/**
 * @class ConversationAnalyzer
 * @brief Conversation pattern and interaction analysis
 */

class ConversationAnalyzer : public QObject {
    Q_OBJECT

public:
    struct ConversationTurn {
        QString role;  // user, assistant
        QString content;
        qint64 timestamp;
        int tokenCount;
    };

    struct ConversationPattern {
        QString patternName;
        QString description;
        QStringList signatures;
        bool isProblematic;
        QString suggestion;
    };

    struct PatternDetection {
        ConversationPattern pattern;
        int occurrenceCount;
        float confidence;
    };

    explicit ConversationAnalyzer(QObject* parent = nullptr);
    ~ConversationAnalyzer();

    void analyzeConversation(const QVector<ConversationTurn>& turns);
    void registerPattern(const ConversationPattern& pattern);

    QVector<PatternDetection> detectPatterns();
    QVector<QString> extractThemes();
    float assessConversationQuality();

    struct ConversationMetrics {
        int totalTurns;
        int userTurns;
        int assistantTurns;
        int totalTokens;
        float avgTurnLength;
        QVector<PatternDetection> detectedPatterns;
    };
    ConversationMetrics analyzeConversationMetrics();

    QString suggestImprovements();
    QString generateSummary();

signals:
    void conversationAnalyzed();
    void patternDetected(const PatternDetection& pattern);
    void qualityAssessed(float score);

private:
    QVector<ConversationTurn> m_turns;
    QVector<ConversationPattern> m_registeredPatterns;
    QVector<PatternDetection> m_detectedPatterns;
};
