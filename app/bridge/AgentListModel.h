#pragma once

#include <QtCore/qtmetamacros.h>
#include <QObject>
#include <QAbstractListModel>
#include <QString>
#include <QVector>

class AgentListModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        NameRole,
        StatusRole,
    };

    explicit AgentListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

public slots:
    void set_primary_agent_status(const QString& status, const QString& task);

private:
    struct AgentEntry {
        QString id;
        QString name;
        QString status;
    };

    QVector<AgentEntry> entries_;
};
