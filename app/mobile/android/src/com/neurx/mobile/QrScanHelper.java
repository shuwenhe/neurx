package com.neurx.mobile;

import android.app.Activity;
import android.content.Intent;

import org.qtproject.qt.android.QtNative;

/**
 * Static helper called from C++ (QrScanner.cpp) to start/stop QR scanning
 * and to receive the result from QrScanActivity and forward it via JNI to C++.
 */
public final class QrScanHelper {

    private QrScanHelper() {}

    /** Called from C++ via QJniObject::callStaticMethod to launch the scanner. */
    public static void startScan() {
        Activity activity = QtNative.activity();
        if (activity == null) return;
        Intent intent = new Intent(activity, QrScanActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        activity.startActivity(intent);
    }

    /** Called from QrScanActivity when a QR code has been successfully decoded. */
    public static void notifyResult(String code) {
        nativeOnQrResult(code);
    }

    /** Called from QrScanActivity when scanning was cancelled (back / no permission). */
    public static void notifyCancelled() {
        nativeOnScanCancelled();
    }

    // ----- JNI methods implemented in QrScanner.cpp -----

    private static native void nativeOnQrResult(String code);
    private static native void nativeOnScanCancelled();
}
