#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QList>
#include <QString>

class LogModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int max_lines READ max_lines WRITE set_max_lines)

public:
    enum Roles {
        TimeRole = Qt::UserRole + 1,
        LevelRole,
        TagRole,
        MessageRole,
    };

    explicit LogModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int max_lines() const;
    void set_max_lines(int value);

public slots:
    void append(const QString& level, const QString& tag, const QString& message);
    Q_INVOKABLE void clear();

private:
    struct Entry {
        QDateTime time;
        QString level;
        QString tag;
        QString message;
    };

    QList<Entry> entries_;
    int max_lines_;
};
