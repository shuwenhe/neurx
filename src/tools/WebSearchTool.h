#pragma once
#include "agent/AgentToolRegistry.h"

// ── WebSearchTool ─────────────────────────────────────────────────────────────
//  Web search using Brave Search API (primary) or DuckDuckGo instant answers
//  (fallback when no Brave key is configured).
//
//  Config: set braveApiKey via setBraveApiKey() or env BRAVE_API_KEY.

class WebSearchTool : public BaseTool {
    Q_OBJECT
public:
    explicit WebSearchTool(QObject *parent = nullptr);

    QString     name()        const override { return QStringLiteral("web_search"); }
    QString     description() const override;
    QJsonObject parametersSchema() const override;
    ToolResult  execute(const QString &callId, const QJsonObject &args) override;
    QString     summary(const QJsonObject &args) const override;

    void setBraveApiKey(const QString &key) { m_braveApiKey = key; }
    QString braveApiKey() const { return m_braveApiKey; }

private:
    ToolResult searchBrave(const QString &callId, const QString &query, int n) const;
    ToolResult searchDuckDuckGo(const QString &callId, const QString &query, int n) const;

    QString m_braveApiKey;
};
