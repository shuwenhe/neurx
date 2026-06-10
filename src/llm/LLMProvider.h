#pragma once
#include <QObject>
#include <QJsonArray>
#include <functional>
#include "agent/AgentMessage.h"
#include "llm/LLMTypes.h"

// ── LLMProvider ──────────────────────────────────────────────────────────────
//  Abstract base for all LLM backends.
//  Providers are responsible for HTTP, auth, retry and rate-limit logic.

// Provider-specific request/response types with expected field names for agent communication
struct ProviderLLMRequest {
    QString            model;                    // Model name/ID
    QList<AgentMessage> messages;                // Conversation history
    QJsonArray         tools;                    // Provider-specific tool schema
    float              temperature{0.0f};
    int                maxTokens{8192};
    bool               stream{true};
};

struct MessageImageAttachment {
    QString path;
    QString mimeType;
    QString dataUrl;
    QString altText;
};

struct ProviderLLMResponse {
    AgentMessage  message;                       // Structured response with content & toolCalls
    int           inputTokens{0};
    int           outputTokens{0};
    QString       stopReason;                   // "end_turn" | "tool_use" | "max_tokens"
};

// Type aliases for agent code
using LLMRequest = ProviderLLMRequest;
using LLMResponse = ProviderLLMResponse;

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
