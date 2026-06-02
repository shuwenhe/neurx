#pragma once

#include <QString>
#include <QAbstractListModel>
#include <QVector>
#include <QVariantMap>

/**
 * @brief StreamingOutputModel - 流式输出的Qt Model
 */
class StreamingOutputModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum OutputRole {
        ContentRole = Qt::UserRole + 1,
        TypeRole,
        TimestampRole,
        IsErrorRole
    };

    explicit StreamingOutputModel(QObject *parent = nullptr);

    // 模型接口
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // 添加输出行
    void addOutput(const QString &content, bool isError = false);
    void addStatusUpdate(const QString &status);
    void clear();

private:
    struct OutputLine {
        QString content;
        bool isError;
        QString timestamp;
    };

    QVector<OutputLine> m_lines;
};

/**
 * @brief DiffViewModel - 差异视图Model
 */
class DiffViewModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum DiffRole {
        FilePathRole = Qt::UserRole + 1,
        AdditionsRole,
        DeletionsRole,
        ModificationsRole,
        SummaryRole
    };

    explicit DiffViewModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // 添加差异
    void addDiff(const QString &filePath, int additions, int deletions, int modifications);
    QString getDiffSummary() const;
    void clear();

private:
    struct DiffEntry {
        QString filePath;
        int additions;
        int deletions;
        int modifications;
    };

    QVector<DiffEntry> m_diffs;
};

/**
 * @brief CheckpointListModel - 检查点列表Model
 */
class CheckpointListModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum CheckpointRole {
        IndexRole = Qt::UserRole + 1,
        TimestampRole,
        DescriptionRole,
        FileCountRole,
        CanRollbackRole
    };

    explicit CheckpointListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // 添加检查点
    void addCheckpoint(int index, const QString &description, int fileCount = 0);
    bool removeCheckpoint(int index);
    QString getCheckpointDescription(int index) const;
    void clear();

private:
    struct CheckpointEntry {
        int index;
        QString timestamp;
        QString description;
        int fileCount;
    };

    QVector<CheckpointEntry> m_checkpoints;
};
