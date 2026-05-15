#include "bridge/LogModel.h"

LogModel::LogModel(QObject* parent)
    : QAbstractListModel(parent), max_lines_(200) {}

int LogModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) {
        return 0;
    }
    return entries_.size();
}

QVariant LogModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= entries_.size()) {
        return {};
    }

    const Entry& entry = entries_.at(index.row());
    switch (role) {
    case TimeRole:
        return entry.time.toString("hh:mm:ss");
    case LevelRole:
        return entry.level;
    case TagRole:
        return entry.tag;
    case MessageRole:
        return entry.message;
    default:
        return {};
    }
}

QHash<int, QByteArray> LogModel::roleNames() const {
    return {
        {TimeRole, "time"},
        {LevelRole, "level"},
        {TagRole, "tag"},
        {MessageRole, "message"},
    };
}

int LogModel::max_lines() const {
    return max_lines_;
}

void LogModel::set_max_lines(int value) {
    if (value > 0) {
        max_lines_ = value;
    }
}

void LogModel::append(const QString& level, const QString& tag, const QString& message) {
    while (entries_.size() >= max_lines_) {
        beginRemoveRows(QModelIndex(), 0, 0);
        entries_.removeFirst();
        endRemoveRows();
    }

    const int row = entries_.size();
    beginInsertRows(QModelIndex(), row, row);
    entries_.append({QDateTime::currentDateTime(), level, tag, message});
    endInsertRows();
}

void LogModel::clear() {
    beginResetModel();
    entries_.clear();
    endResetModel();
}
