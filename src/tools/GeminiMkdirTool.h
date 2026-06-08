#ifndef GEMINIMKDIRTOOL_H
#define GEMINIMKDIRTOOL_H

#include "tools/Tool.h"
#include <QJsonObject>

class GeminiMkdirTool : public Tool
{
    Q_OBJECT
public:
    explicit GeminiMkdirTool(QObject *parent = nullptr);
    QString name() const override;
    QString description() const override;
    QJsonObject schema() const override;
    QJsonObject run(const QJsonObject &args) override;
};

#endif // GEMINIMKDIRTOOL_H

