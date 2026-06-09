#include "tools/WebFetchTool.h"
#include <QEventLoop>
#include <QHostAddress>
#include <QHostInfo>
#include <QJsonArray>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QTimer>
#include <QUrl>

static constexpr int kDefaultMaxChars = 12000;
static constexpr int kTimeoutMs       = 15000;

WebFetchTool::WebFetchTool(QObject *parent) : BaseTool(parent) {}

QString WebFetchTool::description() const
{
    return QStringLiteral(
        "Fetch the text content of a web page or URL. "
        "Strips HTML tags and returns readable plain text. "
        "Use for reading documentation, changelogs, API specs, GitHub files, or any URL. "
        "Parameters: url (required), max_chars (default 12000).");
}

QJsonObject WebFetchTool::parametersSchema() const
{
    return QJsonObject{
        {"type", "object"},
        {"properties", QJsonObject{
            {"url", QJsonObject{
                {"type", "string"},
                {"description", "Full URL to fetch (https:// required)."},
            }},
            {"max_chars", QJsonObject{
                {"type", "integer"},
                {"description", "Maximum characters of plain text to return (default 12000)."},
            }},
        }},
        {"required", QJsonArray{"url"}},
    };
}

QString WebFetchTool::summary(const QJsonObject &args) const
{
    return QStringLiteral("fetch ") + args.value("url").toString();
}

ToolResult WebFetchTool::execute(const QString &callId, const QJsonObject &args)
{
    QString urlStr = args.value("url").toString().trimmed();
    if (urlStr.isEmpty())
        return {callId, name(), true, "url is required."};

    urlStr = normalizeUrl(urlStr);
    urlStr = convertGithubUrlToRaw(urlStr);

    if (isBlockedHost(urlStr)) {
        return {callId, name(), true, "Access to blocked or private host is not allowed: " + urlStr};
    }

    const QUrl url(urlStr);
    if (!url.isValid() || (url.scheme() != "https" && url.scheme() != "http"))
        return {callId, name(), true, "Invalid or non-HTTP URL: " + urlStr};

    const int maxChars = qBound(100, args.value("max_chars").toInt(kDefaultMaxChars), 80000);

    QNetworkAccessManager nam;
    QNetworkRequest req(url);
    req.setRawHeader("User-Agent", "neurx/1.0 (compatible; Mozilla/5.0)");
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);

    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);

    QNetworkReply *reply = nam.get(req);
    QObject::connect(reply,  &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QObject::connect(&timer, &QTimer::timeout,         &loop, &QEventLoop::quit);
    timer.start(kTimeoutMs);
    loop.exec();

    if (!reply->isFinished()) {
        reply->abort();
        reply->deleteLater();
        return {callId, name(), true, "Request timed out."};
    }

    const auto networkError = reply->error();
    if (networkError != QNetworkReply::NoError) {
        const QString err = reply->errorString();
        reply->deleteLater();
        return {callId, name(), true, "Network error: " + err};
    }

    const QByteArray raw = reply->readAll();
    reply->deleteLater();

    // Reject binary content types.
    const QString ct = reply->header(QNetworkRequest::ContentTypeHeader).toString();
    if (!ct.contains("text") && !ct.contains("json") && !ct.contains("xml")
        && !ct.isEmpty()) {
        return {callId, name(), true,
                QStringLiteral("Unsupported content type: %1").arg(ct)};
    }

    const QString text = extractText(QString::fromUtf8(raw));
    return {callId, name(), false, truncate(text, maxChars)};
}

// ── helpers ───────────────────────────────────────────────────────────────────

QString WebFetchTool::normalizeUrl(const QString &urlStr)
{
    QUrl url(urlStr);
    if (!url.isValid()) return urlStr;

    url.setHost(url.host().toLower());

    // Remove default ports
    if ((url.scheme() == "http" && url.port() == 80) ||
        (url.scheme() == "https" && url.port() == 443)) {
        url.setPort(-1);
    }

    // Normalize path: remove trailing slash if not root
    QString path = url.path();
    if (path.length() > 1 && path.endsWith('/')) {
        path.chop(1);
        url.setPath(path);
    }

    return url.toString();
}

bool WebFetchTool::isBlockedHost(const QString &urlStr)
{
    const QUrl url(urlStr);
    const QString host = url.host().toLower();

    if (host == "localhost" || host == "127.0.0.1" || host == "::1") {
        return true;
    }

    // Check if it's a private IP address
    QHostAddress addr(host);
    if (!addr.isNull()) {
        if (addr.isLoopback()) return true;
        // Simple private IP range checks
        quint32 ipv4 = addr.toIPv4Address();
        if ((ipv4 & 0xFF000000) == 0x0A000000) return true; // 10.0.0.0/8
        if ((ipv4 & 0xFFF00000) == 0xAC100000) return true; // 172.16.0.0/12
        if ((ipv4 & 0xFFFF0000) == 0xC0A80000) return true; // 192.168.0.0/16
        if ((ipv4 & 0xFFFF0000) == 0xA9FE0000) return true; // 169.254.0.0/16 (Link-local)
    }

    return false;
}

QString WebFetchTool::convertGithubUrlToRaw(const QString &urlStr)
{
    const QUrl url(urlStr);
    if (url.host() == "github.com") {
        QString path = url.path();
        // Match /user/repo/blob/branch/path/to/file
        static const QRegularExpression re(QStringLiteral("^/([^/]+/[^/]+)/blob/(.*)$"));
        auto match = re.match(path);
        if (match.hasMatch()) {
            return QStringLiteral("https://raw.githubusercontent.com/%1/%2")
                .arg(match.captured(1), match.captured(2));
        }
    }
    return urlStr;
}

QString WebFetchTool::extractText(const QString &html)
{
    // Remove <script> and <style> blocks entirely.
    static const QRegularExpression reScript(
        QStringLiteral("<(script|style)[^>]*>.*?</(script|style)>"),
        QRegularExpression::DotMatchesEverythingOption
        | QRegularExpression::CaseInsensitiveOption);
    // Strip remaining tags.
    static const QRegularExpression reTag(QStringLiteral("<[^>]+>"));
    // Collapse whitespace.
    static const QRegularExpression reSpace(QStringLiteral("[ \\t]+"));
    // Collapse blank lines.
    static const QRegularExpression reBlankLines(QStringLiteral("\\n{3,}"));

    QString s = html;
    s.remove(reScript);
    s.replace(reTag, QStringLiteral(" "));
    // Decode common HTML entities.
    s.replace("&amp;",  "&");
    s.replace("&lt;",   "<");
    s.replace("&gt;",   ">");
    s.replace("&quot;", "\"");
    s.replace("&#39;",  "'");
    s.replace("&nbsp;", " ");
    s.replace(reSpace,   QStringLiteral(" "));
    s.replace(reBlankLines, QStringLiteral("\n\n"));
    return s.trimmed();
}

QString WebFetchTool::truncate(const QString &text, int maxChars)
{
    if (text.length() <= maxChars) return text;
    return text.left(maxChars)
           + QStringLiteral("\n\n[truncated – %1 chars total]").arg(text.length());
}
