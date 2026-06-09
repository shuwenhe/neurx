#pragma once

#include <QString>
#include <QJsonObject>
#include "llm/LLMProvider.h"

/**
 * @class ToolSummarizer
 * @brief Utility for summarizing large tool outputs using an LLM.
 *
 * Replicates the logic from gemini-cli's summarizer.ts
 */
class ToolSummarizer {
public:
    explicit ToolSummarizer(LLMProvider *provider = nullptr);

    /**
     * Summarizes the tool output if it exceeds a certain length.
     * @param toolName The name of the tool that produced the output.
     * @param output The original tool output.
     * @param maxTokens Approximate maximum tokens before summarization kicks in.
     * @return The summarized output (or original if not too long or if summarization fails).
     */
    QString summarize(const QString &toolName, const QString &output, int maxTokens = 2000) const;

private:
    LLMProvider *m_provider;
    static const QString kSummarizePrompt;
};

