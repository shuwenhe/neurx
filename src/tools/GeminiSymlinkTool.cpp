#include "GeminiSymlinkTool.h"
#include <QFile>
#include <QJsonDocument>

QJsonObject GeminiSymlinkTool::parametersSchema() const
{
    QJsonObject props;
    props["target"] = QJsonObject{{"type", "string"}};
    props["linkPath"] = QJsonObject{{"type", "string"}};

    QJsonObject schema;
    schema["type"] = "object";
    schema["properties"] = props;
    schema["required"] = QJsonArray{"target", "linkPath"};
    return schema;
}

ToolResult GeminiSymlinkTool::execute(const QString &callId, const QJsonObject &args)
{
    ToolResult result;
    result.callId = callId;
    result.name = name();

    const QString target = args.value("target").toString();
    const QString linkPath = args.value("linkPath").toString();
    if (target.isEmpty() || linkPath.isEmpty()) {
        result.isError = true;
        result.content = "Missing required parameter: target or linkPath";
        return result;
    }

    // QFile::link(existing, newLinkName)
    bool ok = QFile::link(target, linkPath);
    if (!ok) {
        result.isError = true;
        result.content = QStringLiteral("Failed to create symlink from %1 to %2").arg(linkPath, target);
        return result;
    }

    QJsonObject out;
    out["target"] = target;
    out["linkPath"] = linkPath;
    out["created"] = true;

    result.content = QString::fromUtf8(QJsonDocument(out).toJson(QJsonDocument::Compact));
    return result;
}

