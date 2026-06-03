#include "GeminiGroundingTool.h"

// The implementation is currently inline in the header, but we provide this
// .cpp file to ensure the MOC-generated code has a translation unit to live in,
// which avoids "undefined reference to vtable" errors in some build configurations.

// If we wanted to move the implementation here:
/*
QString GeminiGroundingTool::name() const {
    return "google_search";
}

QString GeminiGroundingTool::description() const {
    return "Search the web using Google's native grounding. Use this for high-precision "
           "queries about recent documentation, news, or general facts.";
}

QJsonObject GeminiGroundingTool::parametersSchema() const {
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

ToolResult GeminiGroundingTool::execute(const QString &callId, const QJsonObject &args) {
    return {callId, name(), false, "Grounding request received. If using Gemini, results will be integrated into the response."};
}
*/
