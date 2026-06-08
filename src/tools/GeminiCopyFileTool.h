#pragma once
#include "agent/AgentToolRegistry.h"
#include <QJsonObject>

class GeminiCopyFileTool : public BaseTool {
    Q_OBJECT
public:
    explicit GeminiCopyFileTool(QObject *parent = nullptr) : BaseTool(parent) {}

    QString name() const override { return QStringLiteral("copy_file"); }
    QString description() const override { return QStringLiteral("Copy a file or directory"); }
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;
};

