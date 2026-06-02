#pragma once
#include <QObject>
#include <QJsonArray>
#include <functional>
#include "agent/AgentMessage.h"

// ── LLMProvider ──────────────────────────────────────────────────────────────
//  Abstract base for all LLM backends.
//  Providers are responsible for HTTP, auth, retry and rate-limit logic.

struct LLMRequest {
    QString            model;
    QList<AgentMessage> messages;
    QJsonArray         tools;       // provider-specific schema
    float              temperature{0.0f};
    int                maxTokens{8192};
    bool               stream{true};
};

struct LLMResponse {
    AgentMessage  message;
    int           inputTokens{0};
    int           outputTokens{0};
    QString       stopReason;      // "end_turn" | "tool_use" | "max_tokens"
};

class LLMProvider : public QObject {
    Q_OBJECT
public:
    explicit LLMProvider(QObject *parent = nullptr) : QObject(parent) {}

    // Human-readable identifier shown in the model selector.
    virtual QString providerId()   const = 0;
    virtual QString displayName()  const = 0;

    // Fetch the list of available models from the provider.
    virtual QStringList availableModels() const = 0;

    // Send a request and stream responses back via signals.
    // Returns immediately; results arrive via tokenReceived / responseComplete.
    virtual void sendRequest(const LLMRequest &request) = 0;

    // Cancel the in-flight request, if any.
    virtual void cancel() = 0;

    // Configure auth / endpoint (read from encrypted settings).
    virtual void setApiKey(const QString &key)       { m_apiKey = key; }
    virtual void setEndpointOverride(const QString &url) { m_endpoint = url; }

signals:
    void tokenReceived(const TokenEvent &event);
    void responseComplete(const LLMResponse &response);
    void requestError(const QString &error);

protected:
    QString m_apiKey;
    QString m_endpoint;
};
