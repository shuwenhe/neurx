#ifndef GITHUB_SWEEP_AUTOMATION_H
#define GITHUB_SWEEP_AUTOMATION_H

#include <QObject>
#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QMap>
#include <QSet>
#include <memory>

/**
 * GitHubSweepAutomation
 *
 * Automates GitHub issue and PR cleanup tasks:
 * - Detects and handles issues needing reproduction/info
 * - Auto-closes stale issues based on policies
 * - Adds helpful nudges and reminders
 * - Applies automated labels and categorization
 */
class GitHubSweepAutomation : public QObject {
    Q_OBJECT

public:
    enum SweepAction {
        NudgeForInfo,
        RequestRepro,
        MarkStale,
        AutoClose,
        Archive,
        NoAction
    };
    
    enum IssueCategory {
        BugNeedsInfo,
        BugNeedsRepro,
        FeatureComplete,
        DocumentationNeeded,
        DuplicateIssue,
        Invalid
    };

    explicit GitHubSweepAutomation(QObject* parent = nullptr);
    ~GitHubSweepAutomation();

    // Sweep operations
    void scanRepositoryIssues(const QString& owner, const QString& repo);
    void processIssue(const QJsonObject& issue);
    SweepAction determineSweepAction(const QJsonObject& issue);
    
    // Issue analysis
    IssueCategory categorizeIssue(const QString& title, const QString& body, const QStringList& labels);
    bool needsInformation(const QJsonObject& issue);
    bool needsReproduction(const QJsonObject& issue);
    bool isStaleWithoutResponse(const QJsonObject& issue);
    
    // Automated actions
    void nudgeForInformation(int issueNumber, const QString& lastCommentBy);
    void nudgeForReproduction(int issueNumber);
    void markAsStale(int issueNumber);
    void autoCloseStale(int issueNumber, const QString& reason = QString());
    
    // Comment generation
    QString generateInfoNudge();
    QString generateReproNudge();
    QString generateStaleWarning();
    QString generateAutoCloseReason();
    
    // Configuration
    void setDaysBeforeNudge(int days);
    void setDaysBeforeClose(int days);
    void setAutoCloseEnabled(bool enabled);
    void setNeedInfoKeywords(const QStringList& keywords);
    void setNeedReproKeywords(const QStringList& keywords);
    
    // Statistics
    int getTotalIssuesProcessed() const;
    int getTotalActionsTaken() const;
    QMap<SweepAction, int> getActionStatistics() const;

signals:
    void sweepStarted(const QString& repo);
    void issueProcessed(int issueNumber, SweepAction action);
    void actionTaken(int issueNumber, SweepAction action, const QString& message);
    void sweepFinished(int issuesProcessed, int actionsTaken);
    void statisticsUpdated();

private:
    struct SweepIssue {
        int number;
        QString title;
        QString body;
        QDateTime created;
        QDateTime lastActivity;
        QStringList labels;
        int daysInactive;
        bool hasReproduction;
        bool hasInformation;
        SweepAction recommendedAction;
    };

    SweepIssue analyzeSweepIssue(const QJsonObject& issue);
    int daysSinceLastActivity(const QJsonObject& issue);
    bool hasReproductionInfo(const QString& body);
    bool hasUserInfo(const QString& body);
    
    int m_daysBeforeNudge;
    int m_daysBeforeClose;
    bool m_autoCloseEnabled;
    
    QStringList m_needInfoKeywords;
    QStringList m_needReproKeywords;
    
    int m_totalProcessed;
    int m_totalActions;
    QMap<SweepAction, int> m_actionStats;
};

#endif // GITHUB_SWEEP_AUTOMATION_H
