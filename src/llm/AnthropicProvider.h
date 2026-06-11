#pragma once
#include "llm/LLMProvider.h"
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

// ── AnthropicProvider ────────────────────────────────────────────────────────
//  Implements the Anthropic Messages API with streaming SSE.
//  Supports: claude-opus-4, claude-sonnet-4-5, claude-haiku-3-5

class AnthropicProvider : public LLMProvider {
    Q_OBJECT
public:
    explicit AnthropicProvider(QObject *parent = nullptr);

    QString     providerId()     const override { return "anthropic"; }
    QString     displayName()    const override { return "Anthropic Claude"; }
    QStringList availableModels() const override;

    void sendRequest(const ProviderLLMRequest &request) override;
    void cancel() override;

private:
    QJsonObject  buildRequestBody(const ProviderLLMRequest &request) const;
    QJsonArray   convertTools(const QJsonArray &tools) const;
    QJsonArray   buildMessages(const QList<AgentMessage> &history) const;

    void handleStreamData(const QByteArray &chunk);
    void parseSSEEvent(const QString &event, const QString &data);

    QNetworkAccessManager *m_nam{nullptr};
    QNetworkReply         *m_reply{nullptr};

    // Stream accumulation state
    QByteArray    m_errorBuffer;
    QString       m_streamText;
    QString       m_currentToolId;
    QString       m_currentToolName;
    QString       m_currentToolArgs;
    ProviderLLMResponse   m_partialResponse;
};
