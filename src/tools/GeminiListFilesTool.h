#ifndef GEMINILISTFILESTOOL_H
#define GEMINILISTFILESTOOL_H

#include "tools/Tool.h"
#include <QDir>
#include <QJsonObject>

class GeminiListFilesTool : public Tool
{
    Q_OBJECT
public:
    explicit GeminiListFilesTool(QObject *parent = nullptr);
    QString name() const override;
    QString description() const override;
    QJsonObject schema() const override;
    QJsonObject run(const QJsonObject &args) override;
};

#endif // GEMINILISTFILESTOOL_H

