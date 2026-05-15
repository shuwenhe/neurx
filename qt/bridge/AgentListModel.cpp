#include "bridge/AgentListModel.h"

AgentListModel::AgentListModel(QObject* parent)
    : QAbstractListModel(parent) {
    entries_.append({"neurx-agent", "Neurx Agent", "idle"});
    entries_.append({"qt-bridge", "Qt Bridge", "ready"});
}

int AgentListModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) {
        return 0;
    }
    return entries_.size();
}

QVariant AgentListModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= entries_.size()) {
        return {};
    }

    const AgentEntry& entry = entries_.at(index.row());
    switch (role) {
    case IdRole:
        return entry.id;
    case NameRole:
        return entry.name;
    case StatusRole:
        return entry.status;
    default:
        return {};
    }
}

QHash<int, QByteArray> AgentListModel::roleNames() const {
    return {
        {IdRole, "agentId"},
        {NameRole, "name"},
        {StatusRole, "status"},
    };
}

void AgentListModel::set_primary_agent_status(const QString& status, const QString& task) {
    QString next_status = status;
    if (!task.isEmpty()) {
        next_status = status + " / " + task;
    }

    if (entries_.isEmpty()) {
        return;
    }

    entries_[0].status = next_status;
    const QModelIndex changed = index(0, 0);
    emit dataChanged(changed, changed, {StatusRole});
}
