#include "UIModels.h"
#include <QDateTime>

// StreamingOutputModel 实现

StreamingOutputModel::StreamingOutputModel(QObject *parent)
    : QAbstractListModel(parent) {
}

int StreamingOutputModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_lines.size();
}

QVariant StreamingOutputModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_lines.size()) {
        return QVariant();
    }

    const auto &line = m_lines[index.row()];

    switch (role) {
    case ContentRole:
        return line.content;
    case TypeRole:
        return line.isError ? "error" : "output";
    case TimestampRole:
        return line.timestamp;
    case IsErrorRole:
        return line.isError;
    case Qt::DisplayRole:
        return line.content;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> StreamingOutputModel::roleNames() const {
    return {
        {ContentRole, "content"},
        {TypeRole, "type"},
        {TimestampRole, "timestamp"},
        {IsErrorRole, "isError"}
    };
}

void StreamingOutputModel::addOutput(const QString &content, bool isError) {
    beginInsertRows(QModelIndex(), m_lines.size(), m_lines.size());
    OutputLine line;
    line.content = content;
    line.isError = isError;
    line.timestamp = QDateTime::currentDateTime().toString("hh:mm:ss");
    m_lines.append(line);
    endInsertRows();
}

void StreamingOutputModel::addStatusUpdate(const QString &status) {
    addOutput(QString("[%1] %2").arg(QDateTime::currentDateTime().toString("hh:mm:ss"), status));
}

void StreamingOutputModel::clear() {
    beginResetModel();
    m_lines.clear();
    endResetModel();
}

// DiffViewModel 实现

DiffViewModel::DiffViewModel(QObject *parent)
    : QAbstractListModel(parent) {
}

int DiffViewModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_diffs.size();
}

QVariant DiffViewModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_diffs.size()) {
        return QVariant();
    }

    const auto &diff = m_diffs[index.row()];

    switch (role) {
    case FilePathRole:
        return diff.filePath;
    case AdditionsRole:
        return diff.additions;
    case DeletionsRole:
        return diff.deletions;
    case ModificationsRole:
        return diff.modifications;
    case SummaryRole: {
        return QString("%1 file: +%2 -%3 ~%4")
            .arg(diff.filePath)
            .arg(diff.additions)
            .arg(diff.deletions)
            .arg(diff.modifications);
    }
    case Qt::DisplayRole:
        return diff.filePath;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> DiffViewModel::roleNames() const {
    return {
        {FilePathRole, "filePath"},
        {AdditionsRole, "additions"},
        {DeletionsRole, "deletions"},
        {ModificationsRole, "modifications"},
        {SummaryRole, "summary"}
    };
}

void DiffViewModel::addDiff(const QString &filePath, int additions, int deletions, int modifications) {
    beginInsertRows(QModelIndex(), m_diffs.size(), m_diffs.size());
    DiffEntry entry;
    entry.filePath = filePath;
    entry.additions = additions;
    entry.deletions = deletions;
    entry.modifications = modifications;
    m_diffs.append(entry);
    endInsertRows();
}

QString DiffViewModel::getDiffSummary() const {
    int totalAdditions = 0, totalDeletions = 0, totalModifications = 0;

    for (const auto &diff : m_diffs) {
        totalAdditions += diff.additions;
        totalDeletions += diff.deletions;
        totalModifications += diff.modifications;
    }

    return QString("Total: +%1 -%2 ~%3 in %4 files")
        .arg(totalAdditions)
        .arg(totalDeletions)
        .arg(totalModifications)
        .arg(m_diffs.size());
}

void DiffViewModel::clear() {
    beginResetModel();
    m_diffs.clear();
    endResetModel();
}

// CheckpointListModel 实现

CheckpointListModel::CheckpointListModel(QObject *parent)
    : QAbstractListModel(parent) {
}

int CheckpointListModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_checkpoints.size();
}

QVariant CheckpointListModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_checkpoints.size()) {
        return QVariant();
    }

    const auto &checkpoint = m_checkpoints[index.row()];

    switch (role) {
    case IndexRole:
        return checkpoint.index;
    case TimestampRole:
        return checkpoint.timestamp;
    case DescriptionRole:
        return checkpoint.description;
    case FileCountRole:
        return checkpoint.fileCount;
    case CanRollbackRole:
        return checkpoint.index > 0;  // 不能回滚到第一个检查点
    case Qt::DisplayRole:
        return QString("Checkpoint %1: %2").arg(checkpoint.index).arg(checkpoint.description);
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> CheckpointListModel::roleNames() const {
    return {
        {IndexRole, "index"},
        {TimestampRole, "timestamp"},
        {DescriptionRole, "description"},
        {FileCountRole, "fileCount"},
        {CanRollbackRole, "canRollback"}
    };
}

void CheckpointListModel::addCheckpoint(int index, const QString &description, int fileCount) {
    beginInsertRows(QModelIndex(), m_checkpoints.size(), m_checkpoints.size());
    CheckpointEntry entry;
    entry.index = index;
    entry.timestamp = QDateTime::currentDateTime().toString(Qt::ISODate);
    entry.description = description;
    entry.fileCount = fileCount;
    m_checkpoints.append(entry);
    endInsertRows();
}

bool CheckpointListModel::removeCheckpoint(int index) {
    for (int i = 0; i < m_checkpoints.size(); ++i) {
        if (m_checkpoints[i].index == index) {
            beginRemoveRows(QModelIndex(), i, i);
            m_checkpoints.removeAt(i);
            endRemoveRows();
            return true;
        }
    }
    return false;
}

QString CheckpointListModel::getCheckpointDescription(int index) const {
    for (const auto &checkpoint : m_checkpoints) {
        if (checkpoint.index == index) {
            return checkpoint.description;
        }
    }
    return "";
}

void CheckpointListModel::clear() {
    beginResetModel();
    m_checkpoints.clear();
    endResetModel();
}
