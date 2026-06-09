#include "agent/ToolSummarizer.h"
#include <QDebug>

const QString ToolSummarizer::kSummarizePrompt = QStringLiteral(
    "Summarize the following tool output to be a maximum of %1 tokens. "
    "The summary should be concise and capture the main points of the tool output.\n\n"
    "The summarization should be done based on the content that is provided. Here are the basic rules to follow:\n"
    "1. If the text is a directory listing or any output that is structural, use the history of the conversation to understand the context. "
    "Try to understand what information we need from the tool output and return that as a response.\n"
    "2. If the text is text content and there is nothing structural that we need, summarize the text.\n"
    "3. If the text is the output of a shell command, try to understand what information we need from the tool output and return a summarization "
    "along with the stack trace of any error within the <error></error> tags. If there are warnings, include them in the summary within <warning></warning> tags.\n\n"
    "Text to summarize:\n"
    "\"%2\"\n\n"
    "Return the summary string which should first contain an overall summarization of text followed by the full stack trace of errors and warnings."
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

    // For now, just return the original output if it's too long
    // In a full implementation, this would call the LLM provider to summarize
    QString preview = output.left(maxTokens * 4);
    return preview + "\n\n[...output truncated by ToolSummarizer...]";
}
