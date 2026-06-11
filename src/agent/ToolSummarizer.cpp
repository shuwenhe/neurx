#include "agent/ToolSummarizer.h"
#include <QDebug>
#include <QEventLoop>
#include <QMetaObject>
#include <QThread>
#include <QTimer>

const QString ToolSummarizer::kSummarizePrompt = QStringLiteral(
    "You are a precise tool-output summarizer.\n"
    "Summarize the provided tool output concisely, preserving important errors, warnings, "
    "paths, counts, and actionable details.\n"
    "Return plain text only.\n\n"
    "Tool: %3\n"
    "Budget: %1 tokens\n\n"
    "Tool output:\n"
    "%2"
);

ToolSummarizer::ToolSummarizer(LLMProvider *provider)
    : m_provider(provider)
{
}

QString ToolSummarizer::summarize(const QString &toolName, const QString &output, int maxTokens) const
{
    // Heuristic: 1 token is roughly 4 characters.
    // So output.length() / 4 gives an approximate token count.
    if (!m_provider || output.length() < maxTokens * 4) {
        return output;
    }

    qDebug() << "[ToolSummarizer] Tool output exceeds token limit for tool:" << toolName;
    qDebug() << "[ToolSummarizer] Output length:" << output.length() << "bytes";

    ProviderLLMRequest request;
    request.model.clear();
    request.temperature = 0.0f;
    request.maxTokens = qMax(256, qMin(maxTokens, 1024));
    request.stream = false;

    AgentMessage systemMsg;
    systemMsg.role = MessageRole::System;
    systemMsg.content = QStringLiteral(
        "Summarize tool output for an agent. Preserve essential facts, file paths, counts, "
        "errors, warnings, and any actionable next steps. Return plain text only."
    );

    AgentMessage userMsg;
    userMsg.role = MessageRole::User;
    userMsg.content = kSummarizePrompt.arg(maxTokens)
                                      .arg(output)
                                      .arg(toolName);

    request.messages = {systemMsg, userMsg};

    ProviderLLMResponse response;
    QString requestError;
    bool finished = false;

    QEventLoop loop;
    QMetaObject::Connection responseConn = QObject::connect(
        m_provider, &LLMProvider::responseComplete,
        &loop, [&](const ProviderLLMResponse &res) {
            response = res;
            finished = true;
            loop.quit();
        });

    QMetaObject::Connection errorConn = QObject::connect(
        m_provider, &LLMProvider::requestError,
        &loop, [&](const QString &err) {
            requestError = err;
            finished = true;
            loop.quit();
        });

    QTimer timeoutTimer;
    timeoutTimer.setSingleShot(true);
    QObject::connect(&timeoutTimer, &QTimer::timeout, &loop, [&]() {
        requestError = QStringLiteral("Tool summary request timed out.");
        finished = true;
        loop.quit();
    });

    timeoutTimer.start(15000);

    if (m_provider->thread() == QThread::currentThread()) {
        m_provider->sendRequest(request);
    } else {
        QMetaObject::invokeMethod(
            m_provider,
            [provider = m_provider, request]() { provider->sendRequest(request); },
            Qt::QueuedConnection);
    }

    if (!finished) {
        loop.exec();
    }
    QObject::disconnect(responseConn);
    QObject::disconnect(errorConn);

    if (!finished || !requestError.isEmpty() || response.message.content.trimmed().isEmpty()) {
        if (!requestError.isEmpty()) {
            qWarning() << "[ToolSummarizer] Summary request failed:" << requestError;
        }
        const QString preview = output.left(maxTokens * 4);
        return preview + QStringLiteral("\n\n[...output truncated by ToolSummarizer...]");
    }

    const QString summarized = response.message.content.trimmed();
    if (summarized.length() > maxTokens * 4) {
        return summarized.left(maxTokens * 4) + QStringLiteral("\n\n[...summary truncated by ToolSummarizer...]");
    }

    return summarized;
}
