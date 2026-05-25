#pragma once

#include <QObject>
#include <QString>

// QR code scanner bridge.
// On Android: launches QrScanActivity via JNI and receives the decoded result.
// On other platforms: stub that immediately emits a test result.
class QrScanner : public QObject {
    Q_OBJECT

public:
    explicit QrScanner(QObject* parent = nullptr);
    ~QrScanner() override;

    Q_INVOKABLE void startScan();

signals:
    void qrCodeFound(const QString& code);
    void scanCancelled();
};
