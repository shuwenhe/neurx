#pragma once
#include "agent/AgentToolRegistry.h"
#include <QCryptographicHash>

class GeminiHashTool : public BaseTool {
    Q_OBJECT
public:
    explicit GeminiHashTool(QObject *parent = nullptr) : BaseTool(parent) {}

    QString name() const override { return QStringLiteral("hash_file"); }
    QString description() const override { return QStringLiteral("Compute file checksum (SHA256)"); }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

