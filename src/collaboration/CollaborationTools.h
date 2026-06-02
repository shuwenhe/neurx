#pragma once

#include <QString>
#include <QVector>
#include <QMap>
#include <QDateTime>

/**
 * @brief UserPresence - 用户在线状态
 */
struct UserPresence {
    QString userId;
    QString userName;
    int cursorLine = -1;
    int cursorColumn = -1;
    QString color;           // 用户颜色标识
    QDateTime lastUpdate;
};

/**
 * @brief EditOperation - 编辑操作（Operational Transformation）
 */
struct EditOperation {
    enum class Type { Insert, Delete, Replace };

    QString operationId;
    QString userId;
    Type type;
    int position;           // 文本位置
    QString content;        // 插入/替换的内容
    int length = 0;         // 删除的长度
    int version = 0;        // 文档版本号
    QDateTime timestamp;
    bool synced = false;    // 是否已同步到其他用户
};

/**
 * @brief CollaborativeEditor - 协作编辑引擎
 */
class CollaborativeEditor {
public:
    explicit CollaborativeEditor();

    // 用户管理
    void addUser(const QString &userId, const QString &userName);
    void removeUser(const QString &userId);
    QVector<UserPresence> getActiveUsers() const;

    // 编辑操作
    void recordOperation(const EditOperation &op);
    bool applyRemoteOperation(const EditOperation &op);
    QVector<EditOperation> getUnacknowledgedOperations(const QString &userId) const;

    // 冲突解决（简化的OT）
    EditOperation transformOperation(const EditOperation &op1, const EditOperation &op2) const;

    // 查询
    int getCurrentVersion() const { return m_documentVersion; }
    QString getCurrentContent() const { return m_content; }
    QVector<EditOperation> getOperationHistory(int fromVersion = 0) const;

private:
    QString m_content;
    int m_documentVersion = 0;
    QMap<QString, UserPresence> m_users;
    QVector<EditOperation> m_operations;

    void updateContent(const EditOperation &op);
};

/**
 * @brief LogEntry - 日志条目
 */
struct LogEntry {
    enum class Level { Debug, Info, Warning, Error, Critical };

    Level level;
    QString category;       // 日志类别 (execution/permission/task等)
    QString message;
    QDateTime timestamp;
    QString userId;         // 操作用户
    QVariantMap metadata;   // 扩展数据
};

/**
 * @brief LogPersistence - 日志持久化
 */
class LogPersistence {
public:
    explicit LogPersistence(const QString &logDir = "./logs");

    // 写入日志
    void writeLog(const LogEntry &entry);
    void writeDebug(const QString &category, const QString &msg);
    void writeInfo(const QString &category, const QString &msg);
    void writeWarning(const QString &category, const QString &msg);
    void writeError(const QString &category, const QString &msg);
    void writeCritical(const QString &category, const QString &msg);

    // 查询日志
    QVector<LogEntry> queryLogs(const QString &category = "", int limit = 1000) const;
    QVector<LogEntry> queryLogsByTimeRange(const QDateTime &start, const QDateTime &end) const;
    QVector<LogEntry> queryLogsByLevel(LogEntry::Level level) const;

    // 日志文件管理
    void rotateLogs(int maxFileSizeMB = 100, int maxDays = 30);
    void exportLogs(const QString &exportPath, const QDateTime &start, const QDateTime &end) const;
    void clearLogs(int olderThanDays = 30);

    // 统计
    int getLogCount() const;
    QMap<QString, int> getLogCountByCategory() const;
    QMap<LogEntry::Level, int> getLogCountByLevel() const;

private:
    QString m_logDir;
    QVector<LogEntry> m_inMemoryLogs;  // 当前会话日志

    QString getLevelString(LogEntry::Level level) const;
    void flushLogs();
};

/**
 * @brief DiffVisualization - Diff可视化
 */
class DiffVisualization {
public:
    explicit DiffVisualization();

    /**
     * @brief 生成HTML格式的Diff视图
     */
    QString generateHtmlDiff(const QString &originalContent, const QString &modifiedContent) const;

    /**
     * @brief 生成Markdown格式的Diff
     */
    QString generateMarkdownDiff(const QString &originalContent, const QString &modifiedContent) const;

    /**
     * @brief 生成侧边栏比较视图
     */
    QString generateSideBySideDiff(const QString &originalContent, const QString &modifiedContent) const;

    /**
     * @brief 高亮特定行
     */
    QString highlightDiffLine(const QString &line, bool isAddition) const;

    /**
     * @brief 统计变更统计
     */
    struct DiffStats {
        int totalLines = 0;
        int addedLines = 0;
        int deletedLines = 0;
        int modifiedLines = 0;
        float changePercentage = 0.0f;
    };

    DiffStats calculateDiffStats(const QString &originalContent, const QString &modifiedContent) const;

private:
    QString colorizeHtml(const QString &html) const;
};
