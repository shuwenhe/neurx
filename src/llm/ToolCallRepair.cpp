#include "llm/ToolCallRepair.h"
#include <QJsonDocument>
#include <QRegularExpression>

namespace ToolCallRepair {

namespace {

bool isValidJsonObject(const QString &text)
{
    QJsonParseError pe;
    const QJsonDocument doc = QJsonDocument::fromJson(text.toUtf8(), &pe);
    return pe.error == QJsonParseError::NoError && doc.isObject();
}

QString extractBalancedObject(const QString &text)
{
    const int start = text.indexOf('{');
    if (start < 0)
        return {};

    bool inString = false;
    bool escaped = false;
    int depth = 0;
    for (int i = start; i < text.size(); ++i) {
        const QChar ch = text.at(i);
        if (inString) {
            if (escaped) {
                escaped = false;
                continue;
            }
            if (ch == '\\') {
                escaped = true;
                continue;
            }
            if (ch == '"')
                inString = false;
            continue;
        }

        if (ch == '"') {
            inString = true;
            continue;
        }
        if (ch == '{')
            ++depth;
        else if (ch == '}') {
            --depth;
            if (depth == 0)
                return text.mid(start, i - start + 1);
        }
    }
    return {};
}

QString normalizeJsonCandidate(const QString &raw)
{
    QString s = raw.trimmed();

    static const QRegularExpression reBlock(
        QStringLiteral("^```(?:json)?\\s*([\\s\\S]*?)\\s*```$"),
        QRegularExpression::DotMatchesEverythingOption);
    const auto m = reBlock.match(s);
    if (m.hasMatch())
        s = m.captured(1).trimmed();

    if (isValidJsonObject(s))
        return s;

    static const QRegularExpression reTrailingComma(
        QStringLiteral(",\\s*([\\}\\]])"));
    s.replace(reTrailingComma, QStringLiteral("\\1"));

    static const QRegularExpression reSingleQuote(
        QStringLiteral("'([^'\\\\]*(?:\\\\.[^'\\\\]*)*)'"));
    s.replace(reSingleQuote, QStringLiteral("\"\\1\""));

    if (isValidJsonObject(s))
        return s;

    const QString extracted = extractBalancedObject(s);
    if (!extracted.isEmpty()) {
        QString candidate = extracted;
        candidate.replace(reTrailingComma, QStringLiteral("\\1"));
        candidate.replace(reSingleQuote, QStringLiteral("\"\\1\""));
        if (isValidJsonObject(candidate))
            return candidate;
    }

    return raw;
}

} // namespace

QString repairJson(const QString &raw)
{
    return normalizeJsonCandidate(raw);
}

QJsonObject repairJsonObject(const QString &raw, bool *ok)
{
    const QString repaired = repairJson(raw);
    QJsonParseError pe;
    const QJsonDocument doc = QJsonDocument::fromJson(repaired.toUtf8(), &pe);
    const bool valid = pe.error == QJsonParseError::NoError && doc.isObject();
    if (ok)
        *ok = valid;
    if (valid)
        return doc.object();
    return {};
}

} // namespace ToolCallRepair
