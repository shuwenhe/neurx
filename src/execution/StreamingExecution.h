#pragma once

#include <QString>
#include <QVector>
#include <QVariantMap>
#include <QDateTime>
#include <memory>
#include <functional>

/**
 * @brief CommandOutput - 命令实时输出
 */
struct CommandOutput {
    enum class Type { Stdout, Stderr, Status, Error };

    Type type;
    QString content;
    QDateTime timestamp;
    int lineNumber = 0;

    bool isError() const { return type == Type::Stderr || type == Type::Error; }
};

/**
 * @brief StreamingShellTool - 支持流式输出的Shell工具
 */
class StreamingShellTool {
public:
    using OutputCallback = std::function<void(const CommandOutput&)>;

    explicit StreamingShellTool();

    /**
     * @brief 执行命令并流式输出
     */
    int executeStreaming(
        const QString &command,
        OutputCallback onOutput,
        int timeoutMs = 30000);

    /**
     * @brief 停止正在运行的命令
     */
    bool stopCommand(int processId);

    /**
     * @brief 发送输入到命令
     */
    bool sendInput(int processId, const QString &input);

    /**
     * @brief 检查是否有错误
     */
    bool hasErrors(int processId) const;

    /**
     * @brief 获取执行状态
     */
    QString getStatus(int processId) const;

private:
    struct ProcessInfo {
        int processId;
        QString command;
        QDateTime startTime;
        bool hasError = false;
        QVector<CommandOutput> outputs;
    };

    QVector<ProcessInfo> m_processes;
};

/**
 * @brief FileChangeEvent - 文件变更事件
 */
struct FileChangeEvent {
    enum class Type { Created, Modified, Deleted, Renamed };

    Type type;
    QString filePath;
    QString originalPath;    // 对于Renamed
    QDateTime timestamp;
    qint64 fileSize = 0;
    QString hash;            // 文件内容哈希
};

/**
 * @brief FileDiff - 文件差异
 */
struct FileDiff {
    QString filePath;
    QString originalContent;
    QString modifiedContent;
    QVector<QPair<int, QString>> additions;      // 行号, 内容
    QVector<QPair<int, QString>> deletions;      // 行号, 内容
    QVector<QPair<int, QPair<QString, QString>>> modifications;  // 行号, (原文本, 新文本)

    int getAddedLineCount() const { return additions.size(); }
    int getDeletedLineCount() const { return deletions.size(); }
    int getModifiedLineCount() const { return modifications.size(); }
};

/**
 * @brief DiffTracker - 文件变更追踪
 */
class DiffTracker {
public:
    explicit DiffTracker();

    /**
     * @brief 记录文件变更
     */
    void recordChange(const FileChangeEvent &event);

    /**
     * @brief 获取所有变更
     */
    QVector<FileChangeEvent> getAllChanges() const;

    /**
     * @brief 获取特定文件的变更
     */
    QVector<FileChangeEvent> getChangesForFile(const QString &filePath) const;

    /**
     * @brief 计算差异
     */
    FileDiff calculateDiff(const QString &filePath,
                          const QString &originalContent,
                          const QString &modifiedContent) const;

    /**
     * @brief 获取修改的文件列表
     */
    QVector<QString> getModifiedFiles() const;

    /**
     * @brief 获取创建的文件列表
     */
    QVector<QString> getCreatedFiles() const;

    /**
     * @brief 获取删除的文件列表
     */
    QVector<QString> getDeletedFiles() const;

    /**
     * @brief 清空追踪
     */
    void clear();

private:
    QVector<FileChangeEvent> m_changes;
};

/**
 * @brief CheckpointViewer - 检查点预览和回滚UI
 */
class CheckpointViewer {
public:
    explicit CheckpointViewer();

    /**
     * @brief 预览检查点中的文件
     */
    QString previewCheckpointFile(int checkpointIndex, const QString &filePath) const;

    /**
     * @brief 比较两个检查点
     */
    FileDiff compareCheckpoints(int checkpointIndex1, int checkpointIndex2,
                                const QString &filePath) const;

    /**
     * @brief 获取检查点摘要
     */
    QVariantMap getCheckpointSummary(int checkpointIndex) const;

    /**
     * @brief 执行回滚
     */
    bool rollback(int checkpointIndex);

private:
    QVector<QVariantMap> m_checkpoints;
};
