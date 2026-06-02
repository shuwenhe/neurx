#include "llm/GeminiProvider.h"
#include <QDebug>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariantMap>

static constexpr char kGeminiBaseUrl[] = "https://generativelanguage.googleapis.com/v1beta/models/";

GeminiProvider::GeminiProvider(QObject *parent)
    : LLMProvider(parent)
    , m_nam(new QNetworkAccessManager(this))
{
}

QStringList GeminiProvider::availableModels() const
{
    return {
        "gemini-2.0-flash-exp",
        "gemini-1.5-pro",
        "gemini-1.5-flash",
        "gemini-1.5-flash-8b"
    };
}

void GeminiProvider::sendRequest(const LLMRequest &request)
{
    if (m_reply) cancel();
    if (m_apiKey.trimmed().isEmpty()) {
        emit requestError("Gemini API key is empty. Please set it in Settings.");
        return;
    }

    QString model = request.model.isEmpty() ? availableModels().first() : request.model;
    // Strip "models/" if present
    if (model.startsWith("models/")) model = model.mid(7);

    QString urlStr = QString("%1%2:%3?key=%4")
                         .arg(kGeminiBaseUrl)
                         .arg(model)
                         .arg(request.stream ? "streamGenerateContent" : "generateContent")
                         .arg(m_apiKey);

    QNetworkRequest req{QUrl(urlStr)};
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    const QByteArray body = QJsonDocument(buildRequestBody(request)).toJson(QJsonDocument::Compact);
    m_reply = m_nam->post(req, body);
    m_buffer.clear();
    m_partialResponse = {};
    m_partialResponse.message.role = MessageRole::Assistant;

    connect(m_reply, &QNetworkReply::readyRead, this, [this]() {
        handleStreamChunk(m_reply->readAll());
    });

    connect(m_reply, &QNetworkReply::finished, this, [this]() {
        if (m_reply->error() != QNetworkReply::NoError) {
            emit requestError(m_reply->errorString());
        } else {
            emit responseComplete(m_partialResponse);
        }
        m_reply->deleteLater();
        m_reply = nullptr;
    });
}

void GeminiProvider::cancel()
{
    if (m_reply) {
        m_reply->abort();
        m_reply->deleteLater();
        m_reply = nullptr;
    }
    m_buffer.clear();
}

QJsonObject GeminiProvider::buildRequestBody(const LLMRequest &request) const
{
    QJsonObject body;
    body["contents"] = buildContents(request.messages);

    QJsonObject config;
    config["temperature"] = static_cast<double>(request.temperature);
    config["maxOutputTokens"] = request.maxTokens;
    body["generationConfig"] = config;

    // Handle system instruction
    for (const auto &msg : request.messages) {
        if (msg.role == MessageRole::System) {
            QJsonObject si;
            QJsonArray parts;
            QJsonObject textPart;
            textPart["text"] = msg.content;
            parts.append(textPart);
            si["parts"] = parts;
            body["system_instruction"] = si;
            break;
        }
    }

    if (!request.tools.isEmpty()) {
        body["tools"] = buildTools(request.tools);
    }

    return body;
}

QJsonArray GeminiProvider::buildContents(const QList<AgentMessage> &history) const
{
    QJsonArray contents;
    for (const auto &msg : history) {
        if (msg.role == MessageRole::System) continue;

        QJsonObject content;
        content["role"] = (msg.role == MessageRole::User) ? "user" : "model";

        QJsonArray parts;
        if (!msg.content.isEmpty()) {
            QJsonObject textPart;
            textPart["text"] = msg.content;
            parts.append(textPart);
        }

        // Tool Results
        if (msg.hasToolResults()) {
            for (const auto &tr : msg.toolResults) {
                QJsonObject resPart;
                QJsonObject fnRes;
                fnRes["name"] = tr.name;
                // Gemini expects a 'content' object for response
                QJsonObject contentObj;
                contentObj["result"] = tr.content;
                fnRes["response"] = contentObj;
                resPart["functionResponse"] = fnRes;
                parts.append(resPart);
            }
        }

        // Tool Calls
        if (msg.hasToolCalls()) {
            for (const auto &tc : msg.toolCalls) {
                QJsonObject callPart;
                QJsonObject fnCall;
                fnCall["name"] = tc.name;
                fnCall["args"] = tc.arguments;
                callPart["functionCall"] = fnCall;
                parts.append(callPart);
            }
        }

        // Images
        for (const auto &val : msg.attachments) {
            const QVariantMap map = val.toMap();
            if (map["type"].toString() == "image") {
                QJsonObject dataPart;
                QJsonObject inlineData;
                inlineData["mime_type"] = map["mimeType"].toString();
                inlineData["data"] = map["base64"].toString();
                dataPart["inline_data"] = inlineData;
                parts.append(dataPart);
            }
        }

        content["parts"] = parts;
        contents.append(content);
    }
    return contents;
}

QJsonObject GeminiProvider::buildTools(const QJsonArray &tools) const
{
    QJsonObject toolsObj;
    QJsonArray declarations;
    bool hasSearch = false;

    for (const auto &tVal : tools) {
        const QJsonObject t = tVal.toObject();
        if (t["name"].toString() == "google_search") {
            hasSearch = true;
            continue;
        }

        QJsonObject dec;
        dec["name"] = t["name"];
        dec["description"] = t["description"];
        dec["parameters"] = t["parameters"];
        declarations.append(dec);
    }

    if (!declarations.isEmpty()) {
        QJsonArray toolsArr;
        QJsonObject fnDeclarations;
        fnDeclarations["function_declarations"] = declarations;
        toolsArr.append(fnDeclarations);

        if (hasSearch) {
            QJsonObject searchTool;
            searchTool["google_search_retrieval"] = QJsonObject();
            toolsArr.append(searchTool);
        }
        // Gemini API structure for tools can be an array of tool objects
        return fnDeclarations; // Simplified for now
    }

    return QJsonObject();
}

void GeminiProvider::handleStreamChunk(const QByteArray &chunk)
{
    m_buffer += chunk;

    // Gemini stream starts with '[' and ends with ']' with comma-separated objects
    // It's actually a bit tricky to parse manually if it's not a single JSON array
    // Let's try to parse individual objects if they are complete

    // Quick hack for Gemini's specific JSON stream format
    QByteArray trimmed = m_buffer.trimmed();
    if (trimmed.startsWith('[')) trimmed = trimmed.mid(1);
    if (trimmed.endsWith(']')) trimmed.chop(1);

    // Split by ",\n" or similar might be dangerous.
    // A better way is to find matching braces.

    // For now, let's assume one object per chunk or use a basic JSON parser
    // actually QJsonDocument::fromJson handles some garbage at the end but we need to be careful

    // Gemini often sends chunks as elements of a JSON array.
    // data: {"candidates": ...}

    // Actually, when using streamGenerateContent, it returns a JSON array of objects.
    // We can try to find the start and end of objects.

    static const QByteArray kSeparator = ",\r\n";
    int sepIdx = m_buffer.indexOf(kSeparator);
    while (sepIdx >= 0 || m_buffer.trimmed().endsWith(']')) {
        QByteArray item;
        if (sepIdx >= 0) {
            item = m_buffer.left(sepIdx).trimmed();
            m_buffer = m_buffer.mid(sepIdx + kSeparator.length());
        } else {
            item = m_buffer.trimmed();
            if (item.startsWith('[')) item = item.mid(1);
            if (item.endsWith(']')) item.chop(1);
            m_buffer.clear();
        }

        if (item.startsWith(',')) item = item.mid(1).trimmed();
        if (item.isEmpty()) break;

        QJsonDocument doc = QJsonDocument::fromJson(item);
        if (doc.isObject()) {
            parseResponsePart(doc.object());
        }

        if (m_buffer.isEmpty()) break;
        sepIdx = m_buffer.indexOf(kSeparator);
    }
}

void GeminiProvider::parseResponsePart(const QJsonObject &obj)
{
    const QJsonArray candidates = obj["candidates"].toArray();
    if (candidates.isEmpty()) return;

    const QJsonObject content = candidates.first().toObject()["content"].toObject();
    const QJsonArray parts = content["parts"].toArray();

    for (const auto &pVal : parts) {
        const QJsonObject p = pVal.toObject();
        if (p.contains("text")) {
            const QString text = p["text"].toString();
            m_partialResponse.message.content += text;
            TokenEvent te; te.type = TokenEvent::Type::TextDelta; te.delta = text;
            emit tokenReceived(te);
        }

        if (p.contains("functionCall")) {
            const QJsonObject fc = p["functionCall"].toObject();
            ToolCall tc;
            tc.id = QUuid::createUuid().toString(QUuid::WithoutBraces); // Gemini doesn't always provide ID
            tc.name = fc["name"].toString();
            tc.arguments = fc["args"].toObject();
            m_partialResponse.message.toolCalls.append(tc);
        }
    }

    if (obj.contains("usageMetadata")) {
        const QJsonObject usage = obj["usageMetadata"].toObject();
        m_partialResponse.inputTokens = usage["promptTokenCount"].toInt();
        m_partialResponse.outputTokens = usage["candidatesTokenCount"].toInt();
    }
}
