#pragma once
#include "agent/AgentToolRegistry.h"
#include "tools/CheckpointManager.h"
#include <QVariantList>

class CheckpointTool : public BaseTool {
    Q_OBJECT

public:
    explicit CheckpointTool(const QString &workspaceRoot, QObject *parent = nullptr);

    QString name() const override { return "checkpoint"; }
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
    QString summary(const QJsonObject &args) const override;

    QVariantList recentCheckpoints() const;
    QVariantList filesForCheckpoint(const QString &checkpointId, QString *error = nullptr) const;

signals:
    void checkpointRolledBack(const QString &checkpointId);

private:
    ToolResult list(const QString &callId) const;
    ToolResult rollback(const QString &callId, const QJsonObject &args);

    CheckpointManager m_manager;
};
