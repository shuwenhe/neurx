#include "GitHubIssueLabelManager.h"
#include <QDebug>
#include <QHash>

GitHubIssueLabelManager::GitHubIssueLabelManager(QObject* parent)
    : QObject(parent)
{
}

GitHubIssueLabelManager::~GitHubIssueLabelManager()
{
}

void GitHubIssueLabelManager::addLabel(int issueNumber, const QString& label)
{
    if (!isValidLabel(label)) {
        emit labelOperationFailed(issueNumber, "Label not found in repository: " + label);
        return;
    }
    
    QStringList& labels = m_issueLabels[issueNumber];
    if (!labels.contains(label)) {
        labels.append(label);
        emit labelAdded(issueNumber, label);
        emit labelsUpdated(issueNumber, labels);
    }
}

void GitHubIssueLabelManager::removeLabel(int issueNumber, const QString& label)
{
    if (m_issueLabels.contains(issueNumber)) {
        QStringList& labels = m_issueLabels[issueNumber];
        if (labels.removeAll(label) > 0) {
            emit labelRemoved(issueNumber, label);
            emit labelsUpdated(issueNumber, labels);
        }
    }
}

void GitHubIssueLabelManager::setLabels(int issueNumber, const QStringList& labels)
{
    QStringList validLabels = filterValidLabels(labels);
    m_issueLabels[issueNumber] = validLabels;
    emit labelsUpdated(issueNumber, validLabels);
}

void GitHubIssueLabelManager::replaceLabelSet(
    int issueNumber,
    const QStringList& oldLabels,
    const QStringList& newLabels)
{
    if (!m_issueLabels.contains(issueNumber)) {
        return;
    }
    
    QStringList& currentLabels = m_issueLabels[issueNumber];
    
    // Remove old labels
    for (const QString& oldLabel : oldLabels) {
        currentLabels.removeAll(oldLabel);
    }
    
    // Add new labels
    QStringList validNewLabels = filterValidLabels(newLabels);
    for (const QString& newLabel : validNewLabels) {
        if (!currentLabels.contains(newLabel)) {
            currentLabels.append(newLabel);
        }
    }
    
    emit labelsUpdated(issueNumber, currentLabels);
}

void GitHubIssueLabelManager::performLabelOperations(const QList<LabelOperation>& operations)
{
    int successCount = 0;
    int failureCount = 0;
    
    for (const LabelOperation& op : operations) {
        bool issueSuccess = true;
        int issueNum = op.issueNumber.toInt();
        
        // Add labels
        for (const QString& label : op.labelsToAdd) {
            if (isValidLabel(label)) {
                addLabel(issueNum, label);
                successCount++;
            } else {
                failureCount++;
                issueSuccess = false;
            }
        }
        
        // Remove labels
        for (const QString& label : op.labelsToRemove) {
            if (isValidLabel(label)) {
                removeLabel(issueNum, label);
                successCount++;
            } else {
                failureCount++;
                issueSuccess = false;
            }
        }
        
        if (!issueSuccess) {
            emit labelOperationFailed(issueNum, "Some label operations failed");
        }
    }
    
    emit operationCompleted(successCount, failureCount);
}

void GitHubIssueLabelManager::applyBulkLabels(const QStringList& issueNumbers, const QStringList& labels)
{
    QStringList validLabels = filterValidLabels(labels);
    
    for (const QString& issueNum : issueNumbers) {
        for (const QString& label : validLabels) {
            addLabel(issueNum.toInt(), label);
        }
    }
}

void GitHubIssueLabelManager::removeBulkLabels(const QStringList& issueNumbers, const QStringList& labels)
{
    for (const QString& issueNum : issueNumbers) {
        for (const QString& label : labels) {
            removeLabel(issueNum.toInt(), label);
        }
    }
}

void GitHubIssueLabelManager::fetchRepositoryLabels(const QString& owner, const QString& repo)
{
    Q_UNUSED(owner);
    Q_UNUSED(repo);
    
    // Initialize with common default labels
    m_repositoryLabels["bug"] = {"bug", "d73a4a", "Something isn't working", true};
    m_repositoryLabels["enhancement"] = {"enhancement", "a2eeef", "New feature or request", true};
    m_repositoryLabels["documentation"] = {"documentation", "0075ca", "Improvements or additions to documentation", true};
    m_repositoryLabels["duplicate"] = {"duplicate", "cfd3d7", "This issue or pull request already exists", true};
    m_repositoryLabels["good first issue"] = {"good first issue", "7057ff", "Good for newcomers", true};
    m_repositoryLabels["help wanted"] = {"help wanted", "008672", "Extra attention is needed", true};
    m_repositoryLabels["invalid"] = {"invalid", "e4e669", "This doesn't seem right", true};
    m_repositoryLabels["question"] = {"question", "d876e3", "Further information is requested", true};
    m_repositoryLabels["wontfix"] = {"wontfix", "ffffff", "This will not be worked on", true};
    
    // Custom labels
    m_repositoryLabels["needs-info"] = {"needs-info", "ffa500", "Waiting for more information", false};
    m_repositoryLabels["needs-repro"] = {"needs-repro", "ff6b6b", "Need reproduction steps", false};
    m_repositoryLabels["stale"] = {"stale", "808080", "No recent activity", false};
    m_repositoryLabels["priority-high"] = {"priority-high", "ff0000", "High priority", false};
    m_repositoryLabels["priority-low"] = {"priority-low", "00ff00", "Low priority", false};
    
    for (auto it = m_repositoryLabels.begin(); it != m_repositoryLabels.end(); ++it) {
        m_validLabelNames.insert(it.key());
    }
    
    emit repositoryLabelsLoaded(m_repositoryLabels.count());
}

bool GitHubIssueLabelManager::isValidLabel(const QString& label) const
{
    return m_validLabelNames.contains(label);
}

QStringList GitHubIssueLabelManager::filterValidLabels(const QStringList& labels) const
{
    QStringList validLabels;
    for (const QString& label : labels) {
        if (isValidLabel(label)) {
            validLabels.append(label);
        }
    }
    return validLabels;
}

QStringList GitHubIssueLabelManager::getAvailableLabels() const
{
    return m_validLabelNames.values();
}

GitHubIssueLabelManager::LabelInfo GitHubIssueLabelManager::getLabelInfo(const QString& label) const
{
    if (m_repositoryLabels.contains(label)) {
        return m_repositoryLabels.value(label);
    }
    return {"", "", "", false};
}

QList<GitHubIssueLabelManager::LabelInfo> GitHubIssueLabelManager::getAllLabelInfo() const
{
    return m_repositoryLabels.values();
}

QStringList GitHubIssueLabelManager::getIssueLabels(int issueNumber)
{
    return m_issueLabels.value(issueNumber, QStringList());
}

bool GitHubIssueLabelManager::issueHasLabel(int issueNumber, const QString& label)
{
    return m_issueLabels.value(issueNumber, QStringList()).contains(label);
}

QStringList GitHubIssueLabelManager::categorizeLabelsByType(const QStringList& labels)
{
    QStringList categorized;
    
    QSet<QString> bugRelated = {"bug", "enhancement", "feature-request"};
    QSet<QString> statusRelated = {"needs-info", "needs-repro", "stale", "duplicate", "wontfix"};
    QSet<QString> priorityRelated = {"priority-high", "priority-low"};
    
    for (const QString& label : labels) {
        if (bugRelated.contains(label)) {
            categorized << "[Type] " + label;
        } else if (statusRelated.contains(label)) {
            categorized << "[Status] " + label;
        } else if (priorityRelated.contains(label)) {
            categorized << "[Priority] " + label;
        } else {
            categorized << label;
        }
    }
    
    return categorized;
}

QString GitHubIssueLabelManager::getPrimaryCategory(const QStringList& labels)
{
    // Priority order for determining primary category
    QStringList priorityOrder = {"bug", "enhancement", "priority-high", "needs-repro", "duplicate"};
    
    for (const QString& priority : priorityOrder) {
        if (labels.contains(priority)) {
            return priority;
        }
    }
    
    return labels.isEmpty() ? "" : labels.first();
}

int GitHubIssueLabelManager::getLabelUsageCount(const QString& label) const
{
    int count = 0;
    for (auto it = m_issueLabels.begin(); it != m_issueLabels.end(); ++it) {
        if (it.value().contains(label)) {
            count++;
        }
    }
    return count;
}

QMap<QString, int> GitHubIssueLabelManager::getLabelStatistics() const
{
    QMap<QString, int> stats;
    
    for (auto it = m_issueLabels.begin(); it != m_issueLabels.end(); ++it) {
        for (const QString& label : it.value()) {
            stats[label]++;
        }
    }
    
    return stats;
}

void GitHubIssueLabelManager::validateLabel(const QString& label)
{
    if (!isValidLabel(label)) {
        qWarning() << "Invalid label:" << label;
    }
}

void GitHubIssueLabelManager::applyLabel(int issueNumber, const QString& label)
{
    if (isValidLabel(label)) {
        addLabel(issueNumber, label);
    }
}

QString GitHubIssueLabelManager::generateLabelColor(const QString& labelName)
{
    // Simple hash-based color generation
    QHash<QChar, int> charValues;
    int sum = 0;
    
    for (const QChar& c : labelName) {
        sum += c.unicode();
    }
    
    int r = (sum * 73) % 256;
    int g = (sum * 149) % 256;
    int b = (sum * 229) % 256;
    
    return QString("%1%2%3").arg(r, 2, 16, QLatin1Char('0'))
                            .arg(g, 2, 16, QLatin1Char('0'))
                            .arg(b, 2, 16, QLatin1Char('0'));
}
