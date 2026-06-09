#ifndef GITHUB_ISSUE_LABEL_MANAGER_H
#define GITHUB_ISSUE_LABEL_MANAGER_H

#include <QObject>
#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QMap>
#include <QSet>
#include <memory>

/**
 * GitHubIssueLabelManager
 *
 * Manages GitHub issue labels with intelligent filtering and application.
 * Features:
 * - Add/remove labels from issues
 * - Validate labels against repository label list
 * - Batch label operations
 * - Label-based issue categorization
 */
class GitHubIssueLabelManager : public QObject {
    Q_OBJECT

public:
    struct LabelOperation {
        QString issueNumber;
        QStringList labelsToAdd;
        QStringList labelsToRemove;
        bool validated;
    };
    
    struct LabelInfo {
        QString name;
        QString color;
        QString description;
        bool isDefault;
    };

    explicit GitHubIssueLabelManager(QObject* parent = nullptr);
    ~GitHubIssueLabelManager();

    // Label operations
    void addLabel(int issueNumber, const QString& label);
    void removeLabel(int issueNumber, const QString& label);
    void setLabels(int issueNumber, const QStringList& labels);
    void replaceLabelSet(int issueNumber, const QStringList& oldLabels, const QStringList& newLabels);
    
    // Batch operations
    void performLabelOperations(const QList<LabelOperation>& operations);
    void applyBulkLabels(const QStringList& issueNumbers, const QStringList& labels);
    void removeBulkLabels(const QStringList& issueNumbers, const QStringList& labels);
    
    // Validation
    void fetchRepositoryLabels(const QString& owner, const QString& repo);
    bool isValidLabel(const QString& label) const;
    QStringList filterValidLabels(const QStringList& labels) const;
    QStringList getAvailableLabels() const;
    
    // Label info
    LabelInfo getLabelInfo(const QString& label) const;
    QList<LabelInfo> getAllLabelInfo() const;
    
    // Issue label queries
    QStringList getIssueLabels(int issueNumber);
    bool issueHasLabel(int issueNumber, const QString& label);
    
    // Categorization
    QStringList categorizeLabelsByType(const QStringList& labels);
    QString getPrimaryCategory(const QStringList& labels);
    
    // Statistics
    int getLabelUsageCount(const QString& label) const;
    QMap<QString, int> getLabelStatistics() const;

signals:
    void labelAdded(int issueNumber, const QString& label);
    void labelRemoved(int issueNumber, const QString& label);
    void labelsUpdated(int issueNumber, const QStringList& labels);
    void labelOperationFailed(int issueNumber, const QString& reason);
    void repositoryLabelsLoaded(int count);
    void operationCompleted(int successCount, int failureCount);

private:
    void validateLabel(const QString& label);
    void applyLabel(int issueNumber, const QString& label);
    QString generateLabelColor(const QString& labelName);
    
    QMap<QString, LabelInfo> m_repositoryLabels;
    QMap<int, QStringList> m_issueLabels;
    QSet<QString> m_validLabelNames;
};

#endif // GITHUB_ISSUE_LABEL_MANAGER_H
