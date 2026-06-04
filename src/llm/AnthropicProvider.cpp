#include "llm/AnthropicProvider.h"
#include "llm/ToolCallRepair.h"
#include <QDebug>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariant>
#include <QVariantMap>

static QList<MessageImageAttachment> extractImageAttachments(const AgentMessage &msg)
{
    QList<MessageImageAttachment> images;
    for (const QVariant &value : msg.attachments) {
        const QVariantMap map = value.toMap();
        if (map.value("type").toString() != QStringLiteral("image"))
            continue;
        MessageImageAttachment image;
        image.path = map.value("path").toString();
        image.mimeType = map.value("mimeType").toString();
        image.dataUrl = map.value("dataUrl").toString();
        image.altText = map.value("altText").toString();
        if (!image.dataUrl.isEmpty())
            images.append(image);
    }
    return images;
}

static constexpr char kBaseUrl[] = "https://api.anthropic.com/v1/messages";
static constexpr char kApiVersion[] = "2023-06-01";

static QJsonObject parseToolArguments(const QString &rawArgs, const QString &callId)
{
    bool ok = false;
    const QJsonObject obj = ToolCallRepair::repairJsonObject(rawArgs, &ok);
    if (!ok && !rawArgs.trimmed().isEmpty()) {
        qWarning().noquote() << "[anthropic] failed to parse tool args for callId=" << callId
                             << "raw=" << rawArgs.left(200);
    }
    return obj;
}

AnthropicProvider::AnthropicProvider(QObject *parent)
    : LLMProvider(parent)
    , m_nam(new QNetworkAccessManager(this))
{
    m_endpoint = kBaseUrl;
}

QStringList AnthropicProvider::availableModels() const
{
    return {
        "claude-opus-4-5",
        "claude-sonnet-4-5",
        "claude-haiku-3-5",
        "claude-opus-4-0",
    };
}

void AnthropicProvider::sendRequest(const LLMRequest &request)
{
    if (m_reply) cancel();
    if (m_apiKey.trimmed().isEmpty()) {
        emit requestError("Anthropic API key is empty. Set it in Settings before sending requests.");
        return;
    }

    QNetworkRequest req(QUrl(m_endpoint.isEmpty() ? kBaseUrl : m_endpoint));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("x-api-key", m_apiKey.toUtf8());
    req.setRawHeader("anthropic-version", kApiVersion);
    req.setRawHeader("anthropic-beta", "interleaved-thinking-2025-05-07");

    const QByteArray body = QJsonDocument(buildRequestBody(request)).toJson(QJsonDocument::Compact);
    m_reply = m_nam->post(req, body);
    m_partialResponse = {};
    m_streamText.clear();

    connect(m_reply, &QNetworkReply::readyRead, this, [this]() {
        const int status = m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status >= 400)
            m_errorBuffer += m_reply->readAll();
        else
            handleStreamData(m_reply->readAll());
    });
    connect(m_reply, &QNetworkReply::finished, this, [this]() {
        if (m_reply->error() != QNetworkReply::NoError) {
            const int status = m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            QString errMsg;
            if (!m_errorBuffer.isEmpty()) {
                const QJsonObject doc = QJsonDocument::fromJson(m_errorBuffer).object();
                errMsg = doc["error"].toObject()["message"].toString();
                if (errMsg.isEmpty())
                    errMsg = QString::fromUtf8(m_errorBuffer);
            }
            if (errMsg.isEmpty()) errMsg = m_reply->errorString();
            if (status > 0 && !errMsg.contains(QString::number(status)))
                errMsg = QStringLiteral("HTTP %1: %2").arg(status).arg(errMsg);
            m_errorBuffer.clear();
            emit requestError(errMsg);
        } else {
            m_errorBuffer.clear();
            emit responseComplete(m_partialResponse);
        }
        m_reply->deleteLater();
        m_reply = nullptr;
    });
}

void AnthropicProvider::cancel()
{
    if (m_reply) {
        m_reply->abort();
        m_reply->deleteLater();
        m_reply = nullptr;
    }
}

QJsonObject AnthropicProvider::buildRequestBody(const LLMRequest &request) const
{
    QJsonObject body;
    body["model"]      = request.model.isEmpty() ? availableModels().first() : request.model;
    body["max_tokens"] = request.maxTokens;
    body["stream"]     = request.stream;
    if (request.temperature > 0.0f)
        body["temperature"] = static_cast<double>(request.temperature);

    // System prompt (first system message in history, or config default)
    for (const auto &msg : request.messages) {
        if (msg.role == MessageRole::System) {
            body["system"] = msg.content;
            break;
        }
    }

    body["messages"] = buildMessages(request.messages);

    if (!request.tools.isEmpty()) {
        qDebug() << "[AnthropicProvider] Adding" << request.tools.size() << "tools to request";
        for (int i = 0; i < request.tools.size(); ++i) {
            QJsonObject tool = request.tools[i].toObject();
            qDebug() << "  - Tool" << i << ":" << tool["name"].toString();
        }
        body["tools"] = convertTools(request.tools);
    } else {
        qWarning() << "[AnthropicProvider] No tools in request!";
    }

    return body;
}

QJsonArray AnthropicProvider::buildMessages(const QList<AgentMessage> &history) const
{
    QJsonArray arr;
    for (const auto &msg : history) {
        if (msg.role == MessageRole::System) continue;

        QJsonObject m;
        if (msg.role == MessageRole::User)      m["role"] = "user";
        else if (msg.role == MessageRole::Assistant) m["role"] = "assistant";
        else if (msg.role == MessageRole::Tool) m["role"] = "user"; // tool results are user-role in Anthropic

        if (msg.hasToolResults()) {
            QJsonArray content;
            for (const auto &tr : msg.toolResults) {
                QJsonObject block;
                block["type"]        = "tool_result";
                block["tool_use_id"] = tr.callId;
                block["content"]     = tr.content;
                if (tr.isError) block["is_error"] = true;
                content.append(block);
            }
            m["content"] = content;
        } else if (msg.hasToolCalls()) {
            QJsonArray content;
            if (!msg.content.isEmpty()) {
                QJsonObject textBlock;
                textBlock["type"] = "text";
                textBlock["text"] = msg.content;
                content.append(textBlock);
            }
            const auto images = extractImageAttachments(msg);
            for (const auto &image : images) {
                QJsonObject source;
                source["type"] = "base64";
                source["media_type"] = image.mimeType.isEmpty() ? QStringLiteral("image/png") : image.mimeType;
                const QString dataUrl = image.dataUrl;
                const int comma = dataUrl.indexOf(',');
                source["data"] = comma >= 0 ? dataUrl.mid(comma + 1) : dataUrl;

                QJsonObject block;
                block["type"] = "image";
                block["source"] = source;
                if (!image.altText.isEmpty())
                    block["alt_text"] = image.altText;
                content.append(block);
            }
            for (const auto &tc : msg.toolCalls) {
                QJsonObject block;
                block["type"]  = "tool_use";
                block["id"]    = tc.id;
                block["name"]  = tc.name;
                block["input"] = tc.arguments;
                content.append(block);
            }
            m["content"] = content;
        } else {
            const auto images = extractImageAttachments(msg);
            if (images.isEmpty()) {
                m["content"] = msg.content;
            } else {
                QJsonArray content;
                if (!msg.content.isEmpty()) {
                    QJsonObject textBlock;
                    textBlock["type"] = "text";
                    textBlock["text"] = msg.content;
                    content.append(textBlock);
                }
                for (const auto &image : images) {
                    QJsonObject source;
                    source["type"] = "base64";
                    source["media_type"] = image.mimeType.isEmpty() ? QStringLiteral("image/png") : image.mimeType;
                    const QString dataUrl = image.dataUrl;
                    const int comma = dataUrl.indexOf(',');
                    source["data"] = comma >= 0 ? dataUrl.mid(comma + 1) : dataUrl;

                    QJsonObject block;
                    block["type"] = "image";
                    block["source"] = source;
                    if (!image.altText.isEmpty())
                        block["alt_text"] = image.altText;
                    content.append(block);
                }
                m["content"] = content;
            }
        }
        arr.append(m);
    }
    return arr;
}

QJsonArray AnthropicProvider::convertTools(const QJsonArray &tools) const
{
    // Already in Anthropic format from ToolRegistry::toAnthropicSchema()
    return tools;
}

void AnthropicProvider::handleStreamData(const QByteArray &chunk)
{
    // SSE lines: "event: ...\ndata: ...\n\n"
    static QByteArray buf;
    buf += chunk;

    while (true) {
        int boundary = buf.indexOf("\n\n");
        if (boundary < 0) break;
        const QByteArray block = buf.left(boundary);
        buf = buf.mid(boundary + 2);

        QString eventType;
        QString dataStr;
        for (const auto &line : block.split('\n')) {
            const QString l = QString::fromUtf8(line).trimmed();
            if (l.startsWith("event: "))
                eventType = l.mid(7);
            else if (l.startsWith("data: "))
                dataStr = l.mid(6);
        }
        if (!eventType.isEmpty() && !dataStr.isEmpty())
            parseSSEEvent(eventType, dataStr);
    }
}

void AnthropicProvider::parseSSEEvent(const QString &event, const QString &data)
{
    const QJsonObject obj = QJsonDocument::fromJson(data.toUtf8()).object();

    if (event == "content_block_start") {
        const auto block = obj["content_block"].toObject();
        if (block["type"] == "tool_use") {
            m_currentToolId   = block["id"].toString();
            m_currentToolName = block["name"].toString();
            m_currentToolArgs.clear();
            TokenEvent te;
            te.type       = TokenEvent::Type::ToolCallDelta;
            te.toolCallId = m_currentToolId;
            te.toolName   = m_currentToolName;
            emit tokenReceived(te);
        }
    } else if (event == "content_block_delta") {
        const auto delta = obj["delta"].toObject();
        const QString type = delta["type"].toString();
        if (type == "text_delta") {
            const QString text = delta["text"].toString();
            m_streamText += text;
            TokenEvent te;
            te.type  = TokenEvent::Type::TextDelta;
            te.delta = text;
            emit tokenReceived(te);
        } else if (type == "input_json_delta") {
            m_currentToolArgs += delta["partial_json"].toString();
        }
    } else if (event == "content_block_stop") {
        if (!m_currentToolId.isEmpty()) {
            ToolCall tc;
            tc.id        = m_currentToolId;
            tc.name      = m_currentToolName;
            tc.arguments = parseToolArguments(m_currentToolArgs, m_currentToolId);
            m_partialResponse.message.toolCalls.append(tc);
            TokenEvent te;
            te.type       = TokenEvent::Type::ToolCallEnd;
            te.toolCallId = m_currentToolId;
            te.toolName   = m_currentToolName;
            emit tokenReceived(te);
            m_currentToolId.clear();
        }
    } else if (event == "message_delta") {
        const auto delta = obj["delta"].toObject();
        m_partialResponse.stopReason   = delta["stop_reason"].toString();
        m_partialResponse.outputTokens = obj["usage"].toObject()["output_tokens"].toInt();
    } else if (event == "message_start") {
        m_partialResponse.inputTokens = obj["message"].toObject()["usage"].toObject()["input_tokens"].toInt();
    } else if (event == "message_stop") {
        m_partialResponse.message.role    = MessageRole::Assistant;
        m_partialResponse.message.content = m_streamText;
        TokenEvent te;
        te.type = TokenEvent::Type::MessageEnd;
        emit tokenReceived(te);
    } else if (event == "error") {
        emit requestError(obj["error"].toObject()["message"].toString());
    }
}
