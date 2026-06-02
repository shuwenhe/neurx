#include "CollaborationTools.h"
#include <QDebug>
#include <QFile>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>

// CollaborativeEditor 实现

CollaborativeEditor::CollaborativeEditor()
    : m_documentVersion(0) {
}

void CollaborativeEditor::addUser(const QString &userId, const QString &userName) {
    UserPresence presence;
    presence.userId = userId;
    presence.userName = userName;
    presence.lastUpdate = QDateTime::currentDateTime();
    m_users[userId] = presence;
    qDebug() << "User added:" << userName;
}

void CollaborativeEditor::removeUser(const QString &userId) {
    m_users.remove(userId);
    qDebug() << "User removed:" << userId;
}

QVector<UserPresence> CollaborativeEditor::getActiveUsers() const {
    QVector<UserPresence> users;
    for (const auto &presence : m_users) {
        users.append(presence);
    }
    return users;
}

void CollaborativeEditor::recordOperation(const EditOperation &op) {
    m_operations.append(op);
    updateContent(op);
    m_documentVersion++;
    qDebug() << "Operation recorded:" << op.operationId << "Version:" << m_documentVersion;
}

bool CollaborativeEditor::applyRemoteOperation(const EditOperation &op) {
    // 简化的OT实现 - 实际产品应使用完整的OT算法
    recordOperation(op);
    return true;
}

QVector<EditOperation> CollaborativeEditor::getUnacknowledgedOperations(const QString &userId) const {
    QVector<EditOperation> ops;
    for (const auto &op : m_operations) {
        if (op.userId == userId && !op.synced) {
            ops.append(op);
        }
    }
    return ops;
}

EditOperation CollaborativeEditor::transformOperation(const EditOperation &op1, const EditOperation &op2) const {
    // 简化的Operational Transform
    EditOperation transformed = op1;
    
    if (op1.type == EditOperation::Type::Insert &&
        op2.type == EditOperation::Type::Insert) {
        // 两个插入操作：需要检查位置冲突
        if (op1.position < op2.position) {
            op2.position += op1.content.length();
        }
    }
    
    return transformed;
}

QVector<EditOperation> CollaborativeEditor::getOperationHistory(int fromVersion) const {
    QVector<EditOperation> history;
    for (const auto &op : m_operations) {
        if (op.version >= fromVersion) {
            history.append(op);
        }
    }
    return history;
}

void CollaborativeEditor::updateContent(const EditOperation &op) {
    switch (op.type) {
    case EditOperation::Type::Insert:
        m_content.insert(op.position, op.content);
        break;
    case EditOperation::Type::Delete:
        m_content.remove(op.position, op.length);
        break;
    case EditOperation::Type::Replace:
        m_content.replace(op.position, op.length, op.content);
        break;
    }
}

// LogPersistence 实现

LogPersistence::LogPersistence(const QString &logDir)
    : m_logDir(logDir) {
    QDir dir(m_logDir);
    if (!dir.exists()) {
        dir.mkpath(".");
    }
}

void LogPersistence::writeLog(const LogEntry &entry) {
    m_inMemoryLogs.append(entry);
    qDebug() << "[" << getLevelString(entry.level) << "]"
             << entry.category << ":" << entry.message;
}

void LogPersistence::writeDebug(const QString &category, const QString &msg) {
    LogEntry entry;
    entry.level = LogEntry::Level::Debug;
    entry.category = category;
    entry.message = msg;
    entry.timestamp = QDateTime::currentDateTime();
    writeLog(entry);
}

void LogPersistence::writeInfo(const QString &category, const QString &msg) {
    LogEntry entry;
    entry.level = LogEntry::Level::Info;
    entry.category = category;
    entry.message = msg;
    entry.timestamp = QDateTime::currentDateTime();
    writeLog(entry);
}

void LogPersistence::writeWarning(const QString &category, const QString &msg) {
    LogEntry entry;
    entry.level = LogEntry::Level::Warning;
    entry.category = category;
    entry.message = msg;
    entry.timestamp = QDateTime::currentDateTime();
    writeLog(entry);
}

void LogPersistence::writeError(const QString &category, const QString &msg) {
    LogEntry entry;
    entry.level = LogEntry::Level::Error;
    entry.category = category;
    entry.message = msg;
    entry.timestamp = QDateTime::currentDateTime();
    writeLog(entry);
}

void LogPersistence::writeCritical(const QString &category, const QString &msg) {
    LogEntry entry;
    entry.level = LogEntry::Level::Critical;
    entry.category = category;
    entry.message = msg;
    entry.timestamp = QDateTime::currentDateTime();
    writeLog(entry);
}

QVector<LogEntry> LogPersistence::queryLogs(const QString &category, int limit) const {
    QVector<LogEntry> result;
    int count = 0;

    // 从后向前遍历，获取最新的日志
    for (int i = m_inMemoryLogs.size() - 1; i >= 0 && count < limit; --i) {
        if (category.isEmpty() || m_inMemoryLogs[i].category == category) {
            result.prepend(m_inMemoryLogs[i]);
            count++;
        }
    }

    return result;
}

QVector<LogEntry> LogPersistence::queryLogsByTimeRange(const QDateTime &start, const QDateTime &end) const {
    QVector<LogEntry> result;

    for (const auto &entry : m_inMemoryLogs) {
        if (entry.timestamp >= start && entry.timestamp <= end) {
            result.append(entry);
        }
    }

    return result;
}

QVector<LogEntry> LogPersistence::queryLogsByLevel(LogEntry::Level level) const {
    QVector<LogEntry> result;

    for (const auto &entry : m_inMemoryLogs) {
        if (entry.level == level) {
            result.append(entry);
        }
    }

    return result;
}

void LogPersistence::rotateLogs(int maxFileSizeMB, int maxDays) {
    Q_UNUSED(maxFileSizeMB);
    Q_UNUSED(maxDays);
    // 日志轮转实现
    qDebug() << "Rotating logs...";
}

void LogPersistence::exportLogs(const QString &exportPath, const QDateTime &start, const QDateTime &end) const {
    auto logs = queryLogsByTimeRange(start, end);

    QFile file(exportPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "Failed to export logs to:" << exportPath;
        return;
    }

    for (const auto &log : logs) {
        QString line = QString("%1 [%2] %3: %4\n")
            .arg(log.timestamp.toString(Qt::ISODate))
            .arg(getLevelString(log.level))
            .arg(log.category)
            .arg(log.message);
        file.write(line.toUtf8());
    }

    file.close();
    qDebug() << "Logs exported to:" << exportPath;
}

void LogPersistence::clearLogs(int olderThanDays) {
    QDateTime cutoffTime = QDateTime::currentDateTime().addDays(-olderThanDays);
    int removed = 0;

    for (int i = m_inMemoryLogs.size() - 1; i >= 0; --i) {
        if (m_inMemoryLogs[i].timestamp < cutoffTime) {
            m_inMemoryLogs.removeAt(i);
            removed++;
        }
    }

    qDebug() << "Cleared" << removed << "old log entries";
}

int LogPersistence::getLogCount() const {
    return m_inMemoryLogs.size();
}

QMap<QString, int> LogPersistence::getLogCountByCategory() const {
    QMap<QString, int> counts;
    for (const auto &log : m_inMemoryLogs) {
        counts[log.category]++;
    }
    return counts;
}

QMap<LogEntry::Level, int> LogPersistence::getLogCountByLevel() const {
    QMap<LogEntry::Level, int> counts;
    for (const auto &log : m_inMemoryLogs) {
        counts[log.level]++;
    }
    return counts;
}

QString LogPersistence::getLevelString(LogEntry::Level level) const {
    switch (level) {
    case LogEntry::Level::Debug: return "DEBUG";
    case LogEntry::Level::Info: return "INFO";
    case LogEntry::Level::Warning: return "WARN";
    case LogEntry::Level::Error: return "ERROR";
    case LogEntry::Level::Critical: return "CRITICAL";
    default: return "UNKNOWN";
    }
}

void LogPersistence::flushLogs() {
    // 将内存日志写入文件
    QString filename = QString("%1/session_%2.log")
        .arg(m_logDir)
        .arg(QDateTime::currentDateTime().toString("yyyyMMdd_hhmmss"));

    QFile file(filename);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        for (const auto &log : m_inMemoryLogs) {
            QString line = QString("%1 [%2] %3: %4\n")
                .arg(log.timestamp.toString(Qt::ISODate))
                .arg(getLevelString(log.level))
                .arg(log.category)
                .arg(log.message);
            file.write(line.toUtf8());
        }
        file.close();
    }
}

// DiffVisualization 实现

DiffVisualization::DiffVisualization() {
}

QString DiffVisualization::generateHtmlDiff(const QString &originalContent, const QString &modifiedContent) const {
    QString html = "<div class='diff'>\n";

    QStringList origLines = originalContent.split('\n');
    QStringList modLines = modifiedContent.split('\n');

    for (int i = 0; i < qMax(origLines.size(), modLines.size()); ++i) {
        html += "<div class='diff-line'>";

        if (i < origLines.size()) {
            html += QString("<span class='removed'>- %1</span>").arg(origLines[i]);
        }
        html += "<br/>";

        if (i < modLines.size()) {
            html += QString("<span class='added'>+ %1</span>").arg(modLines[i]);
        }

        html += "</div>\n";
    }

    html += "</div>";
    return html;
}

QString DiffVisualization::generateMarkdownDiff(const QString &originalContent, const QString &modifiedContent) const {
    QString markdown = "```diff\n";

    QStringList origLines = originalContent.split('\n');
    QStringList modLines = modifiedContent.split('\n');

    for (int i = 0; i < qMax(origLines.size(), modLines.size()); ++i) {
        if (i < origLines.size()) {
            markdown += QString("- %1\n").arg(origLines[i]);
        }
        if (i < modLines.size()) {
            markdown += QString("+ %1\n").arg(modLines[i]);
        }
    }

    markdown += "```";
    return markdown;
}

QString DiffVisualization::generateSideBySideDiff(const QString &originalContent, const QString &modifiedContent) const {
    QString html = "<table class='diff-table'>\n";

    QStringList origLines = originalContent.split('\n');
    QStringList modLines = modifiedContent.split('\n');

    for (int i = 0; i < qMax(origLines.size(), modLines.size()); ++i) {
        html += "<tr>";

        // 原始内容列
        if (i < origLines.size()) {
            html += QString("<td class='original'>%1</td>").arg(origLines[i]);
        } else {
            html += "<td class='original'></td>";
        }

        // 修改后内容列
        if (i < modLines.size()) {
            html += QString("<td class='modified'>%1</td>").arg(modLines[i]);
        } else {
            html += "<td class='modified'></td>";
        }

        html += "</tr>\n";
    }

    html += "</table>";
    return html;
}

QString DiffVisualization::highlightDiffLine(const QString &line, bool isAddition) const {
    if (isAddition) {
        return QString("<span style='background-color: #ccffcc; color: #00aa00;'>%1</span>").arg(line);
    } else {
        return QString("<span style='background-color: #ffcccc; color: #aa0000;'>%1</span>").arg(line);
    }
}

DiffVisualization::DiffStats DiffVisualization::calculateDiffStats(const QString &originalContent, const QString &modifiedContent) const {
    DiffStats stats;

    QStringList origLines = originalContent.split('\n');
    QStringList modLines = modifiedContent.split('\n');

    stats.totalLines = qMax(origLines.size(), modLines.size());
    stats.addedLines = qMax(0, modLines.size() - origLines.size());
    stats.deletedLines = qMax(0, origLines.size() - modLines.size());

    // 简化计算 - 实际应使用更复杂的diff算法
    stats.modifiedLines = qMin(origLines.size(), modLines.size()) - stats.addedLines - stats.deletedLines;

    if (stats.totalLines > 0) {
        stats.changePercentage = ((stats.addedLines + stats.deletedLines + stats.modifiedLines) * 100.0f) / stats.totalLines;
    }

    return stats;
}

QString DiffVisualization::colorizeHtml(const QString &html) const {
    return html;
}
