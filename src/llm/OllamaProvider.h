#pragma once
#include "llm/LLMProvider.h"
#include <QNetworkAccessManager>

// ── OllamaProvider ────────────────────────────────────────────────────────────
//  Connects to a local Ollama instance (default: http://localhost:11434).
//  Supports streaming via the /api/chat endpoint.
//  Model list is fetched dynamically from /api/tags.

class OllamaProvider : public LLMProvider {
    Q_OBJECT
public:
    explicit OllamaProvider(QObject *parent = nullptr);

    QString     providerId()      const override { return "ollama"; }
    QString     displayName()     const override { return "Ollama (Local)"; }
    QStringList availableModels() const override { return m_cachedModels; }

    void sendRequest(const ProviderLLMRequest &request) override;
    void cancel() override;

    // Refresh model list from the Ollama daemon.
    void refreshModels();

signals:
    void modelsRefreshed(const QStringList &models);

private:
    QNetworkAccessManager *m_nam{nullptr};
    QNetworkReply         *m_reply{nullptr};
    QStringList            m_cachedModels;

    void handleStreamChunk(const QByteArray &chunk);
};
