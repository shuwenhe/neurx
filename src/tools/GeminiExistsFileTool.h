#ifndef GEMINIEXISTSFILETOOL_H
#define GEMINIEXISTSFILETOOL_H

#include "tools/Tool.h"
#include <QJsonObject>

class GeminiExistsFileTool : public Tool
{
    Q_OBJECT
public:
    explicit GeminiExistsFileTool(QObject *parent = nullptr);
    QString name() const override;
    QString description() const override;
    QJsonObject schema() const override;
    QJsonObject run(const QJsonObject &args) override;
};

#endif // GEMINIEXISTSFILETOOL_H

