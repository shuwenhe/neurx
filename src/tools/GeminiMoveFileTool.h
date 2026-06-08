#pragma once
#include "agent/AgentToolRegistry.h"
#include <QJsonObject>

class GeminiMoveFileTool : public BaseTool {
    Q_OBJECT
public:
    explicit GeminiMoveFileTool(QObject *parent = nullptr) : BaseTool(parent) {}

    QString name() const override { return QStringLiteral("move_file"); }
    QString description() const override { return QStringLiteral("Move or rename a file or directory"); }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

