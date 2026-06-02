#include "StreamingExecution.h"
#include <QDebug>
#include <QProcess>
#include <QCryptographicHash>
#include <QDateTime>

// StreamingShellTool 实现

StreamingShellTool::StreamingShellTool() {
}

int StreamingShellTool::executeStreaming(
    const QString &command,
    OutputCallback onOutput,
    int timeoutMs) {

    static int nextProcessId = 1;
    int processId = nextProcessId++;

    ProcessInfo info;
    info.processId = processId;
    info.command = command;
    info.startTime = QDateTime::currentDateTime();

    // 模拟命令执行输出
    CommandOutput output;
    output.type = CommandOutput::Type::Status;
    output.timestamp = QDateTime::currentDateTime();

    // 输出初始信息
    output.content = QString("Starting: %1").arg(command);
    if (onOutput) onOutput(output);
    info.outputs.append(output);

    // 模拟执行
    output.content = "Executing...";
    output.type = CommandOutput::Type::Stdout;
    if (onOutput) onOutput(output);
    info.outputs.append(output);

    // 模拟结果
    output.content = "Command completed successfully";
    output.type = CommandOutput::Type::Status;
    if (onOutput) onOutput(output);
    info.outputs.append(output);

    m_processes.append(info);
    return processId;
}

bool StreamingShellTool::stopCommand(int processId) {
    for (auto &info : m_processes) {
        if (info.processId == processId) {
            CommandOutput output;
            output.type = CommandOutput::Type::Status;
            output.content = "Command stopped";
            output.timestamp = QDateTime::currentDateTime();
            info.outputs.append(output);
            return true;
        }
    }
    return false;
}

bool StreamingShellTool::sendInput(int processId, const QString &input) {
    for (auto &info : m_processes) {
        if (info.processId == processId) {
            CommandOutput output;
            output.type = CommandOutput::Type::Stdout;
            output.content = input;
            output.timestamp = QDateTime::currentDateTime();
            info.outputs.append(output);
            return true;
        }
    }
    return false;
}

bool StreamingShellTool::hasErrors(int processId) const {
    for (const auto &info : m_processes) {
        if (info.processId == processId) {
            return info.hasError;
        }
    }
    return false;
}

QString StreamingShellTool::getStatus(int processId) const {
    for (const auto &info : m_processes) {
        if (info.processId == processId) {
            return QString("Process %1: %2").arg(processId).arg(info.command);
        }
    }
    return "Unknown process";
}

// DiffTracker 实现

DiffTracker::DiffTracker() {
}

void DiffTracker::recordChange(const FileChangeEvent &event) {
    m_changes.append(event);
    QString typeStr = event.type == FileChangeEvent::Type::Created ? "Created" :
                      event.type == FileChangeEvent::Type::Modified ? "Modified" :
                      event.type == FileChangeEvent::Type::Deleted ? "Deleted" : "Renamed";
    qDebug() << "File change recorded:" << typeStr << event.filePath;
}

QVector<FileChangeEvent> DiffTracker::getAllChanges() const {
    return m_changes;
}

QVector<FileChangeEvent> DiffTracker::getChangesForFile(const QString &filePath) const {
    QVector<FileChangeEvent> result;
    for (const auto &event : m_changes) {
        if (event.filePath == filePath) {
            result.append(event);
        }
    }
    return result;
}

FileDiff DiffTracker::calculateDiff(const QString &filePath,
                                   const QString &originalContent,
                                   const QString &modifiedContent) const {

    FileDiff diff;
    diff.filePath = filePath;
    diff.originalContent = originalContent;
    diff.modifiedContent = modifiedContent;

    QStringList originalLines = originalContent.split('\n');
    QStringList modifiedLines = modifiedContent.split('\n');

    // 简化的差异计算 - 实际应使用Myers算法
    int i = 0, j = 0;
    while (i < originalLines.size() && j < modifiedLines.size()) {
        if (originalLines[i] == modifiedLines[j]) {
            i++;
            j++;
        } else {
            // 记录删除
            if (i < originalLines.size()) {
                diff.deletions.append({i + 1, originalLines[i]});
                i++;
            }
            // 记录添加
            if (j < modifiedLines.size()) {
                diff.additions.append({j + 1, modifiedLines[j]});
                j++;
            }
        }
    }

    // 处理剩余行
    while (i < originalLines.size()) {
        diff.deletions.append({i + 1, originalLines[i]});
        i++;
    }

    while (j < modifiedLines.size()) {
        diff.additions.append({j + 1, modifiedLines[j]});
        j++;
    }

    return diff;
}

QVector<QString> DiffTracker::getModifiedFiles() const {
    QVector<QString> result;
    for (const auto &event : m_changes) {
        if (event.type == FileChangeEvent::Type::Modified &&
            !result.contains(event.filePath)) {
            result.append(event.filePath);
        }
    }
    return result;
}

QVector<QString> DiffTracker::getCreatedFiles() const {
    QVector<QString> result;
    for (const auto &event : m_changes) {
        if (event.type == FileChangeEvent::Type::Created &&
            !result.contains(event.filePath)) {
            result.append(event.filePath);
        }
    }
    return result;
}

QVector<QString> DiffTracker::getDeletedFiles() const {
    QVector<QString> result;
    for (const auto &event : m_changes) {
        if (event.type == FileChangeEvent::Type::Deleted &&
            !result.contains(event.filePath)) {
            result.append(event.filePath);
        }
    }
    return result;
}

void DiffTracker::clear() {
    m_changes.clear();
}

// CheckpointViewer 实现

CheckpointViewer::CheckpointViewer() {
}

QString CheckpointViewer::previewCheckpointFile(int checkpointIndex, const QString &filePath) const {
    if (checkpointIndex < 0 || checkpointIndex >= m_checkpoints.size()) {
        return "";
    }

    // 模拟检查点中的文件预览
    return QString("Content of %1 at checkpoint %2").arg(filePath).arg(checkpointIndex);
}

FileDiff CheckpointViewer::compareCheckpoints(int checkpointIndex1, int checkpointIndex2,
                                              const QString &filePath) const {
    FileDiff diff;
    diff.filePath = filePath;

    if (checkpointIndex1 < 0 || checkpointIndex1 >= m_checkpoints.size() ||
        checkpointIndex2 < 0 || checkpointIndex2 >= m_checkpoints.size()) {
        return diff;
    }

    // 模拟比较
    diff.originalContent = QString("Content at checkpoint %1").arg(checkpointIndex1);
    diff.modifiedContent = QString("Content at checkpoint %1").arg(checkpointIndex2);

    return diff;
}

QVariantMap CheckpointViewer::getCheckpointSummary(int checkpointIndex) const {
    QVariantMap summary;

    if (checkpointIndex >= 0 && checkpointIndex < m_checkpoints.size()) {
        summary = m_checkpoints[checkpointIndex];
    } else {
        summary["index"] = checkpointIndex;
        summary["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
        summary["status"] = "Invalid checkpoint";
    }

    return summary;
}

bool CheckpointViewer::rollback(int checkpointIndex) {
    if (checkpointIndex < 0 || checkpointIndex >= m_checkpoints.size()) {
        qWarning() << "Cannot rollback to invalid checkpoint:" << checkpointIndex;
        return false;
    }

    qDebug() << "Rolling back to checkpoint:" << checkpointIndex;
    return true;
}
