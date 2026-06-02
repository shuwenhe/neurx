#pragma once
#include "llm/LLMProvider.h"
#include <QNetworkAccessManager>
#include <QNetworkReply>

// ── GeminiProvider ───────────────────────────────────────────────────────────
//  Implements Google Gemini API (Google AI Studio / Vertex AI).
//  Supports multimodal inputs, native tool calling, and long-context reasoning.

class GeminiProvider : public LLMProvider {
    Q_OBJECT
public:
    explicit GeminiProvider(QObject *parent = nullptr);

    QString     providerId()      const override { return "gemini"; }
    QString     displayName()     const override { return "Google Gemini"; }
    QStringList availableModels() const override;

    void sendRequest(const LLMRequest &request) override;
    void cancel() override;

private:
    QJsonObject buildRequestBody(const LLMRequest &request) const;
    QJsonArray  buildContents(const QList<AgentMessage> &history) const;
    QJsonObject buildTools(const QJsonArray &tools) const;

    void handleStreamChunk(const QByteArray &chunk);
    void parseResponsePart(const QJsonObject &part);

    QNetworkAccessManager *m_nam{nullptr};
    QNetworkReply         *m_reply{nullptr};

    QByteArray  m_buffer;
    LLMResponse m_partialResponse;
};
