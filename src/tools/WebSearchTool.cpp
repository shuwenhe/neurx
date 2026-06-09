#include "tools/WebSearchTool.h"
#include <QEventLoop>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcessEnvironment>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>

static constexpr int kSearchTimeoutMs = 10000;

WebSearchTool::WebSearchTool(QObject *parent) : BaseTool(parent)
{
    // Pick up key from environment if not explicitly set.
    const QString envKey =
        QProcessEnvironment::systemEnvironment().value("BRAVE_API_KEY");
    if (!envKey.isEmpty())
        m_braveApiKey = envKey;
}

QString WebSearchTool::description() const
{
    return QStringLiteral(
        "Search the web for current information. Returns titles, URLs, and snippets. "
        "Use when the user asks about recent events, documentation, libraries, or anything "
        "that may require up-to-date external information. "
        "Parameters: query (required), num_results (default 5).");
}

QJsonObject WebSearchTool::parametersSchema() const
{
    return QJsonObject{
        {"type", "object"},
        {"properties", QJsonObject{
            {"query", QJsonObject{
                {"type", "string"},
                {"description", "Search query string."},
            }},
            {"num_results", QJsonObject{
                {"type", "integer"},
                {"description", "Number of results to return (default 5, max 10)."},
            }},
        }},
        {"required", QJsonArray{"query"}},
    };
}

QString WebSearchTool::summary(const QJsonObject &args) const
{
    return QStringLiteral("search: ") + args.value("query").toString();
}

ToolResult WebSearchTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString query = args.value("query").toString().trimmed();
    if (query.isEmpty())
        return {callId, name(), true, "query is required."};

    // Note: We don't filter the query itself, but in searchBrave/searchDuckDuckGo
    // we could filter results if we wanted to be extremely safe.
    // For now, let's just ensure num_results is reasonable.

    const int n = qBound(1, args.value("num_results").toInt(5), 10);

    if (!m_braveApiKey.isEmpty())
        return searchBrave(callId, query, n);
    return searchDuckDuckGo(callId, query, n);
}

// ── Brave Search API ──────────────────────────────────────────────────────────

static QByteArray syncGet(const QUrl &url,
                          const QList<QPair<QByteArray,QByteArray>> &headers,
                          QString &outError)
{
    QNetworkAccessManager nam;
    QNetworkRequest req(url);
    for (const auto &[k, v] : headers)
        req.setRawHeader(k, v);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);

    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);
    auto *reply = nam.get(req);
    QObject::connect(reply,  &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QObject::connect(&timer, &QTimer::timeout,         &loop, &QEventLoop::quit);
    timer.start(kSearchTimeoutMs);
    loop.exec();

    if (!reply->isFinished()) { reply->abort(); reply->deleteLater(); outError = "Timeout"; return {}; }
    if (reply->error() != QNetworkReply::NoError) { outError = reply->errorString(); reply->deleteLater(); return {}; }
    const QByteArray data = reply->readAll();
    reply->deleteLater();
    return data;
}

ToolResult WebSearchTool::searchBrave(const QString &callId,
                                      const QString &query, int n) const
{
    QUrl url("https://api.search.brave.com/res/v1/web/search");
    QUrlQuery q;
    q.addQueryItem("q", query);
    q.addQueryItem("count", QString::number(n));
    url.setQuery(q);

    QString err;
    const QByteArray data = syncGet(url,
        {{"Accept", "application/json"},
         {"Accept-Encoding", "gzip"},
         {"X-Subscription-Token", m_braveApiKey.toUtf8()}}, err);

    if (!err.isEmpty())
        return {callId, name(), true, "Brave API error: " + err};

    const auto doc = QJsonDocument::fromJson(data);
    if (!doc.isObject())
        return {callId, name(), true, "Unexpected Brave API response."};

    const auto webResults = doc.object()
        .value("web").toObject()
        .value("results").toArray();

    if (webResults.isEmpty())
        return {callId, name(), false, QStringLiteral("No results for: %1").arg(query)};

    QStringList lines;
    lines << QStringLiteral("Search results for: %1\n").arg(query);
    int idx = 1;
    for (const auto &v : webResults) {
        const auto r = v.toObject();
        lines << QStringLiteral("%1. %2\n   %3\n   %4")
                     .arg(idx++)
                     .arg(r.value("title").toString())
                     .arg(r.value("url").toString())
                     .arg(r.value("description").toString());
        if (idx > n) break;
    }
    return {callId, name(), false, lines.join("\n\n")};
}

// ── DuckDuckGo instant answer (no-key fallback) ───────────────────────────────

ToolResult WebSearchTool::searchDuckDuckGo(const QString &callId,
                                           const QString &query, int n) const
{
    Q_UNUSED(n)
    QUrl url("https://api.duckduckgo.com/");
    QUrlQuery q;
    q.addQueryItem("q", query);
    q.addQueryItem("format", "json");
    q.addQueryItem("no_html", "1");
    q.addQueryItem("skip_disambig", "1");
    url.setQuery(q);

    QString err;
    const QByteArray data = syncGet(url,
        {{"User-Agent", "neurx/1.0"}}, err);

    if (!err.isEmpty())
        return {callId, name(), true, "Search error: " + err};

    const auto doc = QJsonDocument::fromJson(data);
    if (!doc.isObject())
        return {callId, name(), true, "Unexpected DDG response."};

    const auto obj = doc.object();
    const QString abstract  = obj.value("Abstract").toString();
    const QString abstractUrl = obj.value("AbstractURL").toString();
    const auto relatedTopics = obj.value("RelatedTopics").toArray();

    QStringList lines;
    lines << QStringLiteral("Search results for: %1\n").arg(query);

    if (!abstract.isEmpty()) {
        lines << QStringLiteral("1. %1\n   %2\n   %3")
                     .arg(obj.value("AbstractSource").toString(),
                          abstractUrl, abstract);
    }

    int idx = abstract.isEmpty() ? 1 : 2;
    for (const auto &v : relatedTopics) {
        if (idx > n) break;
        const auto t = v.toObject();
        const QString text = t.value("Text").toString();
        const QString link = t.value("FirstURL").toString();
        if (text.isEmpty()) continue;
        lines << QStringLiteral("%1. %2\n   %3").arg(idx++).arg(text, link);
    }

    if (lines.size() <= 1)
        return {callId, name(), false,
                QStringLiteral("No instant answer found. Set BRAVE_API_KEY for full results.")};

    return {callId, name(), false, lines.join("\n\n")};
}
