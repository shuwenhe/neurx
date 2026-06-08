#ifndef GEMINIREMOVEFILETOOL_H
#define GEMINIREMOVEFILETOOL_H

#include "tools/Tool.h"
#include <QJsonObject>

class GeminiRemoveFileTool : public Tool
{
    Q_OBJECT
public:
    explicit GeminiRemoveFileTool(QObject *parent = nullptr);
    QString name() const override;
    QString description() const override;
    QJsonObject schema() const override;
    QJsonObject run(const QJsonObject &args) override;
};

#endif // GEMINIREMOVEFILETOOL_H

