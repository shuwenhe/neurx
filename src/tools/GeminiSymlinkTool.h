#pragma once
#include "agent/AgentToolRegistry.h"

class GeminiSymlinkTool : public BaseTool {
    Q_OBJECT
public:
    explicit GeminiSymlinkTool(QObject *parent = nullptr) : BaseTool(parent) {}

    QString name() const override { return QStringLiteral("create_symlink"); }
    QString description() const override { return QStringLiteral("Create a symbolic link"); }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

