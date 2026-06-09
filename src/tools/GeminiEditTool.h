#ifndef GEMINIEDITTOOL_H
#define GEMINIEDITTOOL_H

#include "agent/AgentToolRegistry.h"
#include <QJsonObject>

class GeminiEditTool : public BaseTool
{
    Q_OBJECT
public:
    explicit GeminiEditTool(QObject *parent = nullptr);

    QString name() const override;
    QString description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult execute(const QString &callId, const QJsonObject &args) override;

private:
    QString applyFlexibleReplacement(const QString &content, const QString &oldString, const QString &newString, int *occurrences);
    QString applyRegexReplacement(const QString &content, const QString &oldString, const QString &newString, int *occurrences, bool allowMultiple);
    QString stripLine(const QString &line);
    QString escapeRegex(const QString &str);
    QStringList applyIndentation(const QStringList &lines, const QString &targetIndentation);
};

#endif // GEMINIEDITTOOL_H
