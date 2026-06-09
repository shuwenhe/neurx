#ifndef GEMINIGETINTERNALDOCSTOOL_H
#define GEMINIGETINTERNALDOCSTOOL_H

#include "agent/AgentToolRegistry.h"
#include <QObject>
#include <QDir>

class GeminiGetInternalDocsTool : public BaseTool
{
    Q_OBJECT
public:
    explicit GeminiGetInternalDocsTool(QObject* parent = nullptr);

    QString name() const override { return "get_internal_docs"; }
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString& callId, const QJsonObject& args) override;
    QString summary(const QJsonObject& args) const override;

private:
    QString getDocsRoot() const;
    bool isPathInsideDocs(const QString& path, const QString& docsRoot) const;
};

#endif // GEMINIGETINTERNALDOCSTOOL_H
