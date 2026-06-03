#pragma once
#include "agent/AgentToolRegistry.h"

// ── WebFetchTool ─────────────────────────────────────────────────────────────
//  Fetches the text content of a URL.
//  HTML is stripped to readable plain text; binary responses are rejected.
//  Useful for reading documentation, READMEs, issue trackers, API specs, etc.

class WebFetchTool : public BaseTool {
    Q_OBJECT
public:
    explicit WebFetchTool(QObject *parent = nullptr);

    QString     name()        const override { return QStringLiteral("web_fetch"); }
    QString     description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

private:
    static QString extractText(const QString &html);
    static QString truncate(const QString &text, int maxChars);
};
