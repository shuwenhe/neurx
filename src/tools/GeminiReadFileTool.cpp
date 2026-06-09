#include "GeminiReadFileTool.h"
#include "agent/JitContext.h"
#include <QFile>
#include <QTextStream>
#include <QJsonObject>
#include <QJsonArray>

GeminiReadFileTool::GeminiReadFileTool(const QString &workspaceRoot, QObject *parent)
    : BaseTool(parent), m_workspaceRoot(workspaceRoot)
{
}

QString GeminiReadFileTool::name() const
{
    return "gemini_read_file";
}

QString GeminiReadFileTool::description() const
{
    return "Reads the content of a specified file.";
}

QJsonObject GeminiReadFileTool::parametersSchema() const
{
    return QJsonObject{
        {"type", "object"},
        {"properties", QJsonObject{
            {"file_path", QJsonObject{
                {"type", "string"},
                {"description", "The absolute path of the file to read."}
            }}
        }},
        {"required", QJsonArray{"file_path"}}
    };
}

ToolResult GeminiReadFileTool::execute(const QString &callId, const QJsonObject &args)
{
    const QString filePath = args["file_path"].toString();

    if (filePath.isEmpty()) {
        return {callId, name(), true, "Missing file_path."};
    }

    QFile file(filePath);

    if (!file.exists()) {
        return {callId, name(), true, "File not found: " + filePath};
    }

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {callId, name(), true,
                "Failed to open file for reading: " + file.errorString()};
    }

    QTextStream in(&file);
    QString content = in.readAll();
    file.close();

    // Discover JIT context
    QString jitContext = JitContext::discoverContext(filePath, m_workspaceRoot);
    content = JitContext::appendJitContext(content, jitContext);

    return {callId, name(), false, content};
}
