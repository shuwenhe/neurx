# NeurX Mobile

`app/mobile` is a dedicated Qt Quick mobile client for Android and iOS.

## Included

- `CMakeLists.txt`: standalone mobile build target
- `main.cpp`: mobile entrypoint that reuses the existing bridge and models
- `qml/`: phone-oriented UI for agent chat and logs
- `android/`: Android manifest and resources
- `ios/`: iOS bundle metadata template
- `scripts/`: helper build scripts for Android and iOS

## Build

Qt Creator / Qt for Android:

1. Open [app/mobile/CMakeLists.txt](/c:/Users/shuwen/neurx/app/mobile/CMakeLists.txt:1) in Qt Creator.
2. Select a `Qt 6.11.0 for Android arm64-v8a` kit.
3. Make sure the Android kit points at:
   `C:\Users\Administrator\AppData\Local\Android\Sdk`
4. Build the `neurx_mobile` target.
5. With a Xiaomi phone connected over USB debugging, run from Qt Creator or deploy the generated APK with `scripts/deploy_android.sh`.

Android:

```bash
bash scripts/build_android.sh
```

Deploy to a connected Android phone:

```bash
bash scripts/deploy_android.sh
```

On Windows PowerShell, you can check whether the Android SDK/NDK are wired up with:

```powershell
powershell.exe -ExecutionPolicy Bypass -File app\mobile\scripts\doctor_android_env.ps1
```

iOS:

```bash
bash scripts/build_ios.sh
```

## Notes

- The mobile app reuses `app/bridge/*.cpp` and the existing backend/agent runtime.
- The current UI is intentionally smaller and touch-first rather than a direct copy of the desktop shell.
- The Android package template lives under [app/mobile/android](/c:/Users/shuwen/neurx/app/mobile/android:1) and now includes launcher icons, theme resources, and a network security config so the APK is ready for Qt Android packaging.
- Platform signing, store packaging, push notifications, and native camera/file integrations are not included yet.
- For a Xiaomi phone, enable Developer options and USB debugging, then connect the device with `adb` available on your PATH.
- The deploy script installs the latest APK from the Android build directory and launches `com.neurx.mobile`.
- If the environment is incomplete, run `doctor_android_env.ps1` first to see which Android pieces are still missing.
