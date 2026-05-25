#include "QrScanner.h"

#include <QMetaObject>

#if defined(Q_OS_ANDROID)
#include <QJniObject>
#include <jni.h>

// Pointer to the live QrScanner instance used by the JNI callbacks below.
// Written only from the main thread (QrScanner ctor/dtor); read from the
// Java UI thread inside the JNI callbacks (which immediately marshal back
// to the Qt main thread via QueuedConnection, so the window where they can
// race with dtor is negligible for this application lifecycle).
static QrScanner* g_qr_scanner = nullptr;

// Called from Java: com.neurx.mobile.QrScanHelper.nativeOnQrResult(String)
extern "C" JNIEXPORT void JNICALL
Java_com_neurx_mobile_QrScanHelper_nativeOnQrResult(JNIEnv* env, jclass, jstring result)
{
    QrScanner* s = g_qr_scanner;
    if (!s) return;
    const char* str = env->GetStringUTFChars(result, nullptr);
    QString code = QString::fromUtf8(str);
    env->ReleaseStringUTFChars(result, str);
    QMetaObject::invokeMethod(s, [s, code]() {
        emit s->qrCodeFound(code);
    }, Qt::QueuedConnection);
}

// Called from Java: com.neurx.mobile.QrScanHelper.nativeOnScanCancelled()
extern "C" JNIEXPORT void JNICALL
Java_com_neurx_mobile_QrScanHelper_nativeOnScanCancelled(JNIEnv*, jclass)
{
    QrScanner* s = g_qr_scanner;
    if (!s) return;
    QMetaObject::invokeMethod(s, [s]() {
        emit s->scanCancelled();
    }, Qt::QueuedConnection);
}

#endif // Q_OS_ANDROID

QrScanner::QrScanner(QObject* parent)
    : QObject(parent)
{
#if defined(Q_OS_ANDROID)
    g_qr_scanner = this;
#endif
}

QrScanner::~QrScanner()
{
#if defined(Q_OS_ANDROID)
    if (g_qr_scanner == this) {
        g_qr_scanner = nullptr;
    }
#endif
}

void QrScanner::startScan()
{
#if defined(Q_OS_ANDROID)
    QJniObject::callStaticMethod<void>(
        "com/neurx/mobile/QrScanHelper",
        "startScan",
        "()V"
    );
#else
    // Desktop/simulator stub: immediately return a fake result so QML can be tested.
    QMetaObject::invokeMethod(this, [this]() {
        emit qrCodeFound(QStringLiteral("https://example.com/stub-qr-code"));
    }, Qt::QueuedConnection);
#endif
}
