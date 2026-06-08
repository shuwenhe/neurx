#ifndef GEMINISTATFILETOOL_H
#define GEMINISTATFILETOOL_H

#include "tools/Tool.h"
#include <QJsonObject>

class GeminiStatFileTool : public Tool
{
    Q_OBJECT
public:
    explicit GeminiStatFileTool(QObject *parent = nullptr);
    QString name() const override;
    QString description() const override;
    QJsonObject schema() const override;
    QJsonObject run(const QJsonObject &args) override;
};

#endif // GEMINISTATFILETOOL_H

