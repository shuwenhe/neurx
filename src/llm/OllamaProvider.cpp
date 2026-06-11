#include "llm/OllamaProvider.h"
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

static constexpr char kDefaultBase[] = "http://localhost:11434";

OllamaProvider::OllamaProvider(QObject *parent)
    : LLMProvider(parent)
    , m_nam(new QNetworkAccessManager(this))
{
    m_endpoint = kDefaultBase;
    refreshModels();
}

void OllamaProvider::refreshModels()
{
    QNetworkRequest req(QUrl(m_endpoint + "/api/tags"));
    auto *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) return;
        const auto obj = QJsonDocument::fromJson(reply->readAll()).object();
        m_cachedModels.clear();
        for (const auto &m : obj["models"].toArray())
            m_cachedModels << m.toObject()["name"].toString();
        emit modelsRefreshed(m_cachedModels);
    });
}

void OllamaProvider::sendRequest(const ProviderLLMRequest &request)
{
    if (m_reply) cancel();

    QJsonObject body;
    body["model"]  = request.model.isEmpty() ? (m_cachedModels.isEmpty() ? "llama3" : m_cachedModels.first())
                                              : request.model;
    body["stream"] = request.stream;

    QJsonArray messages;
    for (const auto &msg : request.messages) {
        QJsonObject m;
        switch (msg.role) {
        case MessageRole::System:    m["role"] = "system";    break;
        case MessageRole::User:      m["role"] = "user";      break;
        case MessageRole::Assistant: m["role"] = "assistant"; break;
        default:                     m["role"] = "user";      break;
        }
        m["content"] = msg.content;
        messages.append(m);
    }
    body["messages"] = messages;

    QNetworkRequest req(QUrl(m_endpoint + "/api/chat"));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    m_reply = m_nam->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));

    connect(m_reply, &QNetworkReply::readyRead, this, [this]() {
        handleStreamChunk(m_reply->readAll());
    });
    connect(m_reply, &QNetworkReply::finished, this, [this]() {
        if (m_reply->error() != QNetworkReply::NoError)
            emit requestError(m_reply->errorString());
        m_reply->deleteLater();
        m_reply = nullptr;
    });
}

void OllamaProvider::cancel()
{
    if (m_reply) { m_reply->abort(); m_reply->deleteLater(); m_reply = nullptr; }
}

void OllamaProvider::handleStreamChunk(const QByteArray &chunk)
{
    // Ollama streams NDJSON: one JSON object per line.
    static QByteArray buf;
    buf += chunk;

    while (true) {
        int nl = buf.indexOf('\n');
        if (nl < 0) break;
        const QByteArray line = buf.left(nl).trimmed();
        buf = buf.mid(nl + 1);
        if (line.isEmpty()) continue;

        const QJsonObject obj = QJsonDocument::fromJson(line).object();
        const QString text = obj["message"].toObject()["content"].toString();
        if (!text.isEmpty()) {
            TokenEvent te; te.type = TokenEvent::Type::TextDelta; te.delta = text;
            emit tokenReceived(te);
        }
        if (obj["done"].toBool()) {
            ProviderLLMResponse resp;
            resp.message.role = MessageRole::Assistant;
            emit responseComplete(resp);
        }
    }
}
