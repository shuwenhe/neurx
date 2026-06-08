#include "GeminiWriteFileTool.h"
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QFileInfo>
#include <QDebug>

GeminiWriteFileTool::GeminiWriteFileTool(QObject *parent) : BaseTool(parent)
{
}

QString GeminiWriteFileTool::name() const
{
    return "gemini_write_file";
}

QString GeminiWriteFileTool::description() const
{
    return "Creates a new file and writes content to it, or overwrites an existing file.";
}

QJsonObject GeminiWriteFileTool::parametersSchema() const
{
    return QJsonObject{
        {"type", "object"},
        {"properties", QJsonObject{
            {"file_path", QJsonObject{
                {"type", "string"},
                {"description", "The absolute path to the file to write to."}
            }},
            {"content", QJsonObject{
                {"type", "string"},
                {"description", "The content to write to the file."}
            }}
        }},
        {"required", QJsonArray{"file_path", "content"}}
    };
}

ToolResult GeminiWriteFileTool::execute(const QString &callId, const QJsonObject &args)
{
    QString filePath = args["file_path"].toString();
    QString content = args["content"].toString();

    qInfo() << "[GeminiWriteFileTool]" << callId << "START: file_path=" << filePath << "content_size=" << content.size();

    if (filePath.isEmpty()) {
        qWarning() << "[GeminiWriteFileTool]" << callId << "ERROR: file_path is empty";
        return {callId, name(), true, "Error: file_path parameter is required"};
    }

    if (content.isEmpty()) {
        qWarning() << "[GeminiWriteFileTool]" << callId << "WARNING: content is empty, creating empty file";
    }

    QFile file(filePath);
    QDir dir = QFileInfo(file).dir();

    if (!dir.exists()) {
        if (!dir.mkpath(".")) {
            qWarning() << "[GeminiWriteFileTool]" << callId << "ERROR: Failed to create directory:" << dir.path();
            return {callId, name(), true, "Error: Failed to create directory: " + dir.path()};
        }
        qInfo() << "[GeminiWriteFileTool]" << callId << "Created directory:" << dir.path();
    }

    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QString error = file.errorString();
        qWarning() << "[GeminiWriteFileTool]" << callId << "ERROR: Failed to open file:" << error;
        return {callId, name(), true, "Error: Failed to open file for writing: " + error};
    }

    QTextStream out(&file);
    out << content;
    file.close();

    qInfo() << "[GeminiWriteFileTool]" << callId << "SUCCESS: Wrote" << content.size() << "bytes to" << filePath;
    return {callId, name(), false, "Successfully wrote to file: " + filePath};
}

