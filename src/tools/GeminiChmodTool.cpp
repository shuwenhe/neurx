#include "GeminiChmodTool.h"
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>

static QFileDevice::Permissions permissionsFromOctal(int octal)
{
    QFileDevice::Permissions perms = QFileDevice::Permissions();

    // octal is like 0755. Extract owner/group/other
    int owner = (octal / 100) % 10;
    int group = (octal / 10) % 10;
    int other = octal % 10;

    auto apply = [&](int bits, QFileDevice::Permission read, QFileDevice::Permission write, QFileDevice::Permission exec) {
        QFileDevice::Permissions p = QFileDevice::Permissions();
        if (bits & 4) p |= read;
        if (bits & 2) p |= write;
        if (bits & 1) p |= exec;
        return p;
    };

    // Owner
    perms |= apply(owner, QFileDevice::ReadOwner, QFileDevice::WriteOwner, QFileDevice::ExeOwner);
    // Group
    perms |= apply(group, QFileDevice::ReadGroup, QFileDevice::WriteGroup, QFileDevice::ExeGroup);
    // Other
    perms |= apply(other, QFileDevice::ReadOther, QFileDevice::WriteOther, QFileDevice::ExeOther);

    return perms;
}

QJsonObject GeminiChmodTool::parametersSchema() const
{
    QJsonObject props;
    props["path"] = QJsonObject{{"type", "string"}};
    props["mode"] = QJsonObject{{"type", "string"}, {"description", "Octal string like 644 or 0755"}};

    QJsonObject schema;
    schema["type"] = "object";
    schema["properties"] = props;
    schema["required"] = QJsonArray{"path", "mode"};
    return schema;
}

ToolResult GeminiChmodTool::execute(const QString &callId, const QJsonObject &args)
{
    ToolResult result;
    result.callId = callId;
    result.name = name();

    const QString path = args.value("path").toString();
    const QString modeStr = args.value("mode").toString();

    if (path.isEmpty() || modeStr.isEmpty()) {
        result.isError = true;
        result.content = "Missing required parameter: path or mode";
        return result;
    }

    bool ok = false;
    int octal = modeStr.toInt(&ok, 8);
    if (!ok) {
        // Try decimal parse
        octal = modeStr.toInt(&ok, 10);
        if (!ok) {
            result.isError = true;
            result.content = "Invalid mode string";
            return result;
        }
    }

    QFileDevice::Permissions perms = permissionsFromOctal(octal);
    QFile file(path);
    if (!file.exists()) {
        result.isError = true;
        result.content = QStringLiteral("Path does not exist: %1").arg(path);
        return result;
    }

    if (!file.setPermissions(perms)) {
        result.isError = true;
        result.content = QStringLiteral("Failed to set permissions on %1").arg(path);
        return result;
    }

    QJsonObject out;
    out["path"] = path;
    out["mode"] = modeStr;
    out["applied"] = true;

    result.content = QString::fromUtf8(QJsonDocument(out).toJson(QJsonDocument::Compact));
    return result;
}

