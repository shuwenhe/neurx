#include "GeminiHashTool.h"
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>

QJsonObject GeminiHashTool::parametersSchema() const
{
    QJsonObject props;
    props["path"] = QJsonObject{{"type", "string"}};

    QJsonObject schema;
    schema["type"] = "object";
    schema["properties"] = props;
    schema["required"] = QJsonArray{"path"};
    return schema;
}

ToolResult GeminiHashTool::execute(const QString &callId, const QJsonObject &args)
{
    ToolResult result;
    result.callId = callId;
    result.name = name();

    const QString path = args.value("path").toString();
    if (path.isEmpty()) {
        result.isError = true;
        result.content = "Missing required parameter: path";
        return result;
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        result.isError = true;
        result.content = QStringLiteral("Failed to open file: %1").arg(file.errorString());
        return result;
    }

    QCryptographicHash hasher(QCryptographicHash::Sha256);
    const qint64 chunkSize = 1024 * 1024; // 1MB
    while (!file.atEnd()) {
        QByteArray chunk = file.read(chunkSize);
        hasher.addData(chunk);
    }
    file.close();

    QByteArray digest = hasher.result().toHex();

    QJsonObject out;
    out["path"] = path;
    out["algorithm"] = "sha256";
    out["hash"] = QString::fromUtf8(digest);

    result.content = QString::fromUtf8(QJsonDocument(out).toJson(QJsonDocument::Compact));
    return result;
}

