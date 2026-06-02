#include "llm/OpenAIProvider.h"
#include "llm/ToolCallRepair.h"
#include <QDebug>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

static constexpr char kBaseUrl[] = "https://api.siliconflow.cn/v1/chat/completions";

static QJsonObject parseToolArguments(const QString &rawArgs, const QString &callId)
{
    bool ok = false;
    const QJsonObject obj = ToolCallRepair::repairJsonObject(rawArgs, &ok);
    if (!ok && !rawArgs.trimmed().isEmpty()) {
        qWarning().noquote() << "[openai] failed to parse tool args for callId=" << callId
                             << "raw=" << rawArgs.left(200);
    }
    return obj;
}

OpenAIProvider::OpenAIProvider(QObject *parent)
    : LLMProvider(parent)
    , m_nam(new QNetworkAccessManager(this))
{
    m_endpoint = kBaseUrl;
}

QStringList OpenAIProvider::availableModels() const
{
    return {
        "Qwen/Qwen3-8B",
        "Qwen/Qwen3-32B",
        "Qwen/Qwen3-235B-A22B",
        "deepseek-ai/DeepSeek-V3",
        "deepseek-ai/DeepSeek-R1",
        "THUDM/glm-4-9b-chat",
    };
}

void OpenAIProvider::sendRequest(const LLMRequest &request)
{
    if (m_reply) cancel();
    if (m_apiKey.trimmed().isEmpty()) {
        emit requestError(
            "OpenAI-compatible API key is empty. Set it in Settings, or via env (SILICONFLOW_API_KEY / OPENAI_API_KEY)."
        );
        return;
    }

    const QString endpoint = m_endpoint.isEmpty() ? QString::fromUtf8(kBaseUrl) : m_endpoint;
    const QString model = request.model.isEmpty() ? availableModels().first() : request.model;
    qInfo().noquote() << "[openai] sendRequest endpoint=" << endpoint
                      << "model=" << model;

    QNetworkRequest req{QUrl(endpoint)};
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Authorization", ("Bearer " + m_apiKey).toUtf8());

    const QByteArray body = QJsonDocument(buildRequestBody(request)).toJson(QJsonDocument::Compact);
    m_reply = m_nam->post(req, body);
    m_buffer.clear();
    m_partialResponse = {};
    m_streamText.clear();
    m_pendingToolCalls.clear();

    connect(m_reply, &QNetworkReply::readyRead, this, [this]() {
        const int status = m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status >= 400)
            m_errorBuffer += m_reply->readAll();
        else
            handleStreamChunk(m_reply->readAll());
    });
    connect(m_reply, &QNetworkReply::finished, this, [this]() {
        if (m_reply->error() != QNetworkReply::NoError) {
            const int status = m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            QString errMsg;
            if (!m_errorBuffer.isEmpty()) {
                const QJsonObject doc = QJsonDocument::fromJson(m_errorBuffer).object();
                const QJsonObject err = doc["error"].toObject();
                errMsg = err["message"].toString();
                if (errMsg.isEmpty())
                    errMsg = doc["detail"].toString();
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

void OpenAIProvider::cancel()
{
    if (m_reply) {
        m_reply->abort();
        m_reply->deleteLater();
        m_reply = nullptr;
    }
    m_buffer.clear();
    m_pendingToolCalls.clear();
}

QJsonObject OpenAIProvider::buildRequestBody(const LLMRequest &request) const
{
    QJsonObject body;
    body["model"]       = request.model.isEmpty() ? availableModels().first() : request.model;
    body["stream"]      = request.stream;
    body["temperature"] = static_cast<double>(request.temperature);
    body["max_tokens"]  = request.maxTokens;
    body["messages"]    = buildMessages(request.messages);

    if (!request.tools.isEmpty()) {
        body["tools"]       = request.tools;
        body["tool_choice"] = "auto";
    }
    return body;
}

QJsonArray OpenAIProvider::buildMessages(const QList<AgentMessage> &history) const
{
    QJsonArray arr;
    for (const auto &msg : history) {
        QJsonObject m;
        switch (msg.role) {
        case MessageRole::System:    m["role"] = "system";    break;
        case MessageRole::User:      m["role"] = "user";      break;
        case MessageRole::Assistant: m["role"] = "assistant"; break;
        case MessageRole::Tool:      m["role"] = "tool";      break;
        }

        if (msg.hasToolResults()) {
            for (const auto &tr : msg.toolResults) {
                QJsonObject tm;
                tm["role"]         = "tool";
                tm["tool_call_id"] = tr.callId;
                tm["content"]      = tr.content;
                arr.append(tm);
            }
            continue;
        }

        if (msg.hasToolCalls()) {
            QJsonArray calls;
            for (const auto &tc : msg.toolCalls) {
                QJsonObject call;
                call["id"]   = tc.id;
                call["type"] = "function";
                QJsonObject fn;
                fn["name"]      = tc.name;
                fn["arguments"] = QString::fromUtf8(QJsonDocument(tc.arguments).toJson(QJsonDocument::Compact));
                call["function"] = fn;
                calls.append(call);
            }
            m["tool_calls"] = calls;
        }

        m["content"] = msg.content;
        arr.append(m);
    }
    return arr;
}

void OpenAIProvider::handleStreamChunk(const QByteArray &chunk)
{
    m_buffer += chunk;

    while (true) {
        int nl = m_buffer.indexOf('\n');
        if (nl < 0) break;
        const QString line = QString::fromUtf8(m_buffer.left(nl)).trimmed();
        m_buffer = m_buffer.mid(nl + 1);

        if (!line.startsWith("data: ")) continue;
        const QString data = line.mid(6);
        if (data == "[DONE]") {
            for (auto it = m_pendingToolCalls.cbegin(); it != m_pendingToolCalls.cend(); ++it) {
                const auto &pending = it.value();
                if (pending.id.isEmpty() || pending.name.isEmpty())
                    continue;

                ToolCall tc;
                tc.id = pending.id;
                tc.name = pending.name;
                tc.arguments = parseToolArguments(pending.args, pending.id);
                m_partialResponse.message.toolCalls.append(tc);
            }
            m_partialResponse.message.role    = MessageRole::Assistant;
            m_partialResponse.message.content = m_streamText;
            TokenEvent te; te.type = TokenEvent::Type::MessageEnd;
            emit tokenReceived(te);
            continue;
        }

        const QJsonObject obj = QJsonDocument::fromJson(data.toUtf8()).object();
        const auto choices = obj["choices"].toArray();
        if (choices.isEmpty()) continue;
        parseDelta(choices.first().toObject()["delta"].toObject());
    }
}

void OpenAIProvider::parseDelta(const QJsonObject &delta)
{
    if (delta.contains("content") && !delta["content"].isNull()) {
        const QString text = delta["content"].toString();
        m_streamText += text;
        TokenEvent te; te.type = TokenEvent::Type::TextDelta; te.delta = text;
        emit tokenReceived(te);
    }

    if (delta.contains("tool_calls")) {
        for (const auto &tcVal : delta["tool_calls"].toArray()) {
            const auto tc = tcVal.toObject();
            const int idx = tc["index"].toInt();
            const auto fn = tc["function"].toObject();
            auto &pending = m_pendingToolCalls[idx];
            if (tc.contains("id")) pending.id = tc["id"].toString();
            if (fn.contains("name")) pending.name = fn["name"].toString();
            if (fn.contains("arguments")) pending.args += fn["arguments"].toString();
        }
    }
}
