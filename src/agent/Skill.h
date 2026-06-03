#pragma once
#include <QString>
#include <QStringList>
#include <QJsonObject>
#include <QVariantMap>

struct Skill {
    QString id;
    QString title;
    QString description;
    QString sourcePath;
    QString sourceDirectory;
    QString systemInstructions;
    QStringList requiredTools;
    QStringList tags;
    QStringList aliases;
    QVariantList examples; // List of {input, output} for few-shot
    QVariantMap metadata;
    bool active{true};

    QVariantMap toMap() const {
        QVariantMap map;
        map["id"] = id;
        map["title"] = title;
        map["description"] = description;
        map["sourcePath"] = sourcePath;
        map["sourceDirectory"] = sourceDirectory;
        map["active"] = active;
        map["requiredTools"] = requiredTools;
        map["tags"] = tags;
        map["aliases"] = aliases;
        map["metadata"] = metadata;
        return map;
    }
};
