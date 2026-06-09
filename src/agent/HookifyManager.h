#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <memory>
#include <map>

/**
 * @class HookifyManager
 * @brief Creates and manages custom hooks to prevent unwanted behaviors
 * 
 * Features:
 * - Pattern-based hook detection
 * - Conversation analysis for problematic patterns
 * - Automatic hook generation
 * - Hook validation and testing
 * - Rule syntax guidance
 * - Hook marketplace integration
 * - Behavior prevention and filtering
 */

class HookifyManager : public QObject {
    Q_OBJECT

public:
    enum HookType {
        PreventatativeHook,    // Prevents unwanted behavior
        CorrectionHook,        // Corrects behavior in-flight
        FilteringHook,         // Filters output
        RedirectionHook,       // Redirects to correct behavior
        EnforcementHook        // Enforces rules
    };

    enum SeverityLevel {
        Info,
        Warning,
        Error,
        Critical
    };

    struct HookRule {
        QString id;
        QString name;
        QString description;
        HookType type;
        SeverityLevel severity;
        QStringList patterns;
        QStringList keywords;
        QString action;
        QString remediation;
        bool enabled;
        int priority;
        QJsonObject metadata;
        QDateTime createdAt;
        int triggerCount;
    };

    struct BehaviorPattern {
        QString pattern;
        float confidence;
        int occurrences;
        QStringList examples;
        QString suggestedHook;
    };

    explicit HookifyManager(QObject* parent = nullptr);
    ~HookifyManager();

    // Hook management
    void createHook(const HookRule& rule);
    void deleteHook(const QString& hookId);
    void updateHook(const QString& hookId, const HookRule& newRule);
    HookRule getHook(const QString& hookId);
    QVector<HookRule> getAllHooks();
    QVector<HookRule> getHooksOfType(HookType type);

    // Hook execution
    bool executeHook(const QString& hookId, const QString& input);
    QString applyHooks(const QString& input);
    QString applyHooksOfType(const QString& input, HookType type);
    bool checkViolation(const QString& input, const HookRule& rule);

    // Pattern detection
    QVector<BehaviorPattern> analyzeConversation(const QStringList& messages);
    BehaviorPattern detectPattern(const QString& text);
    QVector<BehaviorPattern> suggestHooksForPatterns(const QStringList& messages);
    bool matchesPattern(const QString& text, const HookRule& rule);

    // Hook generation
    HookRule generateHookFromPattern(const BehaviorPattern& pattern);
    HookRule generateHookFromExamples(const QStringList& examples);
    HookRule createPreventionHook(const QString& behavior, const QString& prevention);
    HookRule createCorrectionHook(const QString& badOutput, const QString& correctedOutput);

    // Hook configuration
    void setHookEnabled(const QString& hookId, bool enabled);
    void setHookPriority(const QString& hookId, int priority);
    void setHookSeverity(const QString& hookId, SeverityLevel severity);
    void configureHookAction(const QString& hookId, const QString& action);
    void configureHookRemediation(const QString& hookId, const QString& remediation);

    // Validation and testing
    bool validateHookRule(const HookRule& rule);
    bool testHook(const QString& hookId, const QString& testInput);
    QJsonObject runHookTests(const QString& hookId);
    void validateHookSyntax(const QString& ruleSyntax);

    // Rule syntax assistance
    QString getHookSyntaxGuide();
    QString generateHookSyntax(const HookRule& rule);
    QStringList suggestPatternSyntax(const QString& behavior);
    QJsonArray getHookExamples(HookType type);

    // Conversation analysis
    struct ConversationAnalysis {
        int totalMessages;
        int patternsDetected;
        QVector<BehaviorPattern> patterns;
        QVector<HookRule> recommendedHooks;
        float riskScore;
        QStringList riskFactors;
    };
    ConversationAnalysis analyzeForRisks(const QStringList& messages);

    // Hook marketplace
    void publishHookToMarketplace(const HookRule& rule);
    void importHookFromMarketplace(const QString& hookId);
    QVector<HookRule> searchMarketplace(const QString& query);
    QJsonArray getMarketplaceHooks();

    // Statistics and reporting
    struct HookStats {
        int totalHooks;
        int enabledHooks;
        int disabledHooks;
        QMap<HookType, int> hooksByType;
        QMap<QString, int> triggerCounts;
        float averageSeverity;
        int totalViolationsDetected;
    };
    HookStats getStatistics() const;

    // Hook profiles
    void saveHookProfile(const QString& profileName);
    void loadHookProfile(const QString& profileName);
    QStringList getAvailableProfiles();
    void deleteHookProfile(const QString& profileName);

    // Debugging
    void enableDebugMode(bool enabled);
    QJsonObject getDebugInfo();
    QStringList getHookExecutionLog();
    void clearExecutionLog();

signals:
    void hookCreated(const QString& hookId);
    void hookDeleted(const QString& hookId);
    void hookExecuted(const QString& hookId);
    void patternDetected(const BehaviorPattern& pattern);
    void violationDetected(const QString& hookId);
    void hookEnabled(const QString& hookId);
    void hookDisabled(const QString& hookId);

private:
    QMap<QString, HookRule> m_hooks;
    QStringList m_executionLog;
    HookStats m_statistics;
    bool m_debugMode;

    QString generateUniqueId();
    float calculatePatternConfidence(const BehaviorPattern& pattern);
    QString formatHookSyntax(const HookRule& rule);
};
