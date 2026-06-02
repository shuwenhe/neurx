#pragma once
#include "llm/LLMProvider.h"
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QHash>

// ── OpenAIProvider ────────────────────────────────────────────────────────────
//  Implements OpenAI Chat Completions API with streaming and function-calling.
//  Also supports OpenAI-compatible endpoints (Azure OpenAI, local vLLM, etc.)

class OpenAIProvider : public LLMProvider {
    Q_OBJECT
public:
    explicit OpenAIProvider(QObject *parent = nullptr);

    QString     providerId()      const override { return "openai"; }
    QString     displayName()     const override { return "OpenAI"; }
    QStringList availableModels() const override;

    void sendRequest(const LLMRequest &request) override;
    void cancel() override;

private:
    struct PendingToolCall {
        QString id;
        QString name;
        QString args;
    };

    QJsonObject buildRequestBody(const LLMRequest &request) const;
    QJsonArray  buildMessages(const QList<AgentMessage> &history) const;

    void handleStreamChunk(const QByteArray &chunk);
    void parseDelta(const QJsonObject &delta);

    QNetworkAccessManager *m_nam{nullptr};
    QNetworkReply         *m_reply{nullptr};

    // Stream state
    QByteArray  m_buffer;
    QByteArray  m_errorBuffer;
    QString     m_streamText;
    QHash<int, PendingToolCall> m_pendingToolCalls;
    LLMResponse m_partialResponse;
};
