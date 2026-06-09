#include "IssueDuplicateAutoCloser.h"
#include <QStringList>
#include <QSet>
#include <QDebug>
#include <QRegularExpression>
#include <algorithm>
#include <cmath>

IssueDuplicateAutoCloser::IssueDuplicateAutoCloser(QObject* parent)
    : QObject(parent), m_autoCloseEnabled(true), m_backfillMode(false), m_similarityThreshold(0.7f)
{
}

IssueDuplicateAutoCloser::~IssueDuplicateAutoCloser()
{
}

float IssueDuplicateAutoCloser::calculateSimilarity(const QString& text1, const QString& text2)
{
    if (text1.trimmed().isEmpty() && text2.trimmed().isEmpty()) {
        return 1.0f;
    }
    if (text1.trimmed().isEmpty() || text2.trimmed().isEmpty()) {
        return 0.0f;
    }

    // Combine Levenshtein and Jaccard similarity for better accuracy
    float levenshtein = calculateLevenshteinSimilarity(text1, text2);
    float jaccard = calculateJaccardSimilarity(text1, text2);
    
    // Weighted average: Jaccard (60%) + Levenshtein (40%)
    return (jaccard * 0.6f) + (levenshtein * 0.4f);
}

float IssueDuplicateAutoCloser::calculateLevenshteinSimilarity(const QString& str1, const QString& str2)
{
    const QString& s1 = str1.toLower();
    const QString& s2 = str2.toLower();
    
    int len1 = s1.length();
    int len2 = s2.length();
    
    if (len1 == 0) return len2 == 0 ? 1.0f : 0.0f;
    if (len2 == 0) return 0.0f;
    
    // Calculate Levenshtein distance
    std::vector<std::vector<int>> dp(len1 + 1, std::vector<int>(len2 + 1));
    
    for (int i = 0; i <= len1; i++) dp[i][0] = i;
    for (int j = 0; j <= len2; j++) dp[0][j] = j;
    
    for (int i = 1; i <= len1; i++) {
        for (int j = 1; j <= len2; j++) {
            int cost = (s1[i-1] == s2[j-1]) ? 0 : 1;
            dp[i][j] = std::min({dp[i-1][j] + 1, dp[i][j-1] + 1, dp[i-1][j-1] + cost});
        }
    }
    
    int distance = dp[len1][len2];
    int maxLen = std::max(len1, len2);
    
    return 1.0f - (float)distance / maxLen;
}

float IssueDuplicateAutoCloser::calculateJaccardSimilarity(const QString& str1, const QString& str2)
{
    QStringList tokens1 = tokenize(str1);
    QStringList tokens2 = tokenize(str2);
    
    if (tokens1.isEmpty() && tokens2.isEmpty()) return 1.0f;
    if (tokens1.isEmpty() || tokens2.isEmpty()) return 0.0f;
    
    QSet<QString> set1(tokens1.begin(), tokens1.end());
    QSet<QString> set2(tokens2.begin(), tokens2.end());
    
    // Intersection size
    int intersection = 0;
    for (const QString& token : set1) {
        if (set2.contains(token)) {
            intersection++;
        }
    }
    
    // Union size
    int unionSize = set1.size() + set2.size() - intersection;
    
    if (unionSize == 0) return 0.0f;
    return (float)intersection / unionSize;
}

QStringList IssueDuplicateAutoCloser::tokenize(const QString& text)
{
    QStringList tokens;
    QString normalized = text.toLower();
    
    // Remove punctuation and split by whitespace
    normalized.replace(QRegularExpression("[^a-z0-9\\s]"), " ");
    tokens = normalized.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);
    
    // Remove common stop words
    QStringList stopWords = {"the", "a", "an", "and", "or", "in", "on", "at", "to", "for", "of"};
    tokens.erase(
        std::remove_if(tokens.begin(), tokens.end(),
            [&stopWords](const QString& token) { return stopWords.contains(token); }),
        tokens.end()
    );
    
    return tokens;
}

QList<int> IssueDuplicateAutoCloser::findDuplicateIssues(
    const QString& issueTitle,
    const QString& issueBody,
    const QJsonArray& existingIssues,
    float similarityThreshold)
{
    QList<int> duplicates;
    QString combinedText = issueTitle + " " + issueBody;
    
    for (const QJsonValue& issueValue : existingIssues) {
        QJsonObject issue = issueValue.toObject();
        
        QString existingTitle = issue.value("title").toString();
        QString existingBody = issue.value("body").toString();
        QString existingCombined = existingTitle + " " + existingBody;
        
        float similarity = calculateSimilarity(combinedText, existingCombined);
        
        if (similarity >= similarityThreshold) {
            int issueNumber = issue.value("number").toInt();
            duplicates.append(issueNumber);
        }
    }
    
    return duplicates;
}

void IssueDuplicateAutoCloser::autoClosed(
    int duplicateIssueNumber,
    int targetIssueNumber,
    const QString& comment)
{
    if (!m_autoCloseEnabled) {
        return;
    }
    
    QString closeComment = comment.isEmpty() ? generateDuplicateComment(targetIssueNumber) : comment;
    qDebug().noquote() << "[IssueDuplicateAutoCloser] duplicate close comment:" << closeComment;
    
    // Record the duplicate match
    DuplicateMatch match;
    match.issueNumber = duplicateIssueNumber;
    match.targetIssue = targetIssueNumber;
    match.similarity = 0.0f;
    
    m_processedDuplicates[duplicateIssueNumber] = match;

    emit duplicateDetected(duplicateIssueNumber, targetIssueNumber);
    emit labelAdded(duplicateIssueNumber, "duplicate");
    emit issueClosed(duplicateIssueNumber);
}

void IssueDuplicateAutoCloser::addDuplicateLabel(int issueNumber)
{
    emit labelAdded(issueNumber, "duplicate");
}

void IssueDuplicateAutoCloser::linkDuplicateIssues(int issue1, int issue2)
{
    // Record the relationship
    if (!m_processedDuplicates.contains(issue1)) {
        DuplicateMatch match;
        match.issueNumber = issue1;
        match.targetIssue = issue2;
        match.similarity = 1.0f;
        m_processedDuplicates[issue1] = match;
    }
}

void IssueDuplicateAutoCloser::processDuplicateIssues(const QJsonArray& issues)
{
    emit processingStarted();
    
    int duplicatesFound = 0;
    QSet<QString> handledPairs;
    
    // Compare each pair of issues
    for (int i = 0; i < issues.size(); i++) {
        QJsonObject currentIssue = issues[i].toObject();
        QString currentTitle = currentIssue.value("title").toString();
        QString currentBody = currentIssue.value("body").toString();
        int currentNumber = currentIssue.value("number").toInt();
        
        // Check against subsequent issues
        for (int j = i + 1; j < issues.size(); j++) {
            QJsonObject otherIssue = issues[j].toObject();
            QString otherTitle = otherIssue.value("title").toString();
            QString otherBody = otherIssue.value("body").toString();
            int otherNumber = otherIssue.value("number").toInt();

            QString pairKey = QStringLiteral("%1:%2")
                                  .arg(qMin(currentNumber, otherNumber))
                                  .arg(qMax(currentNumber, otherNumber));
            if (handledPairs.contains(pairKey)) {
                continue;
            }

            float similarity = calculateSimilarity(currentTitle + currentBody, otherTitle + otherBody);
            
            if (similarity >= m_similarityThreshold) {
                // Current issue is duplicate of other (use older/lower number as target)
                int duplicateIssue = currentNumber > otherNumber ? currentNumber : otherNumber;
                int targetIssue = currentNumber > otherNumber ? otherNumber : currentNumber;
                
                autoClosed(
                    duplicateIssue,
                    targetIssue,
                    m_backfillMode ? generateBackfillComment(otherTitle) : QString());
                handledPairs.insert(pairKey);
                duplicatesFound++;
            }
        }
    }
    
    emit processingFinished(duplicatesFound);
}

void IssueDuplicateAutoCloser::setSimilarityThreshold(float threshold)
{
    m_similarityThreshold = qBound(0.0f, threshold, 1.0f);
}

void IssueDuplicateAutoCloser::setAutoCloseEnabled(bool enabled)
{
    m_autoCloseEnabled = enabled;
}

void IssueDuplicateAutoCloser::setBackfillMode(bool enabled)
{
    m_backfillMode = enabled;
}

QString IssueDuplicateAutoCloser::generateDuplicateComment(int targetIssueNumber)
{
    return QString(
        "Duplicate of #%1. This issue has been automatically detected as a duplicate "
        "and is being closed. Please follow the original issue for updates and discussion."
    ).arg(targetIssueNumber);
}

QString IssueDuplicateAutoCloser::generateBackfillComment(const QString& duplicateTitle)
{
    return QString(
        "This is a duplicate of: **%1**\n\n"
        "The following issue was automatically detected as a duplicate during backfill processing."
    ).arg(duplicateTitle);
}

QString IssueDuplicateAutoCloser::generateDefaultComment(int targetIssueNumber)
{
    return generateDuplicateComment(targetIssueNumber);
}
