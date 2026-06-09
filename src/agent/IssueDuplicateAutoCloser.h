#ifndef ISSUE_DUPLICATE_AUTO_CLOSER_H
#define ISSUE_DUPLICATE_AUTO_CLOSER_H

#include <QObject>
#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QMap>
#include <memory>

/**
 * IssueDuplicateAutoCloser
 *
 * Automatically detects and closes duplicate GitHub issues.
 * Features:
 * - Duplicate detection using text similarity
 * - Automatic issue closing with proper comments
 * - Duplicate linking and references
 * - Batch processing of issues
 */
class IssueDuplicateAutoCloser : public QObject {
    Q_OBJECT

public:
    explicit IssueDuplicateAutoCloser(QObject* parent = nullptr);
    ~IssueDuplicateAutoCloser();

    // Duplicate detection
    float calculateSimilarity(const QString& text1, const QString& text2);
    QList<int> findDuplicateIssues(
        const QString& issueTitle,
        const QString& issueBody,
        const QJsonArray& existingIssues,
        float similarityThreshold = 0.7f
    );
    
    // Auto-close operations
    void autoClosed(
        int duplicateIssueNumber,
        int targetIssueNumber,
        const QString& comment = QString()
    );
    
    void addDuplicateLabel(int issueNumber);
    void linkDuplicateIssues(int issue1, int issue2);
    
    // Batch operations
    void processDuplicateIssues(const QJsonArray& issues);
    
    // Configuration
    void setSimilarityThreshold(float threshold);
    void setAutoCloseEnabled(bool enabled);
    void setBackfillMode(bool enabled);
    
    // Comment generation
    QString generateDuplicateComment(int targetIssueNumber);
    QString generateBackfillComment(const QString& duplicateTitle);

signals:
    void duplicateDetected(int issueNumber, int duplicateOf);
    void issueClosed(int issueNumber);
    void labelAdded(int issueNumber, const QString& label);
    void processingStarted();
    void processingFinished(int duplicatesFound);

private:
    struct DuplicateMatch {
        int issueNumber;
        float similarity;
        int targetIssue;
    };

    float calculateLevenshteinSimilarity(const QString& str1, const QString& str2);
    float calculateJaccardSimilarity(const QString& str1, const QString& str2);
    QStringList tokenize(const QString& text);
    QString generateDefaultComment(int targetIssueNumber);
    
    bool m_autoCloseEnabled;
    bool m_backfillMode;
    float m_similarityThreshold;
    QMap<int, DuplicateMatch> m_processedDuplicates;
};

#endif // ISSUE_DUPLICATE_AUTO_CLOSER_H
