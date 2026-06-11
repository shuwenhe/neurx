package com.neurx.mobile;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.os.Bundle;
import android.util.Size;
import android.view.Gravity;
import android.view.Window;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.ImageProxy;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.view.PreviewView;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleOwner;
import androidx.lifecycle.LifecycleRegistry;

import com.google.common.util.concurrent.ListenableFuture;
import com.google.mlkit.vision.barcode.BarcodeScanner;
import com.google.mlkit.vision.barcode.BarcodeScannerOptions;
import com.google.mlkit.vision.barcode.BarcodeScanning;
import com.google.mlkit.vision.barcode.common.Barcode;
import com.google.mlkit.vision.common.InputImage;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Full-screen QR scanning Activity.
 * Uses CameraX for camera preview + ML Kit for barcode decoding.
 * Extends Activity and manually implements LifecycleOwner (no AppCompat needed).
 */
public class QrScanActivity extends Activity implements LifecycleOwner {

    private static final int REQUEST_CAMERA = 1001;

    private final LifecycleRegistry lifecycleRegistry = new LifecycleRegistry(this);
    private final AtomicBoolean resultDelivered = new AtomicBoolean(false);

    private PreviewView previewView;
    private ExecutorService cameraExecutor;
    private ListenableFuture<ProcessCameraProvider> cameraProviderFuture;

    // ── LifecycleOwner ───────────────────────────────────────────────────────

    @NonNull
    @Override
    public Lifecycle getLifecycle() {
        return lifecycleRegistry;
    }

    // ── Activity lifecycle ───────────────────────────────────────────────────

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setFlags(
                WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);

        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE);
        cameraExecutor = Executors.newSingleThreadExecutor();

        // ── Build UI ────────────────────────────────────────────────────────
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);

        previewView = new PreviewView(this);
        root.addView(previewView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        // Scanning hint label
        TextView hint = new TextView(this);
        hint.setText("将二维码放入画面中");
        hint.setTextColor(Color.WHITE);
        hint.setTextSize(18f);
        hint.setShadowLayer(6f, 1f, 1f, Color.BLACK);
        FrameLayout.LayoutParams hintLp = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT);
        hintLp.gravity = Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL;
        hintLp.bottomMargin = dpToPx(96);
        root.addView(hint, hintLp);

        // Cancel button
        TextView cancelBtn = new TextView(this);
        cancelBtn.setText("取消");
        cancelBtn.setTextColor(Color.WHITE);
        cancelBtn.setTextSize(16f);
        cancelBtn.setPadding(dpToPx(32), dpToPx(14), dpToPx(32), dpToPx(14));
        cancelBtn.setBackgroundColor(0xAA000000);
        FrameLayout.LayoutParams cancelLp = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT);
        cancelLp.gravity = Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL;
        cancelLp.bottomMargin = dpToPx(28);
        root.addView(cancelBtn, cancelLp);
        cancelBtn.setOnClickListener(v -> cancelAndFinish());

        setContentView(root);

        // ── Request camera permission ────────────────────────────────────────
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
                == PackageManager.PERMISSION_GRANTED) {
            startCamera();
        } else {
            ActivityCompat.requestPermissions(
                    this,
                    new String[]{Manifest.permission.CAMERA},
                    REQUEST_CAMERA);
        }
    }

    @Override
    protected void onStart() {
        super.onStart();
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START);
    }

    @Override
    protected void onResume() {
        super.onResume();
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME);
    }

    @Override
    protected void onPause() {
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE);
        super.onPause();
    }

    @Override
    protected void onStop() {
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_STOP);
        super.onStop();
    }

    @Override
    protected void onDestroy() {
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY);
        if (cameraExecutor != null && !cameraExecutor.isShutdown()) {
            cameraExecutor.shutdown();
        }
        if (!resultDelivered.getAndSet(true)) {
            QrScanHelper.notifyCancelled();
        }
        super.onDestroy();
    }

    @Override
    public void onBackPressed() {
        cancelAndFinish();
        super.onBackPressed();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode,
                                           @NonNull String[] permissions,
                                           @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQUEST_CAMERA) {
            if (grantResults.length > 0
                    && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startCamera();
            } else {
                Toast.makeText(this, "需要相机权限才能扫描二维码", Toast.LENGTH_LONG).show();
                cancelAndFinish();
            }
        }
    }

    // ── Camera ───────────────────────────────────────────────────────────────

    private void startCamera() {
        cameraProviderFuture = ProcessCameraProvider.getInstance(this);
        cameraProviderFuture.addListener(() -> {
            try {
                ProcessCameraProvider cameraProvider = cameraProviderFuture.get();

                Preview preview = new Preview.Builder().build();
                preview.setSurfaceProvider(previewView.getSurfaceProvider());

                ImageAnalysis imageAnalysis = new ImageAnalysis.Builder()
                        .setTargetResolution(new Size(1280, 720))
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build();

                BarcodeScanner scanner = BarcodeScanning.getClient(
                        new BarcodeScannerOptions.Builder()
                                .setBarcodeFormats(Barcode.FORMAT_QR_CODE,
                                        Barcode.FORMAT_ALL_FORMATS)
                                .build());

                imageAnalysis.setAnalyzer(cameraExecutor, this::analyzeImage);
                // Store scanner reference for use in analyzeImage
                qrScanner = scanner;

                CameraSelector cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA;
                cameraProvider.unbindAll();
                cameraProvider.bindToLifecycle(this, cameraSelector, preview, imageAnalysis);

            } catch (Exception e) {
                runOnUiThread(() ->
                        Toast.makeText(this, "相机启动失败: " + e.getMessage(), Toast.LENGTH_LONG).show());
            }
        }, ContextCompat.getMainExecutor(this));
    }

    private BarcodeScanner qrScanner;

    @SuppressLint("UnsafeOptInUsageError")
    private void analyzeImage(ImageProxy imageProxy) {
        if (resultDelivered.get() || qrScanner == null) {
            imageProxy.close();
            return;
        }
        android.media.Image mediaImage = imageProxy.getImage();
        if (mediaImage == null) {
            imageProxy.close();
            return;
        }
        InputImage image = InputImage.fromMediaImage(
                mediaImage, imageProxy.getImageInfo().getRotationDegrees());

        qrScanner.process(image)
                .addOnSuccessListener(barcodes -> {
                    for (Barcode barcode : barcodes) {
                        String value = barcode.getRawValue();
                        if (value != null && !value.isEmpty()) {
                            if (!resultDelivered.getAndSet(true)) {
                                QrScanHelper.notifyResult(value);
                                runOnUiThread(this::finish);
                            }
                            break;
                        }
                    }
                })
                .addOnFailureListener(e -> { /* ignore single-frame failures */ })
                .addOnCompleteListener(task -> imageProxy.close());
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private void cancelAndFinish() {
        if (!resultDelivered.getAndSet(true)) {
            QrScanHelper.notifyCancelled();
        }
        finish();
    }

    private int dpToPx(int dp) {
        float density = getResources().getDisplayMetrics().density;
        return Math.round(dp * density);
    }
}
