#pragma once

#include <QString>
#include <QObject>
#include <QDateTime>
#include <memory>
#include <map>

/**
 * @class IssueLifecycleManager
 * @brief GitHub issue lifecycle and automation
 */

class IssueLifecycleManager : public QObject {
    Q_OBJECT

public:
    enum LifecycleLabel {
        Invalid,
        NeedsRepro,
        NeedsInfo,
        Stale,
        Autoclose
    };

    struct IssuePolicy {
        LifecycleLabel label;
        int daysUntilAction;
        QString reason;
        QString nudgeMessage;
    };

    struct Issue {
        QString id;
        QString title;
        QString description;
        QDateTime createdAt;
        QDateTime lastActivityAt;
        QStringList labels;
        QString assignee;
        int upvotes;
        bool isOpen;
    };

    explicit IssueLifecycleManager(QObject* parent = nullptr);
    ~IssueLifecycleManager();

    void registerIssuePolicies(const QVector<IssuePolicy>& policies);
    void trackIssue(const Issue& issue);
    void updateLastActivity(const QString& issueId);

    QVector<Issue> findStaleIssues();
    QVector<Issue> findNeedsRepro();
    QVector<Issue> findInvalidIssues();

    void autoCloseIssue(const QString& issueId);
    void sendNudgeMessage(const QString& issueId);
    void labelIssue(const QString& issueId, LifecycleLabel label);

    struct LifecycleReport {
        int totalIssues;
        int activeIssues;
        int staleIssues;
        int invalidIssues;
        int needsReproIssues;
        int needsInfoIssues;
    };
    LifecycleReport generateReport();

signals:
    void issueNeedsAttention(const QString& issueId);
    void issueMarkedStale(const QString& issueId);
    void issueAutoClosed(const QString& issueId);
    void nudgeMessageSent(const QString& issueId);

private:
    QVector<IssuePolicy> m_policies;
    QMap<QString, Issue> m_issues;
};
