#pragma once
#include "agent/AgentToolRegistry.h"

class GeminiChmodTool : public BaseTool {
    Q_OBJECT
public:
    explicit GeminiChmodTool(QObject *parent = nullptr) : BaseTool(parent) {}

    QString name() const override { return QStringLiteral("chmod"); }
    QString description() const override { return QStringLiteral("Change file permissions (octal, e.g. 644)"); }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

