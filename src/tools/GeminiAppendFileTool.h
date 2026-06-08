#ifndef GEMINIAPPENDFILETOOL_H
#define GEMINIAPPENDFILETOOL_H

#include "tools/Tool.h"
#include <QJsonObject>

class GeminiAppendFileTool : public Tool
{
    Q_OBJECT
public:
    explicit GeminiAppendFileTool(QObject *parent = nullptr);
    QString name() const override;
    QString description() const override;
    QJsonObject schema() const override;
    QJsonObject run(const QJsonObject &args) override;
};

#endif // GEMINIAPPENDFILETOOL_H

