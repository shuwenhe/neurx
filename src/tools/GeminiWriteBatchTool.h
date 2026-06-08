#pragma once
#include "agent/AgentToolRegistry.h"
#include <QJsonObject>

class GeminiWriteBatchTool : public BaseTool {
    Q_OBJECT
public:
    explicit GeminiWriteBatchTool(QObject *parent = nullptr) : BaseTool(parent) {}

    QString name() const override { return QStringLiteral("write_batch"); }
    QString description() const override { return QStringLiteral("Write multiple files in one batch"); }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

