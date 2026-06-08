#include "GeminiWriteFileTool.h"
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QDebug>
#include <QSaveFile>
#include <QByteArray>
#include <QJsonObject>

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
    // support either content (string) or contentsBase64 (base64-encoded binary)
    QJsonObject props;
    props["file_path"] = QJsonObject{{"type", "string"}, {"description", "Absolute path to write."}};
    props["content"] = QJsonObject{{"type", "string"}, {"description", "UTF-8 text content."}};
    props["contentsBase64"] = QJsonObject{{"type", "string"}, {"description", "Base64 encoded binary content."}};
    props["options"] = QJsonObject{{"type", "object"}, {"description", "Write options"}};

    return QJsonObject{{"type", "object"}, {"properties", props}, {"required", QJsonArray{"file_path"}}};
}

ToolResult GeminiWriteFileTool::execute(const QString &callId, const QJsonObject &args)
{
    QString filePath = args["file_path"].toString();
    if (filePath.isEmpty()) {
        qWarning() << "[GeminiWriteFileTool]" << callId << "ERROR: file_path is empty";
        return {callId, name(), true, "Error: file_path parameter is required"};
    }

    // Determine content bytes: either contentsBase64 or content
    QByteArray bytes;
    if (args.contains("contentsBase64")) {
        bytes = QByteArray::fromBase64(args.value("contentsBase64").toString().toLatin1());
    } else if (args.contains("content")) {
        bytes = args.value("content").toString().toUtf8();
    } else {
        // create empty file if nothing provided
        bytes.clear();
    }

    // Options
    bool atomic = false;
    bool createDirs = true;
    if (args.contains("options") && args.value("options").isObject()) {
        QJsonObject opts = args.value("options").toObject();
        if (opts.contains("atomic")) atomic = opts.value("atomic").toBool(false);
        if (opts.contains("createDirs")) createDirs = opts.value("createDirs").toBool(true);
    }

    qInfo() << "[GeminiWriteFileTool]" << callId << "START: file_path=" << filePath << "bytes=" << bytes.size() << "atomic=" << atomic;

    QFileInfo finfo(filePath);
    QDir dir = finfo.dir();
    if (!dir.exists()) {
        if (createDirs) {
            if (!dir.mkpath(".")) {
                qWarning() << "[GeminiWriteFileTool]" << callId << "ERROR: Failed to create directory:" << dir.path();
                return {callId, name(), true, "Error: Failed to create directory: " + dir.path()};
            }
        } else {
            return {callId, name(), true, "Parent directory does not exist: " + dir.path()};
        }
    }

    if (atomic) {
        QSaveFile out(filePath);
        if (!out.open(QIODevice::WriteOnly)) {
            QString err = out.errorString();
            qWarning() << "[GeminiWriteFileTool]" << callId << "ERROR: open QSaveFile:" << err;
            return {callId, name(), true, "Error: Failed to open file for atomic write: " + err};
        }
        if (bytes.size()) {
            qint64 written = out.write(bytes);
            Q_UNUSED(written);
        }
        if (!out.commit()) {
            QString err = out.errorString();
            qWarning() << "[GeminiWriteFileTool]" << callId << "ERROR: commit QSaveFile:" << err;
            return {callId, name(), true, "Error: Failed to commit atomic write: " + err};
        }
    } else {
        QFile file(filePath);
        if (!file.open(QIODevice::WriteOnly)) {
            QString err = file.errorString();
            qWarning() << "[GeminiWriteFileTool]" << callId << "ERROR: open file:" << err;
            return {callId, name(), true, "Error: Failed to open file for writing: " + err};
        }
        if (bytes.size()) file.write(bytes);
        file.close();
    }

    qInfo() << "[GeminiWriteFileTool]" << callId << "SUCCESS: Wrote" << bytes.size() << "bytes to" << filePath;
    return {callId, name(), false, "Successfully wrote to file: " + filePath};
}
