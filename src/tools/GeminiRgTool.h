#ifndef GEMINIRGTOOL_H
#define GEMINIRGTOOL_H

#include "tools/Tool.h"
#include <QJsonObject>

class GeminiRgTool : public Tool
{
    Q_OBJECT
public:
    explicit GeminiRgTool(QObject *parent = nullptr);
    QString name() const override;
    QString description() const override;
    QJsonObject schema() const override;
    QJsonObject run(const QJsonObject &args) override;
};

#endif // GEMINIRGTOOL_H

