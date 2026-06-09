#ifndef ISSUE_LIFECYCLE_RULES_ENGINE_H
#define ISSUE_LIFECYCLE_RULES_ENGINE_H

#include <QObject>
#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QMap>
#include <QVector>
#include <memory>

/**
 * IssueLifecycleRulesEngine
 *
 * Manages lifecycle rules for GitHub issues including automatic state transitions.
 * Features:
 * - Define and apply lifecycle policies
 * - Track issue state transitions
 * - Generate appropriate notifications and comments
 * - Handle inactivity tracking
 */
class IssueLifecycleRulesEngine : public QObject {
    Q_OBJECT

public:
    enum LifecycleLabel {
        Invalid,
        NeedsRepro,
        NeedsInfo,
        Stale,
        Autoclose
    };
    
    struct LifecyclePolicy {
        LifecycleLabel label;
        int daysUntilAction;
        QString reason;
        QString nudgeMessage;
    };
    
    struct IssueTransition {
        int issueNumber;
        LifecycleLabel fromLabel;
        LifecycleLabel toLabel;
        QDateTime transitionTime;
        QString reason;
    };

    explicit IssueLifecycleRulesEngine(QObject* parent = nullptr);
    ~IssueLifecycleRulesEngine();

    // Policy management
    void registerPolicies(const QVector<LifecyclePolicy>& policies);
    void addPolicy(const LifecyclePolicy& policy);
    LifecyclePolicy getPolicy(LifecycleLabel label) const;
    QVector<LifecyclePolicy> getAllPolicies() const;
    
    // Issue state management
    void trackIssue(int issueNumber, LifecycleLabel initialLabel = Invalid);
    void updateIssueState(int issueNumber, LifecycleLabel newLabel);
    LifecycleLabel getCurrentState(int issueNumber) const;
    QDateTime getLastActivity(int issueNumber) const;
    void recordActivity(int issueNumber);
    
    // Policy evaluation
    LifecycleLabel evaluatePolicy(int issueNumber) const;
    bool shouldTransition(int issueNumber) const;
    QVector<IssueTransition> evaluateAllIssues();
    
    // Notification generation
    QString generateNudgeMessage(LifecycleLabel label) const;
    QString generateCloseReason(LifecycleLabel label) const;
    QString generateStatusUpdate(int issueNumber, LifecycleLabel label) const;
    
    // Configuration
    void setStaleUpvoteThreshold(int threshold);
    void setAutoTransitionEnabled(bool enabled);
    void setMaxInactivityDays(int days);
    
    // Statistics
    int getIssueCount() const;
    int getIssueCountByLabel(LifecycleLabel label) const;
    QMap<LifecycleLabel, int> getStatistics() const;
    QVector<IssueTransition> getRecentTransitions(int count = 10) const;

signals:
    void policyRegistered(const QString& label);
    void issueTracked(int issueNumber);
    void stateTransitioned(int issueNumber, const QString& fromLabel, const QString& toLabel);
    void nudgeRequired(int issueNumber, const QString& message);
    void closeRequested(int issueNumber, const QString& reason);
    void activityRecorded(int issueNumber);

private:
    QString labelToString(LifecycleLabel label) const;
    LifecycleLabel stringToLabel(const QString& str) const;
    int daysSinceLastActivity(int issueNumber) const;
    
    QVector<LifecyclePolicy> m_policies;
    QMap<int, LifecycleLabel> m_issueStates;
    QMap<int, QDateTime> m_lastActivity;
    QVector<IssueTransition> m_transitionHistory;
    
    bool m_autoTransitionEnabled;
    int m_maxInactivityDays;
    int m_staleUpvoteThreshold;
};

#endif // ISSUE_LIFECYCLE_RULES_ENGINE_H
