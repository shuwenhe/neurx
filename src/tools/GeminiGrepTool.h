#ifndef GEMINIGREPTOOL_H
#define GEMINIGREPTOOL_H

#include "tools/Tool.h"
#include <QJsonObject>

class GeminiGrepTool : public Tool
{
    Q_OBJECT
public:
    explicit GeminiGrepTool(QObject *parent = nullptr);
    QString name() const override;
    QString description() const override;
    QJsonObject schema() const override;
    QJsonObject run(const QJsonObject &args) override;
};

#endif // GEMINIGREPTOOL_H

