#pragma once
#include "agent/ToolRegistry.h"

// ── GeminiGroundingTool ──────────────────────────────────────────────────────
//  A specialized tool that leverages Google's native grounding features.
//  In GeminiProvider, this is mapped to 'google_search_retrieval'.

class GeminiGroundingTool : public BaseTool {
    Q_OBJECT
public:
    explicit GeminiGroundingTool(QObject *parent = nullptr) : BaseTool(parent) {}

    QString name()        const override { return "google_search"; }
    QString description() const override {
        return "Search the web using Google's native grounding. Use this for high-precision "
               "queries about recent documentation, news, or general facts.";
    }

    QJsonObject parametersSchema() const override {
        return QJsonObject{
            {"type", "object"},
            {"properties", QJsonObject{
                {"query", QJsonObject{
                    {"type", "string"},
                    {"description", "The search query."}
                }}
            }},
            {"required", QJsonArray{"query"}}
        };
    }

    ToolResult execute(const QString &callId, const QJsonObject &args) override {
        // When using Gemini, the provider will intercept this tool and use native grounding.
        // For other providers, we can fallback to WebSearchTool or return a placeholder.
        return {callId, name(), false, "Grounding request received. If using Gemini, results will be integrated into the response."};
    }
};
